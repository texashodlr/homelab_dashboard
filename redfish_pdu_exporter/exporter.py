from __future__ import annotations
import asyncio
import os
import re
import signal
import sys
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

import aiohttp
import yaml
from prometheus_client import CollectorRegistry, Gauge, Histogram, generate_latest
from aiohttp import web

from redfish_client import RedfishClient, ClientConfig

# ----
# Configs
# ----

@dataclass
class Target:
    pdu: str
    ip: str
    auth_group: str
    outlets: List[int]
    labels: Dict[str,str] # Suggested: {"rack":"ru3", "row": "A"}

@dataclass
class AuthGroup:
    user: str
    password: str

@dataclass
class AppConfig:
    poll_interval_seconds: int
    request_timeout_seconds: float
    connect_timeout_seconds: float
    max_concurrency: int
    tls_verify: bool
    per_host_qps: Optional[float]  # reserved for future
    http_host: str
    http_port: int
    auth_groups: Dict[str, AuthGroup]
    targets: List[Target]
    cb_fail_threshold: int    # consecutive failures to open circuit
    cb_cooldown_cycles: int   # cycles to skip once open

# ----
# Utilities
# ----

ENV_VAR_PATTERN = re.compile(r"\$\{([A-Z0-9_]+)\}")

def _resolve_env_placeholders(obj: Any) -> Any:
    """Recursively replace ${VAR} in strings with os.environ values."""
    if isinstance(obj, dict):
        return {k: _resolve_env_placeholders(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_resolve_env_placeholders(v) for v in obj]
    if isinstance(obj, str):
        def repl(m: re.Match) -> str:
            name = m.group(1)
            return os.environ.get(name, "")
        return ENV_VAR_PATTERN.sub(repl, obj)
    return obj

def load_config(path: str) -> AppConfig:
    with open(path, "r") as f:
        raw = yaml.safe_load(f)
    raw = _resolve_env_placeholders(raw or {})

    # Defaults
    poll = int(raw.get("poll_interval_seconds", 30))
    cfg = AppConfig(
        poll_interval_seconds=poll,
        request_timeout_seconds=float(raw.get("request_timeout_seconds", 4)),
        connect_timeout_seconds=float(raw.get("connect_timeout_seconds", 2)),
        max_concurrency=int(raw.get("max_concurrency", 400)),
        tls_verify=bool(raw.get("tls_verify", False)),
        per_host_qps=raw.get("per_host_qps", None),
        http_host=str(raw.get("http_host", "0.0.0.0")),
        http_port=int(raw.get("http_port", 9100)),
        auth_groups={},
        targets=[],
        cb_fail_threshold=int(raw.get("circuit_breaker", {}).get("fail_threshold", 5)),
        cb_cooldown_cycles=int(raw.get("circuit_breaker", {}).get("cooldown_cycles", 3)),
    )

# Auth
    auth = raw.get("auth", {}).get("groups", {})
    for name, creds in auth.items():
        cfg.auth_groups[name] = AuthGroup(user=str(creds.get("user", "")), password=str(creds.get("pass", "")))

    # Targets
    tlist = raw.get("targets", [])
    for t in tlist:
        labels = {}
        for k, v in (t.items()):
            # treat any non-reserved keys as labels
            pass
        # Extract known keys
        pdu = t["pdu"]
        ip = t["ip"]
        ag = t["auth_group"]
        outlets = t.get("outlets", [])
        # Labels are any extra keys not in the core set
        label_dict = {k: str(v) for k, v in t.items() if k not in ("pdu", "ip", "auth_group", "outlets")}
        cfg.targets.append(Target(pdu=pdu, ip=ip, auth_group=ag, outlets=outlets, labels=label_dict))

    return cfg

# ----
# Metrics
# ----

REGISTRY = CollectorRegistry()

OUTLET_WATTS = Gauge(
    "pdu_outlet_power_watts",
    "PDU outlet power (Watts)",
    ["pdu", "ip", "outlet"] + ["rack", "row"],
    registry=REGISTRY,
)

SCRAPE_OK = Gauge(
    "pdu_scrape_ok",
    "Last scrape success for this PDU (1=ok, 0=fail)",
    ["pdu", "ip"],
    registry=REGISTRY,
)

LAST_SUCCESS = Gauge(
    "pdu_last_success_epoch_seconds",
    "Unix epoch of last successful scrape for this PDU",
    ["pdu", "ip"],
    registry=REGISTRY,
)

SCRAPE_LAT = Histogram(
    "pdu_scrape_duration_seconds",
    "Latency for a single outlet scrape",
    buckets=(0.05, 0.1, 0.2, 0.5, 1, 2, 3, 5, 8, 13),
    registry=REGISTRY,
)

IN_FLIGHT = Gauge(
    "pdu_requests_in_flight",
    "Requests currently in flight",
    registry=REGISTRY,
)

READY = Gauge(
    "pdu_exporter_ready",
    "Exporter readiness (1=ready, 0=initializing)",
    registry=REGISTRY,
)

# ----
# Collector Task
# ----

class Collector:
    def __init__(self, cfg: AppConfig):
        self.cfg = cfg
        self._stop = asyncio.Event()
        self._ready = asyncio.Event()
        self._sem = asyncio.Semaphore(cfg.max_concurrency)
        self._fail_streaks: Dict[str, int] = {}   # key: pdu ip
        self._cooldown_left: Dict[str, int] = {}  # cycles remaining to skip
        self._rf: Optional[RedfishClient] = None

    async def start(self):
        rf_cfg = ClientConfig(
            connect_timeout_s=self.cfg.connect_timeout_seconds,
            read_timeout_s=self.cfg.request_timeout_seconds,
            total_timeout_s=max(self.cfg.connect_timeout_seconds, self.cfg.request_timeout_seconds) + 1.0,
            verify_ssl=self.cfg.tls_verify,
            max_retries=2,
            per_request_semaphore=self._sem,
        )
        self._rf = RedfishClient(rf_cfg)
        await self._rf._ensure_session()  # prime the session

        # Launch loop
        asyncio.create_task(self._run_loop(), name="collector-loop")

    async def stop(self):
        self._stop.set()
        if self._rf:
            await self._rf.close()

    async def _run_loop(self):
        try:
            cycle = 0
            while not self._stop.is_set():
                t0 = time.time()
                await self._one_sweep(cycle)
                if not self._ready.is_set():
                    self._ready.set()
                    READY.set(1)
                elapsed = time.time() - t0
                sleep_for = max(0.0, self.cfg.poll_interval_seconds - elapsed)
                try:
                    await asyncio.wait_for(self._stop.wait(), timeout=sleep_for)
                except asyncio.TimeoutError:
                    pass
                cycle += 1
        finally:
            READY.set(0)

    async def _one_sweep(self, cycle: int):
        if self._rf is None:
            return
        tasks = []
        # Build work list, skipping PDUs on cooldown
        for tgt in self.cfg.targets:
            if self._cooldown_left.get(tgt.ip, 0) > 0:
                self._cooldown_left[tgt.ip] -= 1
                SCRAPE_OK.labels(tgt.pdu, tgt.ip).set(0)
                continue
            for o in tgt.outlets:
                tasks.append(self._poll_outlet(tgt, o))

        # Drive tasks with as_completed to keep memory modest
        if not tasks:
            return
        # Wrap in a shield to ensure we decrement IN_FLIGHT on cancellation
        await asyncio.gather(*tasks, return_exceptions=True)

    async def _poll_outlet(self, tgt: Target, outlet: int):
        if self._rf is None:
            return
        labels = self._labels_for(tgt, outlet)

        # In-flight instrumentation
        IN_FLIGHT.inc()
        try:
            with SCRAPE_LAT.time():
                val = await self._rf.get_outlet_power(
                    ip=tgt.ip,
                    outlet=outlet,
                    username=self.cfg.auth_groups[tgt.auth_group].user,
                    password=self.cfg.auth_groups[tgt.auth_group].password,
                )
        finally:
            IN_FLIGHT.dec()

        if val is not None:
            OUTLET_WATTS.labels(**labels).set(val)
            SCRAPE_OK.labels(tgt.pdu, tgt.ip).set(1)
            LAST_SUCCESS.labels(tgt.pdu, tgt.ip).set(time.time())
            self._fail_streaks[tgt.ip] = 0
        else:
            # mark failure for this PDU
            SCRAPE_OK.labels(tgt.pdu, tgt.ip).set(0)
            streak = self._fail_streaks.get(tgt.ip, 0) + 1
            self._fail_streaks[tgt.ip] = streak
            if streak >= self.cfg.cb_fail_threshold:
                # open circuit: back off for a few cycles
                self._cooldown_left[tgt.ip] = self.cfg.cb_cooldown_cycles
                # reset so we don't immediately retrigger after cooldown
                self._fail_streaks[tgt.ip] = 0

    def _labels_for(self, tgt: Target, outlet: int) -> Dict[str, str]:
        # ensure rack/row exist in label set, even if blank (prom labels must be consistent)
        rack = tgt.labels.get("rack", "")
        row  = tgt.labels.get("row", "")
        base = {
            "pdu": tgt.pdu,
            "ip": tgt.ip,
            "outlet": str(outlet),
            "rack": rack,
            "row": row,
        }
        return base

    # Exposed to the HTTP layer
    def is_ready(self) -> bool:
        return self._ready.is_set()

# ----
# HTTP Server
# ----

class HttpApp:
    def __init__(self, cfg: AppConfig, collector: Collector):
        self.cfg = cfg
        self.collector = collector
        self.app = web.Application()
        self.app.add_routes([
            web.get("/metrics", self.handle_metrics),
            web.get("/-/healthz", self.handle_healthz),
            web.get("/-/ready", self.handle_ready),
        ])
        self.runner: Optional[web.AppRunner] = None
        self.site: Optional[web.TCPSite] = None
    
    async def start(self):
        self.runner = web.AppRunner(self.app, access_log=None)
        await self.runner.setup()
        self.site = web.TCPSite(self.runner, host=self.cfg.http_host, port=self.cfg.http_port)
        await self.site.start()

    async def stop(self):
        if self.runner:
            await self.runner.cleanup()

    async def handle_metrics(self, request: web.Request) -> web.Response:
        data = generate_latest(REGISTRY)
        return web.Response(body=data, content_type=None)

    async def handle_healthz(self, request: web.Request) -> web.Response:
        return web.Response(text="ok\n")

    async def handle_ready(self, request: web.Request) -> web.Response:
        if self.collector.is_ready():
            return web.Response(text="ready\n")
        return web.Response(status=503, text="not ready\n")


# ----
# Main
# ----

async def amain():
    #config_path = os.environ.get("CONFIG", "/config/config.yaml")
    config_path = os.environ.get("CONFIG", "config.yaml")
    if not os.path.exists(config_path):
        print(f"[FATAL] Config not found at {config_path}", file=sys.stderr)
        sys.exit(2)
    else:
        print(f"[SUCCESS] Config file found at {config_path}")
    
    cfg = load_config(config_path)
    collector = Collector(cfg)
    http = HttpApp(cfg, collector)

    print(f"[SUCCESS] Config, collector and httpApp loaded\nStarting components...")

    # Start components
    await collector.start()
    await http.start()

    # Signal handling
    loop = asyncio.get_running_loop()
    stop_event = asyncio.Event()

    def _stop():
        stop_event.set()

    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _stop)
        except NotImplementedError:
            # Windows
            signal.signal(sig, lambda s, f: _stop())

    # Wait for shutdown request
    await stop_event.wait()

    # Shutdown
    await http.stop()
    await collector.stop()

def main():
    try:
        asyncio.run(amain())
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    main()