#!/bin/bash
# Copyright 2024 RTA SERVER

log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Pemeriksaan apakah file konfigurasi Telegram ada
if [ ! -f "/www/rakitanmanager/telegram_config.txt" ]; then
    log "File konfigurasi Telegram tidak ditemukan."
    exit 1
fi

# Pemeriksaan apakah file pesan bot ada
if [ ! -f "/www/rakitanmanager/bot_message.txt" ]; then
    log "File pesan bot tidak ditemukan."
    exit 1
fi

DEVICE_PROCESSOR=$(ubus call system board | grep '\"system\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')
DEVICE_MODEL=$(ubus call system board | grep '\"model\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')
DEVICE_BOARD=$(ubus call system board | grep '\"board_name\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')

# TELEGRAM
TOKEN_ID=$(uci -q get rakitanmanager.telegram.token)
CHAT_ID=$(uci -q get rakitanmanager.telegram.chatid)
CUSTOM_MESSAGE=$(cat /www/rakitanmanager/bot_message.txt)
CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[DEVICE_PROCESSOR\]/$DEVICE_PROCESSOR/g")
CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[DEVICE_MODEL\]/$DEVICE_MODEL/g")
CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[DEVICE_BOARD\]/$DEVICE_BOARD/g")

send_message() {
    local message="$1"
    curl -s -X POST https://api.telegram.org/bot$TOKEN_ID/sendMessage -d chat_id=$CHAT_ID -d text="$message" > /dev/null
}

test_bot() {
    # Kirim pesan uji
    send_message "===============
$(bash /usr/share/rakitanmanager/plugins/syteminfo.sh)
==============="
}


# Baca file JSON
json_file="/www/rakitanmanager/data_modem.json"
jenis_modem=()
nama_modem=()
apn_modem=()
port_modem=()
interface_modem=()
iporbit_modem=()
usernameorbit_modem=()
passwordorbit_modem=()
hostbug_modem=()
devicemodem_modem=()
delayping_modem=()


send_telegram() { #$1 Token - $2 Chat ID - $3 Nama Modem - $4 New IP
    TOKEN="$1"
    CHAT_ID="$2"
    MESSAGE="====== RAKITAN MANAGER ======\nModem : $3\nNew IP : $4"
    MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g')
    curl_response=$(curl -s -X POST \
        "https://api.telegram.org/bot$TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$MESSAGE" \
        -H "Content-Type: application/json"
    )
    if [[ "$curl_response" == *"\"ok\":true"* ]]; then
        log "Pesan telah berhasil terkirim."
    else
        log "Gagal mengirim pesan. Periksa token bot dan ID grup Anda."
    fi
}


parse_json() {
    modems=$(jq -r '.modems | length' "$json_file")
    for ((i = 0; i < modems; i++)); do
        jenis_modem[$i]=$(jq -r ".modems[$i].jenis" "$json_file")
        nama_modem[$i]=$(jq -r ".modems[$i].nama" "$json_file")
        apn_modem[$i]=$(jq -r ".modems[$i].apn" "$json_file")
        port_modem[$i]=$(jq -r ".modems[$i].portmodem" "$json_file")
        interface_modem[$i]=$(jq -r ".modems[$i].interface" "$json_file")
        iporbit_modem[$i]=$(jq -r ".modems[$i].iporbit" "$json_file")
        usernameorbit_modem[$i]=$(jq -r ".modems[$i].usernameorbit" "$json_file")
        passwordorbit_modem[$i]=$(jq -r ".modems[$i].passwordorbit" "$json_file")
        hostbug_modem[$i]=$(jq -r ".modems[$i].hostbug" "$json_file")
        devicemodem_modem[$i]=$(jq -r ".modems[$i].devicemodem" "$json_file")
        delayping_modem[$i]=$(jq -r ".modems[$i].delayping" "$json_file")
    done
}

