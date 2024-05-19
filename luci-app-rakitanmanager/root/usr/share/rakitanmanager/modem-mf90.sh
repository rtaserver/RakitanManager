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

LOGIN_RESPONSE=$(curl -s -i -X POST "http://${MODEM_IP}/api/user/login" \
  -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
  -d "username=${USERNAME}&password=${PASSWORD}")

COOKIE=$(echo "$LOGIN_RESPONSE" | grep "Set-Cookie" | awk -F ": " '{print $2}' | tr -d '\r')

if [[ -z "$COOKIE" ]]; then
  log "Login gagal. Modem Belum Support."
  exit 1
fi

RESTART_RESPONSE=$(curl -s -X POST "http://${MODEM_IP}/api/device/control" \
  -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
  -H "Cookie: $COOKIE" \
  -d "operation=restart")

if echo "$RESTART_RESPONSE" | grep -q "OK"; then
  log "Perintah restart modem berhasil dikirim."
  log "Mohon Tunggu..."
  sleep 5
  exit 0
else
  log "Gagal mengirim perintah restart. Periksa pengaturan modem Anda."
  exit 1
fi
