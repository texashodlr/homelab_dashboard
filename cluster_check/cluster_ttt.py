import json
import asyncio
from redfish_ttt import RedfishClient, ClientConfig
# Used for looping through the cluster
# Assumes IPMI.json formatting

def load_ipmi_json(datastore_json_file, server_prefix, pdu_prefix):
    with open(datastore_json_file, 'r') as file_handle:
        ipmi_list = json.load(file_handle)
    servers = []
    for node in ipmi_list:
        if server_prefix in node['name'] and pdu_prefix not in node['name']:
            #print(f"name: {node['name']}, ip: {node['ip']}, ")
            servers.append([node['name'], node['ip'], node['username'], node['password']])
    return servers


async def main():
    datastore_json_file = 'ipmi.json'
    server_prefix = 'tus1-p'
    pdu_prefix = 'tus1-pdu'
    output_log_file = 'ttt.log'
    cfg = ClientConfig(
        connect_timeout_s=2.0,
        read_timeout_s=4.0,
        total_timeout_s=6.0,
        verify_ssl=False,
        max_retries=2,
        per_request_semaphore=asyncio.Semaphore(400),  # global concurrency limit (optional)
    )
    servers = load_ipmi_json(datastore_json_file, server_prefix, pdu_prefix)
    async with RedfishClient(cfg) as rf:
        with open(output_log_file, 'w') as file:
            for server in servers:
                liquid_check = await rf.get_liquid_leak(ip=server[1], username=server[2], password=server[3])
                file.write(f"{server[0]}: Status: {liquid_check}\n")

if __name__ == "__main__":
    asyncio.run(main())