perform_ping() {
    nama="${1:-}"
    jenis="${2:-}"
    host="${3:-}"
    devicemodem="${4:-}"
    delayping="${5:-}"
    apn="${6:-}"
    portmodem="${7:-}"
    interface="${8:-}"
    iporbit="${9:-}"
    usernameorbit="${10:-}"
    passwordorbit="${11:-}"

    max_attempts=5
    attempt=1

    while true; do
        log_size=$(wc -c < "$log_file")
        max_size=$((2 * 2048))
        if [ "$log_size" -gt "$max_size" ]; then
            # Kosongkan isi file log
            echo -n "" > "$log_file"
            log "Log dibersihkan karena melebihi ukuran maksimum."
        fi

        status_Internet=false

        for pinghost in $host; do
            if [ "$devicemodem" = "" ]; then
                if [[ $(curl -si -m 5 $pinghost | grep -c 'Date:') == "1" ]]; then
                    log "[$jenis - $nama] $pinghost dapat dijangkau"
                    status_Internet=true
                    attempt=1
                else
                    log "[$jenis - $nama] $pinghost tidak dapat dijangkau"
                fi
            else
                if [[ $(curl -sI -m 5 --interface "$devicemodem" "$pinghost" | grep -c 'Date:') == "1" ]]; then
                    log "[$jenis - $nama] $pinghost dapat dijangkau Dengan Interface $devicemodem"
                    status_Internet=true
                    attempt=1
                else
                    log "[$jenis - $nama] $pinghost tidak dapat dijangkau Dengan Interface $devicemodem"
                fi
            fi
        done

        if [ "$status_Internet" = false ]; then
            if [ "$jenis" = "rakitan" ]; then
                log "[$jenis - $nama] Internet mati. Percobaan $attempt/$max_attempts"
                if [ "$attempt" = "1" ]; then
                    log "[$jenis - $nama] Mengaktifkan Mode Pesawat"
                    echo AT+CFUN=4 | atinout - "$portmodem" -
                    sleep 5
                elif [ "$attempt" = "2" ]; then
                    log "[$jenis - $nama] Mencoba Menghubungkan Kembali Modem Dengan APN : $apn"
                    modem_info=$(mmcli -L)
                    modem_number=$(echo "$modem_info" | awk -F 'Modem/' '{print $2}' | awk '{print $1}')
                    mmcli -m "$modem_number" --simple-connect="apn=$apn"
                    ifdown "$interface"
                    sleep 5
                    ifup "$interface"
                elif [ "$attempt" = "3" ]; then
                    log "[$jenis - $nama] Restart Modem Manager"
                    /etc/init.d/modemmanager restart
                    sleep 5
                elif [ "$attempt" = "4" ]; then
                    log "[$jenis - $nama] Mencoba Menghubungkan Kembali Modem Dengan APN : $apn"
                    modem_info=$(mmcli -L)
                    modem_number=$(echo "$modem_info" | awk -F 'Modem/' '{print $2}' | awk '{print $1}')
                    mmcli -m "$modem_number" --simple-connect="apn=$apn"
                    ifdown "$interface"
                    sleep 5
                    ifup "$interface"
                fi
                attempt=$((attempt + 1))
                
                if [ $attempt -ge $max_attempts ]; then
                    log "[$jenis - $nama] Upaya maksimal tercapai. Internet masih mati. Restart modem akan dijalankan"
                    echo AT^RESET | atinout - "$portmodem" - || echo AT+CFUN=1,1 | atinout - "$portmodem" -
                    sleep 20 && ifdown "$interface" && ifup "$interface"
                    attempt=1
                fi
                new_rakitan_ip=$(ifconfig $devicemodem | grep inet | grep -v inet6 | awk '{print $2}' | awk -F : '{print $2}')
                log "[$jenis - $nama] New IP: $new_rakitan_ip"
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[IP\]/$new_rakitan_ip/g")
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[NAMAMODEM\]/$nama/g")
                if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                    send_message "$CUSTOM_MESSAGE"
                fi
            elif [ "$jenis" = "hp" ]; then
                log "[$jenis - $nama] Mencoba Menghubungkan Kembali"
                log "[$jenis - $nama] Mengaktifkan Mode Pesawat"
                adb shell cmd connectivity airplane-mode enable
                sleep 2
                log "[$jenis - $nama] Menonaktifkan Mode Pesawat"
                adb shell cmd connectivity airplane-mode disable
                sleep 7
                new_ip_hp=$(adb shell ip addr show rmnet_data0 | grep 'inet ' | awk '{print $2}' | cut -d / -f 1)
                log "[$jenis - $nama] New IP = $new_ip_hp"
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[IP\]/$new_ip_hp/g")
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[NAMAMODEM\]/$nama/g")
                if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                    send_message "$CUSTOM_MESSAGE"
                fi
            elif [ "$jenis" = "orbit" ]; then
                log "[$jenis - $nama] Mencoba Menghubungkan Kembali Modem Orbit / Huawei"
                python3 /usr/bin/modem-orbit.py $nama $iporbit $usernameorbit $passwordorbit
                log "[$jenis - $nama] New IP $(cat /tmp/ip_orbit.txt)"
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[IP\]/$(< /tmp/{$nama}ip_orbit.txt)/g")
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[NAMAMODEM\]/$nama/g")
                if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                    send_message "$CUSTOM_MESSAGE"
                fi
            fi
        fi
        sleep "$delayping"
    done
}

main() {
    parse_json

    # Loop through each modem and perform actions
    for ((i = 0; i < ${#jenis_modem[@]}; i++)); do
        perform_ping "${nama_modem[$i]}" "${jenis_modem[$i]}" "${hostbug_modem[$i]}" "${devicemodem_modem[$i]}" "${delayping_modem[$i]}" "${apn_modem[$i]}" "${port_modem[$i]}" "${interface_modem[$i]}" "${iporbit_modem[$i]}" "${usernameorbit_modem[$i]}" "${passwordorbit_modem[$i]}" &
    done
}

rakitanmanager_stop() {
    if pidof rakitanmanager.sh > /dev/null; then
        killall -9 rakitanmanager.sh
        log "RakitanManager Berhasil Di Hentikan."
    else
        log "RakitanManager is not running."
    fi
}

while getopts ":skrpcvh" rakitanmanager ; do
    case $rakitanmanager in
        s)
            main
            ;;
        k)
            rakitanmanager_stop
            ;;
    esac
done

action="$1"

# Evaluasi aksi yang diterima
case $action in
    "bot_test")
        test_bot
        ;;
#    *)
#        log "Usage: $0 [bot_test]"
#        exit 1
#        ;;
esac
