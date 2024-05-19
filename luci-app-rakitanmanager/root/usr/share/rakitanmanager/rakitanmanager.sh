#!/bin/bash
# Copyright 2024 RTA SERVER

log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}


# Ambil informasi perangkat
DEVICE_INFO=$(ubus call system board)
DEVICE_PROCESSOR=$(echo "$DEVICE_INFO" | jq -r '.system')
DEVICE_MODEL=$(echo "$DEVICE_INFO" | jq -r '.model')
DEVICE_BOARD=$(echo "$DEVICE_INFO" | jq -r '.board_name')

# TELEGRAM
TOKEN_ID=$(uci -q get rakitanmanager.telegram.token)
CHAT_ID=$(uci -q get rakitanmanager.telegram.chatid)
CUSTOM_MESSAGE=$(cat /www/rakitanmanager/bot_message.txt)
CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[DEVICE_PROCESSOR\]/$DEVICE_PROCESSOR/g")
CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[DEVICE_MODEL\]/$DEVICE_MODEL/g")
CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[DEVICE_BOARD\]/$DEVICE_BOARD/g")

# Fungsi untuk mengirim pesan balasan
send_message() {
    local message="$1"
    if ! curl -s -X POST "https://api.telegram.org/bot$TOKEN_ID/sendMessage" -d "chat_id=$CHAT_ID" -d "text=$message" >/dev/null; then
        log "Kirim Pesan Telegram Gagal"
    fi
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
if [ ! -f "$json_file" ]; then
    log "File JSON tidak ditemukan."
    exit 1
fi

# Parsing JSON dan simpan ke array
parse_json() {
    modems=()
    while IFS= read -r line; do
        modems+=("$line")
    done < <(jq -c '.modems[]' "$json_file")
}

perform_ping() {
    local modem_data="$1"
    local cobaping=$(jq -r '.cobaping' <<< "$modem_data")
    local nama=$(jq -r '.nama' <<< "$modem_data")
    local jenis=$(jq -r '.jenis' <<< "$modem_data")
    local metodeping=$(jq -r '.metodeping' <<< "$modem_data")
    local host=$(jq -r '.hostbug' <<< "$modem_data")
    local androidid=$(jq -r '.androidid' <<< "$modem_data")
    local devicemodem=$(jq -r '.devicemodem' <<< "$modem_data")
    local delayping=$(jq -r '.delayping' <<< "$modem_data")
    local portmodem=$(jq -r '.portmodem' <<< "$modem_data")
    local interface=$(jq -r '.interface' <<< "$modem_data")
    local iporbit=$(jq -r '.iporbit' <<< "$modem_data")
    local usernameorbit=$(jq -r '.usernameorbit' <<< "$modem_data")
    local passwordorbit=$(jq -r '.passwordorbit' <<< "$modem_data")
    local script=$(jq -r '.script' <<< "$modem_data")

    delayping=${delayping:-1}

    attempt=1

    while true; do
        log_size=$(wc -c < "$log_file")
        max_size=$((2 * 10000))
        if [ "$log_size" -gt "$max_size" ]; then
            echo -n "" > "$log_file"
            log "Log dibersihkan karena melebihi ukuran maksimum."
        fi

        status_Internet=false

        for pinghost in $host; do
            local xhost=$(echo "${pinghost}" | cut -d':' -f1)
            local xport=$(echo "${pinghost}" | cut -d':' -f2)

            port_icmp=0
            port_tcp=${xport:-80}
            port_http=${xport:-80}
            port_https=${xport:-443}

            ping_success=false

            case "$metodeping" in
                icmp)
                    if ping -q -c 3 -W 3 -I "${devicemodem}" "${xhost}" > /dev/null; then
                        log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem succeeded"
                        ping_success=true
                    else
                        log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem failed"
                    fi
                    ;;
                curl)
                    local cv_type=$(echo "$xhost" | sed 's|https|http|g')
                    if [[ $(curl --interface ${devicemodem} -si ${cv_type} | grep -c 'Date:') == "1" ]]; then
                        log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem succeeded"
                        ping_success=true
                    else
                        log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem failed"
                    fi
                    ;;
                http)
                    if curl -Is --max-time 3 "http://${xhost}:${port_http}" --interface ${devicemodem} >/dev/null; then
                        log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem succeeded"
                        ping_success=true
                    else
                        log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem failed"
                    fi
                    ;;
                https)
                    if curl -Is --max-time 3 "https://${xhost}:${port_https}" --interface ${devicemodem} >/dev/null; then
                        log "[$jenis - $nama] HTTPS ping to $pinghost on interface $devicemodem succeeded"
                        ping_success=true
                    else
                        log "[$jenis - $nama] HTTPS ping to $pinghost on interface $devicemodem failed"
                    fi
                    ;;
            esac

            if [ "$ping_success" = true ]; then
                status_Internet=true
                attempt=1
                break
            fi
        done

        if [ "$status_Internet" = false ]; then
            log "[$jenis - $nama] Gagal PING | $attempt"
            case $jenis in
                rakitan)
                    handle_rakitan "$modem_data" "$attempt"
                    ;;
                hp)
                    handle_hp "$modem_data" "$attempt"
                    ;;
                orbit)
                    handle_orbit "$modem_data" "$attempt"
                    ;;
                customscript)
                    handle_customscript "$modem_data" "$attempt"
                    ;;
            esac
            attempt=$((attempt + 1))
        fi
        sleep "$delayping"
    done
}

