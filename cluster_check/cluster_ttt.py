import os
import json
import time
import argparse
from tqdm import tqdm
import asyncio
from typing import List, Tuple, Dict, Any

from redfish_ttt import RedfishClient, ClientConfig
# Used for looping through the cluster
# Assumes IPMI.json formatting

# ----------- Server Inventory ----------- #

def load_ipmi_json(datastore_json_file: str, server_prefix: str, pdu_prefix: str) -> List[Tuple[str, str, str, str]]:
    with open(datastore_json_file, 'r') as file_handle:
        ipmi_list = json.load(file_handle)
    servers = []
    for node in ipmi_list:
        n = node.get("name", "")
        if server_prefix in n and pdu_prefix not in n:
            #print(f"name: {node['name']}, ip: {node['ip']}, ")
            servers.append((n, node.get("ip"), node.get("username"), node.get("password")))
    return servers


# ----------- Checks Registry ----------- #
async def run_checks(rf: RedfishClient, ip: str, user: str, pw: str) -> Dict[str, Any]:
    """
    Add new checks here keeping return keys stable
    Each check should return a dict or none
    """
    results: Dict[str, Any] = {}
    
    # 1. Liquid Leak Check
    try:
        ll = await rf.get_liquid_leak(ip=ip, username=user, password=pw)
        results["liquid_leak"] = ll
    except Exception as e:
        results["liquid_leak"] = None
        results.setdefault("_errors", []).append(f"liquid_leak:{type(e).__name__}")
    
    try:
        ll = await rf.get_m2_health(ip=ip, username=user, password=pw)
        results["m2_drives"] = ll
    except Exception as e:
        results["m2_drives"] = None
        results.setdefault("_errors", []).append(f"m2_drives:{type(e).__name__}")

    # -- Future -- #
    # 2. CPU
    # 3. HDD/SSD
    # 4. Memory
    # 5. NIC
    # 6. GPU
    # 7. Power
    return results

# ----------- Runner ----------- #
async def sweep(
    datastore_json_file: str,
    server_prefix: str,
    pdu_prefix: str,
    out_path: str,
    max_concurrency: int = 400,
) -> None:
    servers = load_ipmi_json(datastore_json_file, server_prefix, pdu_prefix)
    cfg = ClientConfig(
        connect_timeout_s=2.0,
        read_timeout_s=4.0,
        total_timeout_s=6.0,
        verify_ssl=False,
        max_retries=2,
        per_request_semaphore=asyncio.Semaphore(max_concurrency),
    )
    # JSONL output
    # One line per host: {"ts":..., "name":..., "ip":..., "status":"ok|fail", "checks":{...}}
    async with RedfishClient(cfg) as rf:
        # Write as results complete (as_completed) to avoid holding everything in memory
        async def do_one(name: str, ip: str, user: str, pw: str) -> str:
            t0 = time.time()
            status = "ok"
            try:
                checks = await run_checks(rf, ip, user, pw)
            except Exception as e:
                status = "fail"
                checks = {"_errors": [f"runner:{type(e).__name__}"]}
            rec = {
                "ts": int(t0),
                "name": name,
                "ip": ip,
                "status": status,
                "checks": checks,
            }
            return json.dumps(rec, separators=(",", ":"), sort_keys=False)

        tasks = [do_one(n, ip, u, p) for (n, ip, u, p) in servers]

        start = time.time()

        # Append mode so multiple sweeps can be concatenated
        with open(out_path, "a", buffering=1) as fh:
            # tqdm progress bar over total number of servers
            with tqdm(total=len(tasks), desc="Liquid leak sweep", unit="server") as pbar:
                for fut in asyncio.as_completed(tasks):
                    line = await fut
                    fh.write(line + "\n")
                    pbar.update(1)   # <- bump bar for each completed host
        
        end = time.time()
        print(f"[Sweep Completed] Servers: {len(servers)} | Duration {end - start:.2f} seconds")
# ---------- cli ----------

def parse_args():
    ap = argparse.ArgumentParser(description="Timmy's Tensor Triage (TTT) (JSONL)")
    ap.add_argument("--ipmi", default="ipmi.json", help="Path to ipmi.json")
    ap.add_argument("--server-prefix", default="tus1-p", help="Server name prefix filter")
    ap.add_argument("--pdu-prefix", default="tus1-pdu", help="PDU name prefix to exclude")
    ap.add_argument("--out", default="ttt.jsonl", help="Output JSONL log file")
    ap.add_argument("--concurrency", type=int, default=400, help="Max concurrent requests")
    return ap.parse_args()

async def main_async():
    a = parse_args()
    await sweep(a.ipmi, a.server_prefix, a.pdu_prefix, a.out, a.concurrency)

def main():
    asyncio.run(main_async())

if __name__ == "__main__":
    main()