#!/bin/bash
# Copyright 2024 RTA SERVER

log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

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

RAKITANPLUGINS="/usr/share/rakitanmanager/plugins"
test_bot() {
    # Kirim pesan uji
    send_message "===============
$(bash $RAKITANPLUGINS/systeminfo.sh)
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
metodeping_modem=()
hostbug_modem=()
androidid_modem=()
devicemodem_modem=()
delayping_modem=()
script_modem=()


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
        metodeping_modem[$i]=$(jq -r ".modems[$i].metodeping" "$json_file")
        hostbug_modem[$i]=$(jq -r ".modems[$i].hostbug" "$json_file")
        androidid_modem[$i]=$(jq -r ".modems[$i].androidid" "$json_file")
        devicemodem_modem[$i]=$(jq -r ".modems[$i].devicemodem" "$json_file")
        delayping_modem[$i]=$(jq -r ".modems[$i].delayping" "$json_file")
        script_modem[$i]=$(jq -r ".modems[$i].script" "$json_file")
    done
}

perform_ping() {
    nama="${1:-}"
    jenis="${2:-}"
    motodeping="${3:-}"
    host="${4:-}"
    androidid="${5:-}"
    devicemodem="${6:-}"
    delayping="${7:-}"
    if [ -z "$delayping" ]; then
	    delayping="10"
    fi
    apn="${8:-}"
    portmodem="${9:-}"
    interface="${10:-}"
    iporbit="${11:-}"
    usernameorbit="${12:-}"
    passwordorbit="${13:-}"
    script="${14:-}"

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
            # Parsing host dan port dari pinghost
            xhost=$(echo "${pinghost}" | cut -d':' -f1)
            xport=$(echo "${pinghost}" | cut -d':' -f2)

            # Set port default jika tidak ada port yang diberikan
            if [ "$port" = "" ]; then
                port_icmp=0  # ICMP tidak menggunakan port
                port_tcp=80
                port_http=80
                port_https=443
            else
                port_icmp=$port
                port_tcp=$port
                port_http=$port
                port_https=$port
            fi
            if [ "$devicemodem" = "" ]; then

                if [ "$motodeping" = "icmp" ]; then
                    # ICMP ping
                    ping -q -c 3 -W 3 -p $port_icmp ${xhost} > /dev/null
                    if [ $? -eq 0 ]; then
                        log "[$jenis - $nama] ICMP ping to $pinghost succeeded"
                        status_Internet=true
                        attempt=1
                    else
                        log "[$jenis - $nama] ICMP ping to $pinghost failed"
                    fi
                elif [ "$motodeping" = "tcp" ]; then
                     # TCP ping
                    if nc -zvw 1 ${xhost} $port_tcp 2>&1 | grep -q succeeded; then
                        log "[$jenis - $nama] TCP ping to $pinghost succeeded"
                        status_Internet=true
                        attempt=1
                    else
                        log "[$jenis - $nama] TCP ping to $pinghost failed"
                    fi
                elif [ "$motodeping" = "http" ]; then
                    # HTTP ping
                    if curl -Is http://${xhost}:${port_http} >/dev/null; then
                        log "[$jenis - $nama] HTTP ping to $pinghost succeeded"
                        status_Internet=true
                        attempt=1
                    else
                        log "[$jenis - $nama] HTTP ping to $pinghost failed"
                    fi
                elif [ "$motodeping" = "https" ]; then
                    # HTTPS ping
                    if curl -Is https://${xhost}:${port_https} >/dev/null; then
                        log "[$jenis - $nama] HTTPS ping to $pinghost succeeded"
                        status_Internet=true
                        attempt=1
                    else
                        log "[$jenis - $nama] HTTPS ping to $pinghost failed"
                    fi
                fi
            else
                if [ "$motodeping" = "icmp" ]; then
                    # ICMP ping dengan antarmuka kustom
                    ping -q -c 3 -W 3 -I ${devicemodem} ${xhost} > /dev/null
                    if [ $? -eq 0 ]; then
                        log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem succeeded"
                        status_Internet=true
                        attempt=1
                    else
                        log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem failed"
                    fi
                elif [ "$motodeping" = "tcp" ]; then
                    # TCP ping dengan antarmuka kustom
                    if nc -zvw 1 -e /bin/true -g 1 -G 1 -I ${devicemodem} ${xhost} $port_tcp 2>&1 | grep -q succeeded; then
                        log "[$jenis - $nama] TCP ping to $pinghost on interface $devicemodem succeeded"
                        status_Internet=true
                        attempt=1
                    else
                        log "[$jenis - $nama] TCP ping to $pinghost on interface $devicemodem failed"
                        # HTTP ping dengan antarmuka kustom
                    fi
                elif [ "$motodeping" = "http" ]; then
                    # HTTP ping dengan antarmuka kustom
                    if curl -Is http://${xhost}:${port_http} --interface ${devicemodem} >/dev/null; then
                        log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem succeeded"
                        status_Internet=true
                        attempt=1
                    else
                        log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem failed"
                    fi
                elif [ "$motodeping" = "https" ]; then
                    # HTTPS ping dengan antarmuka kustom
                    if curl -Is https://${xhost}:${port_https} --interface ${devicemodem} >/dev/null; then
                        log "[$jenis - $nama] HTTPS ping to $pinghost on interface $devicemodem succeeded"
                        status_Internet=true
                        attempt=1
                    else
                        log "[$jenis - $nama] HTTPS ping to $pinghost on interface $devicemodem failed"
                    fi
                fi
            fi
        done

        if [ "$status_Internet" = false ]; then
            if [ "$jenis" = "rakitan" ]; then
                log "[$jenis - $nama] Internet mati. Percobaan $attempt/$max_attempts"
                log "[$jenis - $nama] Mengaktifkan Mode Pesawat"
                echo AT+CFUN=4 | atinout - "$portmodem" -
                # if [ "$attempt" = "1" ]; then
                #     log "[$jenis - $nama] Mengaktifkan Mode Pesawat"
                #     echo AT+CFUN=4 | atinout - "$portmodem" -
                # elif [ "$attempt" = "2" ]; then
                #     log "[$jenis - $nama] Mencoba Menghubungkan Kembali Modem Dengan APN : $apn"
                #     modem_info=$(mmcli -L)
                #     modem_number=$(echo "$modem_info" | awk -F 'Modem/' '{print $2}' | awk '{print $1}')
                #     mmcli -m "$modem_number" --simple-connect="apn=$apn"
                #     ifdown "$interface"
                #     sleep 3
                #     ifup "$interface"
                # elif [ "$attempt" = "3" ]; then
                #     log "[$jenis - $nama] Restart Modem Manager"
                #     /etc/init.d/modemmanager restart
                # elif [ "$attempt" = "4" ]; then
                #     log "[$jenis - $nama] Mencoba Menghubungkan Kembali Modem Dengan APN : $apn"
                #     modem_info=$(mmcli -L)
                #     modem_number=$(echo "$modem_info" | awk -F 'Modem/' '{print $2}' | awk '{print $1}')
                #     mmcli -m "$modem_number" --simple-connect="apn=$apn"
                #     ifdown "$interface"
                #     sleep 5
                #     ifup "$interface"
                # fi

                attempt=$((attempt + 1))

                if [ $attempt -ge $max_attempts ]; then
                    log "[$jenis - $nama] Upaya maksimal tercapai. Internet masih mati. Restart modem akan dijalankan"
                    echo AT^RESET | atinout - "$portmodem" - || echo AT+CFUN=1,1 | atinout - "$portmodem" -
                    sleep 20 && ifdown "$interface" && ifup "$interface"
                    attempt=1
                    sleep 5
                    new_rakitan_ip=$(ifconfig $devicemodem | grep inet | grep -v inet6 | awk '{print $2}' | awk -F : '{print $2}')
                    log "[$jenis - $nama] New IP: $new_rakitan_ip"
                    CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[IP\]/$new_rakitan_ip/g")
                    CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[NAMAMODEM\]/$nama/g")
                    if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                        curl -s -X POST https://api.telegram.org/bot$TOKEN_ID/sendMessage -d chat_id=$CHAT_ID -d text="$CUSTOM_MESSAGE" > /dev/null
                    fi
                fi

                sleep 5
                new_rakitan_ip=$(ifconfig $devicemodem | grep inet | grep -v inet6 | awk '{print $2}' | awk -F : '{print $2}')
                log "[$jenis - $nama] New IP: $new_rakitan_ip"
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[IP\]/$new_rakitan_ip/g")
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[NAMAMODEM\]/$nama/g")
                if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                    curl -s -X POST https://api.telegram.org/bot$TOKEN_ID/sendMessage -d chat_id=$CHAT_ID -d text="$CUSTOM_MESSAGE" > /dev/null
                fi
            elif [ "$jenis" = "hp" ]; then
                $RAKITANPLUGINS/adb-refresh-network.sh $androidid
                sleep 3
                new_ip_hp=$(adb shell ip addr show rmnet_data0 | grep 'inet ' | awk '{print $2}' | cut -d / -f 1)
                if [ -z "$new_ip_hp" ]; then
	                new_ip_hp=$(adb shell ip addr show rmnet_data1 | grep 'inet ' | awk '{print $2}' | cut -d / -f 1)
                fi
                log "[$jenis - $nama] New IP = $new_ip_hp"
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[IP\]/$new_ip_hp/g")
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[NAMAMODEM\]/$nama/g")
                if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                    curl -s -X POST https://api.telegram.org/bot$TOKEN_ID/sendMessage -d chat_id=$CHAT_ID -d text="$CUSTOM_MESSAGE" > /dev/null
                fi
            elif [ "$jenis" = "orbit" ]; then
                if python3 /usr/bin/modem-orbit.py $iporbit $usernameorbit $passwordorbit; then
                    new_ip_orbit="IP Changed"
                 else
                    /usr/bin/rakitanhilink.sh iphunter
                    new_ip_orbit="IP Changed"
                fi
                log "[$jenis - $nama] New IP $new_ip_orbit"
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[IP\]/$new_ip_orbit/g")
                CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[NAMAMODEM\]/$nama/g")
                if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                    curl -s -X POST https://api.telegram.org/bot$TOKEN_ID/sendMessage -d chat_id=$CHAT_ID -d text="$CUSTOM_MESSAGE" > /dev/null
                fi
            elif [ "$jenis" = "customscript" ]; then
                echo "$script" > "/usr/share/takitanmanager/${nama}-customscript.sh"
                sleep 1
                chmod +x "/usr/share/takitanmanager/${nama}-customscript.sh"
                sleep 1
                bash "/usr/share/takitanmanager/${nama}-customscript.sh"
                if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                    curl -s -X POST https://api.telegram.org/bot$TOKEN_ID/sendMessage -d chat_id=$CHAT_ID -d text="$CUSTOM_MESSAGE" > /dev/null
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
        perform_ping "${nama_modem[$i]}" "${jenis_modem[$i]}" "${metodeping_modem[$i]}" "${hostbug_modem[$i]}" "${androidid_modem[$i]}" "${devicemodem_modem[$i]}" "${delayping_modem[$i]}" "${apn_modem[$i]}" "${port_modem[$i]}" "${interface_modem[$i]}" "${iporbit_modem[$i]}" "${usernameorbit_modem[$i]}" "${passwordorbit_modem[$i]}" "${script_modem[$i]}" &
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
