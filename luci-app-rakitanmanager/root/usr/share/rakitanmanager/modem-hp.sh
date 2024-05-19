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

if [ -z "$1" ]; then
	log "ADBID tidak disetel, menggunakan default..."
	ADBID=$(adb devices | grep 'device' | grep -v 'List of' | awk {'print $1'}) # Default device_id if $1 unset
else
	ADBID="$1"
fi

for IPX in ${ADBID}
do
	log "Menghubungkan ke perangkat ${IPX}..." 
    log "Mode pesawat akan diaktifkan dalam 3 detik..."
    if [[ "$(adb -s ${IPX} shell settings get global airplane_mode_on)" == "0" ]]; then
    	adb -s "$IPX" settings put global airplane_mode_on 1 &>/dev/null
    	adb -s "$IPX" am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true &>/dev/null
    fi
    if [[ "$(adb -s ${IPX} shell cmd connectivity airplane-mode)" == "disabled" ]]; then
    	adb -s "$IPX" shell cmd connectivity airplane-mode enable &>/dev/null
    fi
    sleep "3" &>/dev/null

    log "Menonaktifkan mode pesawat untuk mendapatkan IP baru dan jaringan yang diperbarui..."
    if [[  "$(adb -s ${IPX} shell settings get global airplane_mode_on)" == "1" ]]; then
    	adb -s "$IPX" settings put global airplane_mode_on 0 &>/dev/null
    	adb -s "$IPX" am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false &>/dev/null
    fi
    if [[ "$(adb -s ${IPX} shell cmd connectivity airplane-mode)" == "enabled" ]]; then
    	adb -s "$IPX" shell cmd connectivity airplane-mode disable &>/dev/null
    fi
    log "ID [${IPX}] : Penyegaran jaringan selesai...!!"
    exit 0
done

# if [ "$2" = "myip" ]; then
#     # Jalankan perintah adb untuk mendapatkan informasi jaringan perangkat
#     network_info=$(adb -s ${IPX} shell ip addr show)

#     # Cari baris yang berisi alamat IP
#     ip_address_line=$(echo "$network_info" | grep 'inet ' | grep -v '127.0.0.1')

#     # Jika ditemukan baris yang berisi alamat IP
#     if [ -n "$ip_address_line" ]; then
#         # Ambil alamat IP dari baris tersebut
#         ip_address=$(echo "$ip_address_line" | awk '{print $2}')
#         echo "$ip_address"
#         exit 0
#     else
#         log "Tidak dapat menemukan alamat IP perangkat."
#         exit 1
#     fi
# fi