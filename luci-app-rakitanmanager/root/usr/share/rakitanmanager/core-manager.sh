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

RAKITANMANAGERDIR="/usr/share/rakitanmanager"
test_bot() {
    # Kirim pesan uji
    send_message "===============
$(bash $RAKITANMANAGERDIR/plugins/systeminfo.sh)
==============="
}

# Parsing konfigurasi dan menjalankan fungsi-fungsi yang diperlukan
json_file="/usr/share/rakitanmanager/data-modem.json"
parse_config() {
    modems=()
    while IFS= read -r line; do
        modems+=("$line")
    done < <(jq -c '.modems[]' "$json_file")
}

perform_ping() {
    local modem_data="$1"
    local index="$2"
    local status=$(jq -r '.status' <<< "$modem_data")
    local cobaping=$(jq -r '.cobaping' <<< "$modem_data")
    local nama=$(jq -r '.nama' <<< "$modem_data")
    local jenis=$(jq -r '.jenis' <<< "$modem_data")
    local metodeping=$(jq -r '.metodeping' <<< "$modem_data")
    local host=$(jq -r '.hostbug' <<< "$modem_data")
    local androidid=$(jq -r '.androidid' <<< "$modem_data")
    local modpes=$(jq -r '.modpes' <<< "$modem_data")
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

        if [ "$status" = "-1" ]; then
            break
        fi

        status_Internet=false

        for pinghost in $host; do
            ping_success=false

            case "$metodeping" in
                icmp)
                    if [ "$devicemodem" = "disabled" ]; then
                        if ping -q -c 3 -W 3 "${pinghost}" > /dev/null; then
                            log "[$jenis - $nama] ICMP ping to $pinghost succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] ICMP ping to $pinghost failed"
                        fi
                    else
                        if ping -q -c 3 -W 3 -I "${devicemodem}" "${pinghost}" > /dev/null; then
                            log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem failed"
                        fi
                    fi
                ;;
                curl)
                    if [ "$devicemodem" = "disabled" ]; then
                        if [[ $(curl -si --max-time 3 "http://${pinghost}" | grep -c 'Date:') == "1" ]]; then
                            log "[$jenis - $nama] CURL ping to $pinghost succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] CURL ping to $pinghost failed"
                        fi
                    else
                        if [[ $(curl --interface "${devicemodem}" -si --max-time 3 "http://${pinghost}" | grep -c 'Date:') == "1" ]]; then
                            log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem failed"
                        fi
                    fi
                ;;
                http)
                    if [ "$devicemodem" = "disabled" ]; then
                        if curl -Is --max-time 3 "http://${xhost}:${port_http}" >/dev/null; then
                            log "[$jenis - $nama] HTTP ping to $pinghost succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] HTTP ping to $pinghost failed"
                        fi
                    else
                        if curl --interface "${devicemodem}" -Is --max-time 3 "http://${xhost}:${port_http}" >/dev/null; then
                            log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem failed"
                        fi
                    fi
                ;;
                https)
                    if [ "$devicemodem" = "disabled" ]; then
                        if curl -Is --max-time 3 "https://${xhost}:${port_https}" >/dev/null; then
                            log "[$jenis - $nama] HTTPS ping to $pinghost succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] HTTPS ping to $pinghost failed"
                        fi
                    else
                        if curl --interface "${devicemodem}" -Is --max-time 3 "https://${xhost}:${port_https}" >/dev/null; then
                            log "[$jenis - $nama] HTTPS ping to $pinghost on interface $devicemodem succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] HTTPS ping to $pinghost on interface $devicemodem failed"
                        fi
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
                    handle_rakitan
                    ;;
                hp)
                    handle_hp
                    ;;
                orbit)
                    handle_orbit
                    ;;
                hilink)
                    handle_hilink
                    ;;
                mf90)
                    handle_mf90
                    ;;
                customscript)
                    handle_customscript
                    ;;
            esac

            update_status "$index" "2"

            attempt=$((attempt + 1))
        else
        update_status "$index" "1"
        fi
        sleep "$delayping"
    done
}

