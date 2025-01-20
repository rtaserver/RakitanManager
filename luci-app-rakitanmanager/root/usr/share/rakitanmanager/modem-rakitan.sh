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
    modem_info=$(mmcli -L)
    IP=$(ubus call network.interface.$INTERFACEMODEM status | jsonfilter -e '@["ipv4-address"][0].address')
    log "IP Saat Ini: $IP"
    if [ -z "$modem_info" ]; then
        log "Tidak ada modem yang terdeteksi"
        exit 1
    fi
    modem_count=$(echo "$modem_info" | wc -l)
    log "Ditemukan $modem_count modem:"
    while IFS= read -r line; do
        modem_number=$(echo "$line" | grep -o '/org/freedesktop/ModemManager[0-9]*/Modem/[0-9]\+' | grep -o '[0-9]\+$')
        modem_name=$(echo "$line" | sed -n 's/.*\/Modem\/[0-9]\+\s\(.*\)/\1/p')
        
        log "Nama Modem : $modem_name"
        log "Nomer Modem : $modem_number"

        if mmcli -m -$modem_number -r &>/dev/null; then
            log "Modem $modem_number berhasil di-restart"
        else
            log "Gagal restart modem $modem_number"
        fi
    done < <(echo "$modem_info")
    log "Mohon Tunggu.. Sedang Mendapatkan IP Baru."
    if ifup "$INTERFACEMODEM"; then
        log "Interface $INTERFACEMODEM berhasil diaktifkan"
    else
        log "Gagal mengaktifkan interface $INTERFACEMODEM"
        exit 1
    fi
    sleep 20
    NEW_IP=$(ubus call network.interface.$INTERFACEMODEM status | jsonfilter -e '@["ipv4-address"][0].address')
    if [ "$IP" != "$NEW_IP" ]; then
        log "New IP: $NEW_IP"
    else
        log "IP tidak berubah"
    fi
    exit 0
fi