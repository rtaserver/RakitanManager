import logging
import sys
from huawei_lte_api.Client import Client
from huawei_lte_api.Connection import Connection
import time

def get_wan_info(client):
    """Get WAN IP address and device name."""
    wan_info = client.device.information()
    wan_ip_address = wan_info.get('WanIPAddress')
    device_name = wan_info.get('DeviceName')
    return wan_ip_address, device_name

def fetch_wan_info(client):
    """Fetch WAN IP address and device name."""
    wan_ip_address = None
    device_name = None
    while not (wan_ip_address and device_name):
        wan_ip_address, device_name = get_wan_info(client)
    return wan_ip_address, device_name

def initiate_ip_change(client):
    """Initiate IP change process."""
    response = client.net.plmn_list()

def print_header(title, creator):
    """Print section header."""
    print(f"{'=' * 40}")
    print(f"{title.center(40)}")
    print(f"{'=' * 40}")
    print(f"Script created by: {creator}\n")

def print_result(label, value):
    """Print result."""
    print(f"{label}: {value}")

def print_success(message):
    """Print success message."""
    print("\n\033[92m" + message + "\033[0m")

def print_error(message):
    """Print error message."""
    print("\n\033[91m" + message + "\033[0m")

def main():
    """Main function."""
    router_ip = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]

    connection_url = f'http://{username}:{password}@{router_ip}/'

    with Connection(connection_url) as connection:
        client = Client(connection)
        
        try:
            print_header("Auto Reconnect Modem Huawei", "@RTASERVER")           
            
            wan_ip_address, device_name = fetch_wan_info(client)
            print_result("Device Name", device_name)
            print_result("Current IP", wan_ip_address)
          
            print("Initiating IP change process...")
            initiate_ip_change(client)
            
            time.sleep(5)  
            
            print("Waiting for the IP to be changed...")
            wan_ip_address_after_plmn, _ = fetch_wan_info(client)
            print_result("New IP", wan_ip_address_after_plmn)
            
            print_success("IP has been successfully changed.")
        
        except Exception as e:
            print_error(f"An error occurred: {e}")

if __name__ == "__main__":
    main()