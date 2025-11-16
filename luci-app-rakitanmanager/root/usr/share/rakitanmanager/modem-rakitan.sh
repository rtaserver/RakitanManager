#!/bin/bash
# Copyright 2024 RTA SERVER

log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

DEVICEMODEM="$2"
PORTMODEM="$3"
INTERFACEMODEM="$4"

if [ "$1" = "renew" ]; then
    log "Starting modem renewal process for interface $INTERFACEMODEM"

    # Get current IP
    IP=$(ubus call network.interface.$INTERFACEMODEM status 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address')
    if [ -z "$IP" ]; then
        log "Failed to get current IP for interface $INTERFACEMODEM"
        exit 1
    fi
    log "Current IP: $IP"

    # Check for available modems
    modem_info=$(mmcli -L 2>/dev/null)
    if [ -z "$modem_info" ]; then
        log "No modems detected by ModemManager"
        exit 1
    fi

    # Count modems (excluding header line)
    modem_count=$(echo "$modem_info" | grep -c "/org/freedesktop/ModemManager")
    log "Found $modem_count modem(s)"

    # Process each modem
    modem_found=false
    while IFS= read -r line; do
        if [[ "$line" == *"/org/freedesktop/ModemManager"* ]]; then
            modem_path=$(echo "$line" | awk '{print $1}')
            modem_name=$(echo "$line" | sed 's/.*\/Modem\/[0-9]\+\s*//')
            modem_number=$(echo "$modem_path" | grep -o '[0-9]\+$')

            log "Processing modem: $modem_name (ID: $modem_number)"

            # Try to restart the modem
            # if mmcli -m "$modem_number" --reset >/dev/null 2>&1; then
            #     log "Modem $modem_number ($modem_name) reset successfully"
            #     modem_found=true
            # else
            #     log "Failed to reset modem $modem_number ($modem_name)"
            # fi

            # Try Airplane Mode
            if echo AT+CFUN=4 | atinout - "$PORTMODEM" - >/dev/null; then
                log "Modem $modem_number ($modem_name) reset successfully"
                modem_found=true
            else
                log "Failed to Airplane modem $modem_number ($modem_name)"
            fi
        fi
    done < <(echo "$modem_info")

    if [ "$modem_found" = false ]; then
        log "No modems were successfully reset"
        exit 1
    fi

    # Bring interface down and up to get new IP
    log "Restarting network interface $INTERFACEMODEM to obtain new IP"
    if ifdown "$INTERFACEMODEM" 2>/dev/null; then
        log "Interface $INTERFACEMODEM brought down successfully"
    else
        log "Warning: Failed to bring down interface $INTERFACEMODEM"
    fi

    sleep 5

    if ifup "$INTERFACEMODEM" 2>/dev/null; then
        log "Interface $INTERFACEMODEM brought up successfully"
    else
        log "Failed to bring up interface $INTERFACEMODEM"
        exit 1
    fi

    # Wait for IP assignment
    log "Waiting for new IP assignment..."
    sleep 30

    # Check new IP
    NEW_IP=$(ubus call network.interface.$INTERFACEMODEM status 2>/dev/null | jsonfilter -e '@["ipv4-address"][0].address')
    if [ -n "$NEW_IP" ] && [ "$IP" != "$NEW_IP" ]; then
        log "IP successfully renewed: $NEW_IP"
        echo "New IP: $NEW_IP"
        exit 0
    elif [ -n "$NEW_IP" ] && [ "$IP" = "$NEW_IP" ]; then
        log "IP did not change: $NEW_IP"
        echo "New IP: $NEW_IP"
        exit 0
    else
        log "Failed to obtain new IP address"
        exit 1
    fi
elif [ "$1" = "status" ]; then
    # Add status check functionality
    modem_info=$(mmcli -L 2>/dev/null)
    if [ -z "$modem_info" ]; then
        log "No modems detected"
        echo "No modems detected"
        exit 1
    fi

    modem_count=$(echo "$modem_info" | grep -c "/org/freedesktop/ModemManager")
    log "Found $modem_count modem(s)"
    echo "Found $modem_count modem(s)"

    while IFS= read -r line; do
        if [[ "$line" == *"/org/freedesktop/ModemManager"* ]]; then
            modem_path=$(echo "$line" | awk '{print $1}')
            modem_name=$(echo "$line" | sed 's/.*\/Modem\/[0-9]\+\s*//')
            modem_number=$(echo "$modem_path" | grep -o '[0-9]\+$')

            # Get modem status
            modem_status=$(mmcli -m "$modem_number" --state 2>/dev/null | grep "state:" | awk '{print $3}')
            if [ -n "$modem_status" ]; then
                log "Modem $modem_number ($modem_name): $modem_status"
                echo "Modem $modem_number ($modem_name): $modem_status"
            else
                log "Failed to get status for modem $modem_number"
                echo "Modem $modem_number ($modem_name): Unknown"
            fi
        fi
    done < <(echo "$modem_info")
    exit 0
else
    log "Usage: $0 {renew|status} [devicemodem] [portmodem] [interface]"
    echo "Usage: $0 {renew|status} [devicemodem] [portmodem] [interface]"
    exit 1
fi
