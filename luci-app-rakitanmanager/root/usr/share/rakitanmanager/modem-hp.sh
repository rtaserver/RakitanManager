#!/bin/bash
# Copyright 2024 RTA SERVER

log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

if ! command -v adb &> /dev/null; then
    log "ADB tidak ditemukan. Pastikan Android Debug Bridge (ADB) telah diinstal."
    exit 1
fi

# Periksa koneksi ADB
devices=$(adb devices | sed -n '2p')
if [[ -z "$devices" || "$devices" == *"unauthorized"* ]]; then
    echo "ADB device not connected or unauthorized."
    exit 1
fi

if [ -z "$1" ]; then
	log "ADBID tidak disetel, menggunakan default..."
	ADBID=$(adb devices | grep 'device' | grep -v 'List of' | awk {'print $1'}) # Default device_id if $1 unset
else
	ADBID="$1"
fi

if [ "$2" = "restart" ]; then
    for IPX in ${ADBID}
    do
        log "Menghubungkan ke perangkat ${IPX}..." 
        log "Mode pesawat akan diaktifkan dalam 3 detik..."
        if [ "$3" = "v1" ]; then
            adb -s "$IPX" shell settings put global airplane_mode_on 1 &>/dev/null
        fi
        if [ "$3" = "v2" ]; then
            adb -s "$IPX" shell cmd connectivity airplane-mode enable &>/dev/null
        fi
        adb -s "$IPX" shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true &>/dev/null
        sleep "3" &>/dev/null
        log "Menonaktifkan mode pesawat untuk mendapatkan IP baru dan jaringan yang diperbarui..."
        if [ "$3" = "v1" ]; then
            adb -s "$IPX" shell settings put global airplane_mode_on 0 &>/dev/null
        fi
        if [ "$3" = "v2" ]; then
            adb -s "$IPX" shell cmd connectivity airplane-mode disable &>/dev/null
        fi
        adb -s "$IPX" shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false &>/dev/null
        log "ID [${IPX}] : Penyegaran jaringan selesai...!!"
        exit 0
    done
fi

if [ "$2" = "myip" ]; then
    # Jalankan perintah adb untuk mendapatkan informasi jaringan perangkat
    for IPX in ${ADBID}
    do
        ip_output=$(adb -s "$IPX" shell ip addr show)
        ip_addr=$(echo "$ip_output" | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | awk '{print $2}' | head -n 1)
        
        # Jika alamat IP kosong, tetapkan "Tidak tersedia"
        if [[ -z "$ip_addr" ]]; then
            ip_addr="Unavailable"
        fi
        
        log "New IP: $ip_addr"
        echo "New IP: $ip_addr"
    done
fi