handle_rakitan() {
    local modem_data="$1"
    local attempt="$2"

    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Renew IP Started"
        echo AT+CFUN=4 | atinout - "$portmodem" - >/dev/null
        sleep 20
        new_ip=$(ifconfig "$devicemodem" | grep inet | grep -v inet6 | awk '{print $2}')
        TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
        send_message "$TGMSG"
    elif [ "$attempt" -eq $((cobaping + 1)) ]; then
        log "[$jenis - $nama] Gagal PING | Restart Modem Started"
        echo AT^RESET | atinout - "$portmodem" - >/dev/null
        sleep 30
        new_ip=$(ifconfig "$devicemodem" | grep inet | grep -v inet6 | awk '{print $2}')
        TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
        send_message "$TGMSG"
        attempt=1
    fi
}

handle_hp() {
    local modem_data="$1"
    local attempt="$2"

    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        "$RAKITANPLUGINS/adb-refresh-network.sh" "$androidid"
        sleep 30
        new_ip=$(adb -s "$androidid" shell ip route | awk 'NR==1 {print $9}')
        TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
        send_message "$TGMSG"
        attempt=1
    fi
}

handle_orbit() {
    local modem_data="$1"
    local attempt="$2"

    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        orbitresult=$(python3 /usr/bin/modem-orbit.py "$iporbit" "$usernameorbit" "$passwordorbit" || /usr/bin/rakitanhilink.sh iphunter || curl -d "isTest=false&goformId=REBOOT_DEVICE" -X POST http://"$iporbit"/reqproc/proc_post)
        sleep 30
        new_ip=$(echo "$orbitresult" | grep "New IP" | awk -F": " '{print $2}')
        TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
        send_message "$TGMSG"
        attempt=1
    fi
}

handle_customscript() {
    local modem_data="$1"
    local attempt="$2"

    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Custom Script Started"
        echo "$script" > "/usr/share/rakitanmanager/${nama}-customscript.sh"
        chmod +x "/usr/share/rakitanmanager/${nama}-customscript.sh"
        "/usr/share/rakitanmanager/${nama}-customscript.sh"
        sleep 10
        attempt=1
    fi
}

main() {
    parse_json

    for modem_data in "${modems[@]}"; do
        perform_ping "$modem_data" &
    done
}

rakitanmanager_stop() {
    if pidof rakitanmanager.sh > /dev/null; then
        killall -9 rakitanmanager.sh
        log "RakitanManager Berhasil Dihentikan."
    else
        log "RakitanManager is not running."
    fi
}

while getopts ":skrpcvh" rakitanmanager; do
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

case $action in
    "bot_test")
        test_bot
        ;;
esac
