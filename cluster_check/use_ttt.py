# Single host diagnostics
import asyncio
from redfish_ttt import RedfishClient, ClientConfig

async def main():
    cfg = ClientConfig(
        connect_timeout_s=2.0,
        read_timeout_s=4.0,
        total_timeout_s=6.0,
        verify_ssl=False,
        max_retries=2,
        per_request_semaphore=asyncio.Semaphore(400),  # global concurrency limit (optional)
    )
    async with RedfishClient(cfg) as rf:
        liquid_check = await rf.get_liquid_leak(
            ip="10.31.230.107",
            username="ADMIN",
            password="NIEUOCNAIL",
        )
        print("Status:", liquid_check)

if __name__ == "__main__":
    asyncio.run(main())