import json
file_path = '../pdu_scripts/ipmi_pdus.json'

try:
    with open(file_path, 'r') as file:
        data = json.load(file)
    print("JSON Data loaded successfully: ")
    print(data)
    print(f"Type of loaded data: {type(data)}")

except FileNotFoundError:
    print(f"Error: The file '{file_path}' was not found.")
except json.JSONDecodeError:
    print(f"Error: Could not decode JSON from '{file_path}'. Check if the file contains valid JSON.")
except Exception as e:
    print(f"An unexpected error occurred: {e}")