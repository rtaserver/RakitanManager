#!/bin/bash
# Copyright 2024 RTA SERVER

log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

MODEM_IP="$1"
USERNAME="$2"
PASSWORD="$3"

send_request() {
    local ip="$MODEM_IP"
    local payload="$1"
    local url="http://$ip/goform/goform_set_cmd_process"
    local response
    local max_retries=3
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        response=$(curl -s --connect-timeout 10 --max-time 30 -X POST "$url" \
            -H "Accept: application/json, text/javascript, */*; q=0.01" \
            -H "Accept-Encoding: gzip, deflate" \
            -H "Accept-Language: en-US,en;q=0.9" \
            -H "Connection: keep-alive" \
            -H "Content-Length: ${#payload}" \
            -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
            -H "DNT: 1" \
            -H "Host: $ip" \
            -H "Origin: http://$ip" \
            -H "Referer: http://$ip/index.html" \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36" \
            -H "X-Requested-With: XMLHttpRequest" \
            --data "$payload" 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$response" ]; then
            echo "$response"
            return 0
        else
            retry_count=$((retry_count + 1))
            log "Request failed (attempt $retry_count/$max_retries), retrying in 2 seconds..."
            sleep 2
        fi
    done

    log "Request failed after $max_retries attempts"
    echo "error"
    return 1
}

check_success() {
    local response="$1"
    if [[ "$response" == *"error"* ]]; then
        log "Operation failed: $response"
        return 1
    else
        log "Operation successful: $response"
        return 0
    fi
}

login() {
    local payload="isTest=false&goformId=LOGIN&password=$(echo -n "${PASSWORD}" | base64)"
    log "Login Modem..."
    response=$(send_request "$payload")
    if check_success "$response"; then
        log "Login successful."
    else
        log "Login failed."
        exit 1
    fi
}

disable_wifi() {
    local payload="isTest=false&goformId=SET_WIFI_INFO&wifiEnabled=0"
    log "Disabling WiFi..."
    response=$(send_request "$payload")
    if check_success "$response"; then
        log "WiFi disabled successfully."
    else
        log "Failed to disable WiFi."
        exit 1
    fi
}

enable_wifi() {
    local payload="isTest=false&goformId=SET_WIFI_INFO&wifiEnabled=1"
    log "Enabling WiFi..."
    response=$(send_request "$payload")
    if check_success "$response"; then
        log "WiFi enabled successfully."
    else
        log "Failed to enable WiFi."
        exit 1
    fi
}

reboot() {
    local payload="isTest=false&goformId=REBOOT_DEVICE"
    log "Reboot Modem..."
    response=$(send_request "$payload")
    if check_success "$response"; then
        log "Reboot successful."
    else
        log "Reboot failed."
        exit 1
    fi
}

get_new_ip() {
    log "Getting new IP address after reboot..."
    sleep 60 # Waktu tunggu untuk reboot selesai

    # Try multiple methods to get IP address
    new_ip=""

    # Method 1: Try wlan0 interface
    if command -v adb &> /dev/null; then
        log "Attempting to get IP via ADB wlan0 interface..."
        new_ip=$(adb shell ifconfig wlan0 2>/dev/null | grep 'inet addr' | cut -d: -f2 | awk '{ print $1}' | head -1)
    fi

    # Method 2: Try usb0 interface (common for MF90)
    if [ -z "$new_ip" ] && command -v adb &> /dev/null; then
        log "Attempting to get IP via ADB usb0 interface..."
        new_ip=$(adb shell ifconfig usb0 2>/dev/null | grep 'inet addr' | cut -d: -f2 | awk '{ print $1}' | head -1)
    fi

    # Method 3: Try modem web interface
    if [ -z "$new_ip" ]; then
        log "Attempting to get IP via modem web interface..."
        status_response=$(curl -s --connect-timeout 10 --max-time 30 "http://$MODEM_IP/goform/goform_get_cmd_process?cmd=wan_ip_addr" 2>/dev/null)
        if [[ "$status_response" == *"wan_ip_addr"* ]]; then
            new_ip=$(echo "$status_response" | grep -o '"wan_ip_addr":"[^"]*"' | cut -d'"' -f4)
        fi
    fi

    # Method 4: Try system ifconfig (if running on router)
    if [ -z "$new_ip" ]; then
        log "Attempting to get IP via system ifconfig..."
        # Try common interface names
        for interface in wlan0 usb0 eth1 ppp0; do
            ip_addr=$(ifconfig "$interface" 2>/dev/null | grep 'inet addr' | cut -d: -f2 | awk '{ print $1}' | head -1)
            if [ -n "$ip_addr" ]; then
                new_ip="$ip_addr"
                log "Found IP on interface $interface: $new_ip"
                break
            fi
        done
    fi

    if [ -n "$new_ip" ]; then
        log "New IP: $new_ip"
        echo "New IP: $new_ip"
    else
        log "Failed to retrieve new IP address"
        echo "New IP: Unavailable"
    fi
}

# Argumen untuk menentukan tindakan
action="$4"

# Login ke modem
login
sleep 2

case "$action" in
    disable_wifi)
        disable_wifi
        ;;
    enable_wifi)
        enable_wifi
        ;;
    reboot)
        reboot
        get_new_ip
        ;;
    *)
        log "Tindakan tidak valid: $action"
        echo "Penggunaan: $0 <MODEM_IP> <USERNAME> <PASSWORD> <action>"
        echo "Tindakan yang tersedia: disable_wifi, enable_wifi, reboot"
        exit 1
        ;;
esac

exit 0
