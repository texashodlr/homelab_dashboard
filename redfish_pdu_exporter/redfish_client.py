from __future__ import annotations

import asyncio
import json
import random
import ssl
import time
from dataclasses import dataclass
from typing import Any, Optional

import aiohttp

class RedfishError(Exception):
    """Generic Redfish client error."""

@dataclass(frozen=True)
class ClientConfig:
    connect_timeout_s: float = 2.0
    read_timeout_s: float = 4.0
    total_timeout_s: float = 6.0
    verify_ssl: bool = False
    user_agent: str = "pdu-exporter/0.1"
    max_retries: int = 2
    backoff_base_s: float = 0.2
    per_request_semaphore: Optional[asyncio.Semaphore] = None

class RedfishClient:
    """
    Async redfish client:
        - Reuses a single aiohttp ClientSession (HTTP keep-alive)
        - Optional concurrency control via semaphore
        - Jittered exponentional backoff retries
    """

    def __init__(self, cfg: Optional[ClientConfig] = None):
        self.cfg = cfg or ClientConfig()
        self._session: Optional[aiohttp.ClientSession] = None
        self._ssl_context: Optional[ssl.SSLContext] = None

        if not self.cfg.verify_ssl:
            self._ssl_context = ssl.create_default_context()
            self._ssl_context.check_hostname = False
            self._ssl_context.verify_mode = ssl.CERT_NONE
    
    async def __aenter__(self) -> "RedfishClient":
        await self._ensure_session()
        return self
    
    async def __aexit__(self, exc_type, exc, tb):
        await self.close()
    
    async def _ensure_session(self) -> None:
        if self._session is None or self._session.closed:
            timeout = aiohttp.ClientTimeout(
                total=self.cfg.total_timeout_s,
                connect=self.cfg.connect_timeout_s,
                sock_read=self.cfg.read_timeout_s,
            )
            headers = {"User-Agent": self.cfg.user_agent, "Accept": "application/json"}
            self._session = aiohttp.ClientSession(timeout=timeout, headers=headers)

    async def close(self) -> None:
        if self._session and not self._session.closed:
            await self._session.close()


## Public API ##

    async def get_outlet_power(
        self,
        ip: str,
        outlet: int | str,
        *,
        username: str,
        password: str,
    ) -> Optional[float]:
        outlet_str = str(outlet)
        url = f"https://{ip}/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET{outlet_str}"
        # curl -sk --user admin:87654321 https://$NAME/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET14 | jq -r '.Voltage.Reading'

        data = await self._get_json_with_retries(
            url,
            auth=aiohttp.BasicAuth(username, password),
        )
        if data is None:
            return None
        
        val = _extract_watts(data)
        return val

    async def get_outlet_volts(
        self,
        ip: str,
        outlet: int | str,
        *,
        username: str,
        password: str,
    ) -> Optional[float]:
        outlet_str = str(outlet)
        url = f"https://{ip}/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET{outlet_str}"
        # curl -sk --user admin:87654321 https://$NAME/redfish/v1/PowerEquipment/RackPDUs/1/Outlets/OUTLET14 | jq -r '.Voltage.Reading'

        data = await self._get_json_with_retries(
            url,
            auth=aiohttp.BasicAuth(username, password),
        )
        if data is None:
            return None
        
        val = _extract_volts(data)
        return val

    async def _get_json_with_retries(
        self,
        url: str,
        *,
        auth: Optional[aiohttp.BasicAuth] = None,
    ) -> Optional[dict[str, Any]]:
        await self._ensure_session()
        assert self._session is not None

        last_err: Optional[Exception] = None
        attempts = self.cfg.max_retries + 1

        for attempt in range(attempts):
            t0 = time.time()
            try:
                async with self._maybe_semaphore():
                    async with self._session.get(
                        url,
                        auth=auth,
                        ssl=self._ssl_context if not self.cfg.verify_ssl else None,
                    ) as resp:
                            # 2xx happy path
                        if 200 <= resp.status < 300:
                            text = await resp.text()
                                # Some devices return application/json but with oddities; parse robustly.
                            try:
                                return json.loads(text)
                            except json.JSONDecodeError:
                                    # Some PDUs return bytes or malformed JSON occasionally; try resp.json() as a fallback.
                                return await resp.json(content_type=None)

                        # 401/403 likely bad credentials or auth flow
                        if resp.status in (401, 403):
                            raise RedfishError(f"Auth failed ({resp.status}) for {url}")
                        # 404: outlet not found (can occur for absent outlets)
                        if resp.status == 404:
                            return None

                            # Other HTTP errors → retry-able
                        body = await _safe_snippet(resp)
                        raise RedfishError(f"HTTP {resp.status} from {url}: {body}")

            except (aiohttp.ClientError, asyncio.TimeoutError, RedfishError) as e:
                last_err = e
                # Only backoff if we have remaining attempts
                if attempt < attempts - 1:
                    await asyncio.sleep(self._backoff_delay(attempt))
                continue
            finally:
                _ = time.time() - t0

        # Exhausted retries
        return None

    def _backoff_delay(self, attempt: int) -> float:
        base = self.cfg.backoff_base_s * (2**attempt)
        jitter = random.uniform(0, base * 0.5)
        return base + jitter

    def _maybe_semaphore(self):
        sem = self.cfg.per_request_semaphore
        return _SemaphoreContext(sem)

class _SemaphoreContext:
    """ Async context manager wrapper for an optional semaphore"""
    def __init__(self, semaphore: Optional[asyncio.Semaphore]):
        self._sem = semaphore

    async def __aenter__(self):
        if self._sem is not None:
            await self._sem.acquire()
        return self

    async def __aexit__(self, exc_type, exc, tb):
        if self._sem is not None:
            self._sem.release()

def _extract_watts(data: dict[str, Any]) -> Optional[float]:
    """
    Robustly extract a watts reading from common Redfish schemas.

    Primary (as requested):
        data["PowerWatts"]["Reading"]

    Fallbacks seen in the wild (kept conservative):
        data["PowerReading"] or data["PowerReading"]["Reading"]
        data["Power"]["Reading"]
    """
    try:
        pw = data.get("PowerWatts")
        if isinstance(pw, dict):
            val = pw.get("Reading")
            if _is_number(val):
                return float(val)
    except Exception:
        pass

    # Conservative fallbacks
    try:
        pr = data.get("PowerReading")
        if _is_number(pr):
            return float(pr)
        if isinstance(pr, dict) and _is_number(pr.get("Reading")):
            return float(pr["Reading"])
    except Exception:
        pass

    try:
        p = data.get("Power")
        if isinstance(p, dict) and _is_number(p.get("Reading")):
            return float(p["Reading"])
    except Exception:
        pass

    return None

def _extract_volts(data: dict[str, Any]) -> Optional[float]:
    """
    Robustly extract a watts reading from common Redfish schemas.

    Primary (as requested):
        data["PowerWatts"]["Reading"]

    Fallbacks seen in the wild (kept conservative):
        data["PowerReading"] or data["PowerReading"]["Reading"]
        data["Power"]["Reading"]
    """
    try:
        pw = data.get("Voltage")
        if isinstance(pw, dict):
            val = pw.get("Reading")
            if _is_number(val):
                return float(val)
    except Exception:
        pass

    # Conservative fallbacks
    #   None
    return None

def _is_number(x: Any) -> bool:
    try:
        float(x)
        return True
    except Exception:
        return False

async def _safe_snippet(resp: aiohttp.ClientResponse, limit: int = 200) -> str:
    try: 
        text = await resp.text()
        return text[:limit].replace("\n"," ")
    except Exception:
        return "<no body>"