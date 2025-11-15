import logging
import sys
from huawei_lte_api.Client import Client
from huawei_lte_api.Connection import Connection
from huawei_lte_api.exceptions import ResponseErrorException, LoginErrorException
import time

# Set up logging
logging.basicConfig(
    filename='/var/log/rakitanmanager.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def log(message):
    """Log message to file and print to stdout."""
    logging.info(message)
    print(message)

def get_wan_info(client):
    """Get WAN IP address and device name with error handling."""
    try:
        wan_info = client.device.information()
        wan_ip_address = wan_info.get('WanIPAddress')
        device_name = wan_info.get('DeviceName')
        return wan_ip_address, device_name
    except Exception as e:
        log(f"Failed to get WAN info: {e}")
        return None, None

def fetch_wan_info(client, max_retries=5, retry_delay=2):
    """Fetch WAN IP address and device name with retries."""
    wan_ip_address = None
    device_name = None
    retries = 0

    while not (wan_ip_address and device_name) and retries < max_retries:
        wan_ip_address, device_name = get_wan_info(client)
        if not (wan_ip_address and device_name):
            retries += 1
            log(f"Retry {retries}/{max_retries} to get WAN info...")
            time.sleep(retry_delay)

    if not (wan_ip_address and device_name):
        raise Exception("Failed to retrieve WAN IP and device name after maximum retries")

    return wan_ip_address, device_name

def initiate_ip_change(client):
    """Initiate IP change process with proper error handling."""
    try:
        # Try multiple methods to trigger IP change
        log("Attempting to trigger IP change via PLMN list...")
        response = client.net.plmn_list()

        # Alternative method: try to reconnect
        log("Attempting to reconnect...")
        try:
            client.net.net_mode({'NetworkMode': '00', 'NetworkBand': '3FFFFFFF', 'LTEBand': '7FFFFFFFFFFFFFFF'})
            time.sleep(2)
            client.net.net_mode({'NetworkMode': '03', 'NetworkBand': '3FFFFFFF', 'LTEBand': '7FFFFFFFFFFFFFFF'})
        except Exception as e:
            log(f"Network mode switching failed: {e}")

        return True
    except Exception as e:
        log(f"Failed to initiate IP change: {e}")
        return False

def print_header(title, creator):
    """Print section header."""
    header = f"{'=' * 40}\n{title.center(40)}\n{'=' * 40}\nScript created by: {creator}\n"
    print(header)
    log(f"Started: {title}")

def print_result(label, value):
    """Print result."""
    result = f"{label}: {value}"
    print(result)
    log(result)

def print_success(message):
    """Print success message."""
    success_msg = f"SUCCESS: {message}"
    print("\n\033[92m" + success_msg + "\033[0m")
    log(success_msg)

def print_error(message):
    """Print error message."""
    error_msg = f"ERROR: {message}"
    print("\n\033[91m" + error_msg + "\033[0m")
    log(error_msg)

def validate_arguments():
    """Validate command line arguments."""
    if len(sys.argv) != 4:
        print_error("Usage: python3 modem-orbit.py <router_ip> <username> <password>")
        sys.exit(1)

    router_ip = sys.argv[1]
    username = sys.argv[2]
    password = sys.argv[3]

    if not router_ip or not username or not password:
        print_error("All arguments (router_ip, username, password) are required")
        sys.exit(1)

    return router_ip, username, password

def main():
    """Main function with comprehensive error handling."""
    try:
        router_ip, username, password = validate_arguments()

        connection_url = f'http://{username}:{password}@{router_ip}/'

        log(f"Connecting to Huawei modem at {router_ip}")

        with Connection(connection_url, timeout=30) as connection:
            client = Client(connection)

            print_header("Auto Reconnect Modem Huawei", "@RTASERVER")

            # Get initial WAN info
            log("Retrieving initial WAN information...")
            wan_ip_address, device_name = fetch_wan_info(client)
            print_result("Device Name", device_name)
            print_result("Current IP", wan_ip_address)
            initial_ip = wan_ip_address

            # Initiate IP change
            if not initiate_ip_change(client):
                print_error("Failed to initiate IP change process")
                sys.exit(1)

            # Wait for IP change
            log("Waiting for IP change to complete...")
            time.sleep(10)  # Increased wait time

            # Check for new IP with retries
            max_ip_checks = 6
            new_ip_found = False

            for check in range(max_ip_checks):
                log(f"Checking for new IP (attempt {check + 1}/{max_ip_checks})...")
                try:
                    wan_ip_address_after, _ = fetch_wan_info(client, max_retries=3, retry_delay=1)
                    print_result("Current IP", wan_ip_address_after)

                    if wan_ip_address_after != initial_ip and wan_ip_address_after:
                        print_success(f"IP successfully changed from {initial_ip} to {wan_ip_address_after}")
                        print(f"New IP: {wan_ip_address_after}")
                        new_ip_found = True
                        break
                    else:
                        log("IP has not changed yet, waiting...")
                        time.sleep(10)
                except Exception as e:
                    log(f"Error during IP check: {e}")
                    time.sleep(5)

            if not new_ip_found:
                print_error("IP change process completed but IP did not change")
                sys.exit(1)

    except LoginErrorException as e:
        print_error(f"Login failed: Invalid credentials for modem at {router_ip}")
        log(f"Login error: {e}")
        sys.exit(1)
    except ResponseErrorException as e:
        print_error(f"Modem API error: {e}")
        log(f"Response error: {e}")
        sys.exit(1)
    except Exception as e:
        print_error(f"An unexpected error occurred: {e}")
        log(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
