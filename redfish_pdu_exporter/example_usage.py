# Dummy implementation to test on a single PDU
import asyncio
from redfish_client import RedfishClient, ClientConfig

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
        watts = await rf.get_outlet_power(
            ip="10.31.238.79",
            outlet=40,
            username="admin",
            password="87654321",
        )
        print("W:", watts)

if __name__ == "__main__":
    asyncio.run(main())