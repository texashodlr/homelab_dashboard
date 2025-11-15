import json
import yaml
file_path = '../pdu_scripts/ipmi_pdus.json'
config_file_path = 'test_config.yaml'
try:
    with open(file_path, 'r') as file:
        data = json.load(file)
    print("JSON Data loaded successfully: ")
    #print(data)
    print(f"Type of loaded data: {type(data)}")
    print(f"Item #1: {data[0]}")
    prometheus_pdu_dict = list()
    for pdu in data:
        print(f"PDU: {pdu}")
        temp_pdu = dict()
        name = pdu['name']
        temp_pdu['pdu'] = str(name)
        temp_pdu['ip'] = str(pdu['ip'])
        temp_pdu['auth_group'] = "tw-tus1"
        temp_pdu['rack'] = str(name[9:12])
        temp_pdu['row'] = str(name[13:])
        #print(f"Rack: {temp_pdu['rack']} | Row: {temp_pdu['row']}")
        # Outlet check
        if temp_pdu['row'] =='L1' or temp_pdu['row'] =='R1':
            temp_pdu['outlets'] = [10, 12, 18, 20, 26, 28, 38, 40]
        elif temp_pdu['row'] =='L2':
            temp_pdu['outlets'] = [6, 8, 14, 16, 26, 28, 38, 40]
        elif temp_pdu['row'] =='L3' or temp_pdu['row'] == 'L4':
            temp_pdu['outlets'] = [6, 8, 14, 16, 22, 24, 32, 34]
        elif temp_pdu['row'] =='R2':
            temp_pdu['outlets'] = [10, 12, 14, 16, 26, 28, 38, 40]
        elif temp_pdu['row'] =='R3' or temp_pdu['row'] == 'R4':
            temp_pdu['outlets'] = [6, 8, 14, 16, 22, 24, 32, 34]
        else:
            print("Error assigning outlets")
            break
        #print(f"Temp: {temp_pdu}")
        prometheus_pdu_dict.append(temp_pdu)
    #print(prometheus_pdu_dict)
    #yaml_string = yaml.dump(prometheus_pdu_dict, sort_keys=False)
    with open(config_file_path, "w") as f:
        f.write('poll_interval_seconds: 30\n')
        f.write('request_timeout_seconds: 4\n')
        f.write('connect_timeout_seconds: 2\n')
        f.write('max_concurrency: 100\n')
        f.write('tls_verify: false\n')
        f.write('http_host: "0.0.0.0"\n')
        f.write('http_port: 9100\n')
        f.write('circuit_breaker:\n')
        f.write('  fail_threadhold: 5\n')
        f.write('  cooldown_cycles: 3\n\n')
        f.write('auth:\n')
        f.write('  groups:\n')
        f.write('    tw-tus1:\n')
        f.write('      user: "${PDU_USER}"\n')
        f.write('      pass: "${PDU_PASS}"\n')
        f.write('targets:\n')
        yaml.dump(prometheus_pdu_dict, f, sort_keys=False)


except FileNotFoundError:
    print(f"Error: The file '{file_path}' was not found.")
except json.JSONDecodeError:
    print(f"Error: Could not decode JSON from '{file_path}'. Check if the file contains valid JSON.")
except Exception as e:
    print(f"An unexpected error occurred: {e}")



"""

Need to now modify the dict and add in the additional yaml:
- pdu: "tus1-pdu-209-R2"
  ip: "10.31.236.149"
  auth_group: "tw-tus1"
  rack: "209
  row: "R2
  outlets: [10, 12, 14, 16, 26, 28, 38, 40]

Example Dict: ["pdu":"tus1...", "ip":"1.1.1.1", "auth":"---", "rack":"100", "row":"L1", "outlets":"[10, 12, 14, 16, 26, 28, 38, 40]"]

"""