handle_rakitan() {
    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Renew IP Started"
        "$RAKITANMANAGERDIR/modem-rakitan.sh" renew "$devicemodem" "$portmodem" "$interface"
        new_ip=$(ubus call network.interface.$interface status | jsonfilter -e '@["ipv4-address"][0].address')
        if [ -z "$new_ip" ]; then
            new_ip="Changed"
        fi
        if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
            TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
            send_message "$TGMSG"
        fi
    # elif [ "$attempt" -eq $((cobaping + 3)) ]; then
    #     log "[$jenis - $nama] Gagal PING | Restart Modem Started"
    #     "$RAKITANMANAGERDIR/modem-rakitan.sh" restart "$devicemodem" "$portmodem" "$interface"
    #     new_ip=$(ubus call network.interface.$interface status | jsonfilter -e '@["ipv4-address"][0].address')
    #     if [ -z "$new_ip" ]; then
    #         new_ip="Changed"
    #     fi
    #     if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
    #         TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
    #         send_message "$TGMSG"
    #     fi
        attempt=0
    fi
}

handle_hp() {
    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        if [ "$modpes" = "modpesv1" ]; then
            "$RAKITANMANAGERDIR/modem-hp.sh" "$androidid" restart v1
        fi
        if [ "$modpes" = "modpesv2" ]; then
            "$RAKITANMANAGERDIR/modem-hp.sh" "$androidid" restart v2
        fi
        myipresult=$("$RAKITANMANAGERDIR/modem-hp.sh" "$androidid" myip)
        new_ip=$(echo "$myipresult" | grep "New IP" | awk -F": " '{print $2}')
        if [ -z "$new_ip" ]; then
            new_ip="Changed"
        fi
        if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
            TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
            send_message "$TGMSG"
        fi
        attempt=0
    fi
}

handle_orbit() {
    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        orbitresult=$(python3 "$RAKITANMANAGERDIR/modem-orbit.py" "$iporbit" "$usernameorbit" "$passwordorbit")
        new_ip=$(echo "$orbitresult" | grep "New IP" | awk -F": " '{print $2}')
        if [ -z "$new_ip" ]; then
            new_ip="Changed"
        fi
        if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
            TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
            send_message "$TGMSG"
        fi
        attempt=0
    fi
}

handle_hilink() {
    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        hilinkresult=$("$RAKITANMANAGERDIR/modem-hilink.sh" "$iporbit" "$usernameorbit" "$passwordorbit")
        new_ip=$(echo "$hilinkresult" | grep "New IP" | awk -F": " '{print $2}')
        if [ -z "$new_ip" ]; then
            new_ip="Changed"
        fi
        if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
            TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
            send_message "$TGMSG"
        fi
        attempt=0
    fi
}

handle_mf90() {
    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        mf90result=$("$RAKITANMANAGERDIR/modem-mf90.sh" "$iporbit" "$usernameorbit" "$passwordorbit" reboot)
        new_ip=$(echo "$mf90result" | grep "New IP" | awk -F": " '{print $2}')
        "$RAKITANMANAGERDIR/modem-mf90.sh" "$iporbit" "$usernameorbit" "$passwordorbit" disable_wifi
        if [ -z "$new_ip" ]; then
            new_ip="Changed"
        fi
        if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
            TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
            send_message "$TGMSG"
        fi
        attempt=0
    fi
}

handle_customscript() {
    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Custom Script Started"
        local script_clean=$(echo "$script" | tr -d '\r')
        bash -c "$script_clean"
        sleep 10
        attempt=0
    fi
}

update_status() {
    local index="$1"
    local status="$2"
    if [[ -z "$index" ]] || [[ -z "$status" ]]; then
        return
    fi

    local ip_gateway=$(ip address show br-lan | grep -w 'inet' 2>/dev/null | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | tr -d '\n')
    if [ -z "$ip_gateway" ]; then
        ip_gateway=$(uci -q get network.lan.ipaddr | awk -F '/' '{print $1}' 2>/dev/null | tr -d '\n')
    fi

    curl -sL -m 5 --retry 2 -o /dev/null -X GET "http://$ip_gateway:80/rakitanmanager?update_status=$index&status=$status"
}

main() {
    parse_config

    i=0
    for modem_data in "${modems[@]}"; do
        perform_ping "$modem_data" "$i" &
        ((i++))
    done
}

rakitanmanager_stop() {
    if pidof core-manager.sh > /dev/null; then
        killall -9 core-manager.sh
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
