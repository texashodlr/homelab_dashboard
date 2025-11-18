from __future__ import annotations

import asyncio
import json
import random
import ssl
import time
from dataclasses import dataclass
from typing import Any, Optional, Dict

import aiohttp

class RedfishError(Exception):
    """Generic Redfish client error."""

@dataclass(frozen=True)
class ClientConfig:
    connect_timeout_s: float = 2.0
    read_timeout_s: float = 4.0
    total_timeout_s: float = 6.0
    verify_ssl: bool = False            # self-signed BMC/PDUs
    user_agent: str = "tw-redfish/0.1"
    max_retries: int = 2
    backoff_base_s: float = 0.2
    per_request_semaphore: Optional[asyncio.Semaphore] = None

class RedfishClient:
    """
    Async Redfish client:
      - Single aiohttp session (keep-alive)
      - Optional global semaphore for concurrency
      - Jittered exponential backoff retries
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

    async def get_liquid_leak(
        self,
        ip: str,
        *,
        username: str,
        password: str,
    ) -> Optional[Dict[str, Optional[str]]]:
        """
        Supermicro example:
        GET /redfish/v1/Chassis/1/Sensors/LiquidLeak
        Returns dict: {"health": ..., "location": ...} or None on failure/not present.
        """
        url = f"https://{ip}/redfish/v1/Chassis/1/Sensors/LiquidLeak"
        data = await self._get_json_with_retries(url, auth=aiohttp.BasicAuth(username, password))
        if data is None:
            return None
        return _extract_liquid_leak(data)
    
    # --- Placeholders for future expansion ---
    async def get_m2_health(self, ip: str, *, username: str, password: str) -> Optional[Dict[str, Any]]:
        auth = aiohttp.BasicAuth(username, password)
        base = f"https://{ip}/redfish/v1/Chassis/HA-RAID.0.StorageEnclosure.0/Drives"
        url_0 = f"{base}/Disk.Bay.0"
        url_1 = f"{base}/Disk.Bay.1"
        data_0, data_1 = await asyncio.gather(
            self._get_json_with_retries(url_0,auth=auth),
            self._get_json_with_retries(url_1,auth=auth),
        )
        
        if data_0 is None and data_1 is None:
            return None
        
        drives: List[Dict[str, Any]] = []
        if data_0 is not None:
            drives.append(_extract_m2_drive(data_0, bay="0"))
        if data_1 is not None:
            drives.append(_extract_m2_drive(data_1, bay="1"))
        return drives
    
    async def get_nvme_health(self, ip: str, *, username: str, password: str) -> Optional[Dict[str, Any]]:
        auth = aiohttp.BasicAuth(username, password)
        base = f"https://{ip}/redfish/v1/Chassis/1/PCIeDevices/NVMeSSD"
        url_1 = f"{base}1"
        url_2 = f"{base}2"
        url_3 = f"{base}3"
        url_4 = f"{base}4"

        data_1, data_2, data_3, data_4 = await asyncio.gather(
            self._get_json_with_retries(url_1,auth=auth),
            self._get_json_with_retries(url_2,auth=auth),
            self._get_json_with_retries(url_3,auth=auth),
            self._get_json_with_retries(url_4,auth=auth),
        )
        
        if data_1 is None and data_2 is None and data_3 is None and data_4 is None:
            return None
        
        drives: List[Dict[str, Any]] = []
        if data_1 is not None:
            drives.append(_extract_nvme_drive(data_1, bay="1"))
        if data_2 is not None:
            drives.append(_extract_nvme_drive(data_2, bay="2"))
        if data_3 is not None:
            drives.append(_extract_nvme_drive(data_3, bay="3"))
        if data_4 is not None:
            drives.append(_extract_nvme_drive(data_4, bay="4"))    
        return drives
    
    async def get_memory_health(self, ip: str, *, username: str, password: str) -> Optional[List[Dict[str, Any]]]:
        
        auth = aiohttp.BasicAuth(username, password)
        base = f"https://{ip}/redfish/v1/Systems/1/Memory/"
        # /redfish/v1/Systems/1/Memory/12/MemoryMetrics
        dimm_slots = [str(i) for i in range(1, 25)]
        urls = [f"{base}{dimm}/MemoryMetrics" for dimm in dimm_slots]

        tasks = [self._get_json_with_retries(url, auth=auth) for url in urls]
        datas = await asyncio.gather(*tasks)

        if all(d is None for d in datas):
            return None
        
        dimms: List[Dict[str, Any]] = []
        for dimm, data in zip(dimm_slots, datas):
            if data is not None:
                dimms.append(_extract_dimm(data, dimm=dimm))

        return dimms

    async def get_cpu_health(self, ip: str, *, username: str, password: str) -> Optional[Dict[str, Any]]:
        # Example endpoint (varies by vendor): /redfish/v1/Systems/1/Processors
        # Return a dict like {"summary_health": "...", "processors": [{"id": "...", "health": "..."}]}
        return None

    async def get_gpu_health(self, ip: str, *, username: str, password: str) -> Optional[Dict[str, Any]]:
        # Example OEM path may expose GPU sensors: /redfish/v1/Chassis/1/Sensors/<GPU>...
        return None

    async def get_nic_health(self, ip: str, *, username: str, password: str) -> Optional[Dict[str, Any]]:
        # /redfish/v1/Systems/1/EthernetInterfaces or OEM NIC sensors
        return None

    # ---------- INTERNALS ----------

    async def _get_json_with_retries(
        self,
        url: str,
        *,
        auth: Optional[aiohttp.BasicAuth] = None,
    ) -> Optional[dict[str, Any]]:
        await self._ensure_session()
        assert self._session is not None

        attempts = self.cfg.max_retries + 1
        for attempt in range(attempts):
            try:
                async with self._maybe_semaphore():
                    async with self._session.get(
                        url,
                        auth=auth,
                        ssl=self._ssl_context if not self.cfg.verify_ssl else None,
                    ) as resp:
                        if 200 <= resp.status < 300:
                            text = await resp.text()
                            try:
                                return json.loads(text)
                            except json.JSONDecodeError:
                                return await resp.json(content_type=None)

                        if resp.status in (401, 403):
                            raise RedfishError(f"Auth failed ({resp.status}) for {url}")
                        if resp.status == 404:
                            return None

                        body = await _safe_snippet(resp)
                        raise RedfishError(f"HTTP {resp.status} from {url}: {body}")

            except (aiohttp.ClientError, asyncio.TimeoutError, RedfishError):
                if attempt < attempts - 1:
                    await asyncio.sleep(self._backoff_delay(attempt))
                continue

        return None

    def _backoff_delay(self, attempt: int) -> float:
        base = self.cfg.backoff_base_s * (2 ** attempt)
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

def _extract_liquid_leak(data: dict[str, Any]) -> Dict[str, Optional[str]]:
    """
    Pulls health + location for the LiquidLeak sensor from common Supermicro schemas.
    """
    health = None
    location = None
    try:
        status = data.get("Status")
        if isinstance(status, dict):
            maybe = status.get("Health")
            if isinstance(maybe, str):
                health = maybe

        oem = data.get("Oem")
        if isinstance(oem, dict):
            sm = oem.get("Supermicro")
            if isinstance(sm, dict):
                sv = sm.get("SensorValue")
                if isinstance(sv, str):
                    location = sv
    except Exception:
        pass

    return {"health": health, "location": location}

def _extract_m2_drive(data: Dict[str, Any], bay: str) -> Dict[str, Any]:
    """
    Pulls health + location for the LiquidLeak sensor from common Supermicro schemas.
    """
    health: Optional[str] =  None
    otherErrCount: Optional[int] = None
    SmartEvent: Optional[int] = None
    MediaErrCount: Optional[int] = None
    
    try:
        status = data.get("Status")
        if isinstance(status, dict):
            maybe = status.get("Health")
            if isinstance(maybe, str):
                health = maybe

        oem = data.get("Oem")
        if isinstance(oem, dict):
            sm = oem.get("Supermicro")
            if isinstance(sm, dict):
                oec = sm.get("OtherErrCount")
                if isinstance(oec, int):
                    other_err_count = oec

                ser = sm.get("SmartEventReceived")
                if isinstance(ser, int):
                    smart_event = ser

                mec = sm.get("MediaErrCount")
                if isinstance(mec, int):
                    media_err_count = mec
    except Exception:
        # swallow and return partial info
        pass

    return {
        "m2_bay": bay,
        "health": health,
        "other_err_count": other_err_count,
        "smart_event_received": smart_event,
        "media_err_count": media_err_count,
    }

def _extract_nvme_drive(data: Dict[str, Any], bay: str) -> Dict[str, Any]:
    """
    Pulls health + location for the nvme drive from common Supermicro schemas.
    """
    serialNumber: Optional[str] =  None
    health: Optional[str] = None
    healthRollup: Optional[str] = None
    
    try:
        serialNumber = data.get("SerialNumber")

        status = data.get("Status")
        if isinstance(status, dict):
            h = status.get("Health")
            if isinstance(h, str):
                health = h
            hr = status.get("HealthRollup")
            if isinstance(hr, str):
                healthRollup = hr
    except Exception:
        # swallow and return partial info
        pass

    return {
        "nvme_bay": bay,
        "sn": serialNumber,
        "health": health,
        "healthRollup": healthRollup,
    }

def _extract_dimm(data: Dict[str, Any], dimm: str) -> Dict[str, Any]:
    """
    Pulls health + location for the nvme drive from common Supermicro schemas.
    """
    temp_alarm: Optional[bool] =  None
    uncorrectableECCerr_alarm: Optional[bool] = None
    correctableECCerr_alarm: Optional[bool] = None
    
    try:
        health_data = data.get("HealthData")
        if isinstance(health_data, dict):
            alarm_trips = health_data.get("AlarmTrips")
            if isinstance(alarm_trips, dict):
                t = alarm_trips.get("Temperature")
                if isinstance(t, bool):
                    temp_alarm = t
                unc = alarm_trips.get("UncorrectableECCError")
                if isinstance(unc, bool):
                    uncorrectableECCerr_alarm = unc
                c = alarm_trips.get("CorrectableECCError")
                if isinstance(c, bool):
                    correctableECCerr_alarm = c
    except Exception:
        # swallow and return partial info
        pass

    return {
        "dimm_slot": dimm,
        "temp_alarm": temp_alarm,
        "uncorrectableECCerr_alarm": uncorrectableECCerr_alarm,
        "correctableECCerr_alarm": correctableECCerr_alarm,
    }


async def _safe_snippet(resp: aiohttp.ClientResponse, limit: int = 200) -> str:
    try:
        text = await resp.text()
        return text[:limit].replace("\n", " ")
    except Exception:
        return "<no body>"