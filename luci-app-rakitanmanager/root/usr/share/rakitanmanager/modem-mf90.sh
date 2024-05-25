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

    response=$(curl -s -X POST "$url" \
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
        --data "$payload")

    echo "$response"
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
    new_ip=$(adb shell ifconfig wlan0 | grep 'inet addr' | cut -d: -f2 | awk '{ print $1}')
    log "New IP: $new_ip"
    echo "New IP: $new_ip"
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
