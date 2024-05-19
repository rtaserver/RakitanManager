#!/bin/bash
# Copyright 2024 RTA SERVER

log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

DEVICEMODEM="$2"
PORTMODEM="$3"

if [ "$1" = "renew" ]; then
    IP=$(ifconfig "$DEVICEMODEM" | grep inet | grep -v inet6 | awk '{print $2}')
    log "IP Saat Ini: $IP"
    echo AT+CFUN=4 | atinout - "$PORTMODEM" - >/dev/null
    log "Mohon Tunggu.. Sedang Mendapatkan IP Baru."
    sleep 20
    IP=$(ifconfig "$DEVICEMODEM" | grep inet | grep -v inet6 | awk '{print $2}')
    log "New IP: $IP"
    exit 0
fi

if [ "$1" = "restart" ]; then
    IP=$(ifconfig "$DEVICEMODEM" | grep inet | grep -v inet6 | awk '{print $2}')
    log "IP Saat Ini: $IP"
    echo AT^RESET | atinout - "$PORTMODEM" - >/dev/null
    log "Mohon Tunggu.. Sedang Mendapatkan IP Baru."
    sleep 35
    IP=$(ifconfig "$DEVICEMODEM" | grep inet | grep -v inet6 | awk '{print $2}')
    log "New IP: $IP"
    exit 0
fi