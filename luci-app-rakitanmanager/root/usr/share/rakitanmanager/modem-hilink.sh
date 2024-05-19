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

get_auth_token() {
    curl -s "http://${MODEM_IP}/api/webserver/SesTokInfo" | grep -oP "(?<=<SesInfo>)[^<]+" | tr -d '\n'
}

login() {
    TOKEN=$(get_auth_token)
    RESPONSE=$(curl -s -X POST "http://${MODEM_IP}/api/user/login" \
        -H "__RequestVerificationToken: $TOKEN" \
        -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><Username>${USERNAME}</Username><Password>$(echo -n "${PASSWORD}" | base64)</Password></request>")
    echo "$RESPONSE" | grep -q "<response>OK</response>"
}

restart_modem() {
    TOKEN=$(get_auth_token)
    RESPONSE=$(curl -s -X POST "http://${MODEM_IP}/api/device/control" \
        -H "__RequestVerificationToken: $TOKEN" \
        -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><Control>1</Control></request>")
    echo "$RESPONSE" | grep -q "<response>OK</response>"
}

if login; then
    log "Login berhasil."
    if restart_modem; then
        log "Perintah restart berhasil dikirim."
        log "Mohon Tunggu..."
        sleep 5
        exit 0
    else
        log "Gagal mengirim perintah restart."
        exit 1
    fi
else
    log "Login gagal. Modem Belum Support."
    exit 1
fi
