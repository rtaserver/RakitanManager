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
parse_config() {
    config_list=$(uci show rakitanmanager_datamodem | grep "^rakitanmanager" | cut -d'=' -f1)
    for config in $config_list; do
        id=$(uci get "$config.id" 2>/dev/null || echo "")
        jenis=$(uci get "$config.jenis" 2>/dev/null || echo "")
        nama=$(uci get "$config.nama" 2>/dev/null || echo "")
        cobaping=$(uci get "$config.cobaping" 2>/dev/null || echo "")
        portmodem=$(uci get "$config.portmodem" 2>/dev/null || echo "")
        interface=$(uci get "$config.interface" 2>/dev/null || echo "")
        iporbit=$(uci get "$config.iporbit" 2>/dev/null || echo "")
        usernameorbit=$(uci get "$config.usernameorbit" 2>/dev/null || echo "")
        passwordorbit=$(uci get "$config.passwordorbit" 2>/dev/null || echo "")
        metodeping=$(uci get "$config.metodeping" 2>/dev/null || echo "")
        hostbug=$(uci get "$config.hostbug" 2>/dev/null || echo "")
        androidid=$(uci get "$config.androidid" 2>/dev/null || echo "")
        modpes=$(uci get "$config.modpes" 2>/dev/null || echo "")
        devicemodem=$(uci get "$config.devicemodem" 2>/dev/null || echo "")
        delayping=$(uci get "$config.delayping" 2>/dev/null || echo "")
        script=$(uci get "$config.script" 2>/dev/null || echo "")

        # Pengecekan apakah semua nilai kosong
        if [ -n "$id" ] || [ -n "$jenis" ] || [ -n "$nama" ] || [ -n "$cobaping" ] || [ -n "$portmodem" ] || [ -n "$interface" ] || [ -n "$iporbit" ] || [ -n "$usernameorbit" ] || [ -n "$passwordorbit" ] || [ -n "$metodeping" ] || [ -n "$hostbug" ] || [ -n "$androidid" ] || [ -n "$modpes" ] || [ -n "$devicemodem" ] || [ -n "$delayping" ] || [ -n "$script" ]; then
            modem_data="{\"id\":\"$id\",\"jenis\":\"$jenis\",\"nama\":\"$nama\",\"cobaping\":\"$cobaping\",\"portmodem\":\"$portmodem\",\"interface\":\"$interface\",\"iporbit\":\"$iporbit\",\"usernameorbit\":\"$usernameorbit\",\"passwordorbit\":\"$passwordorbit\",\"metodeping\":\"$metodeping\",\"hostbug\":\"$hostbug\",\"androidid\":\"$androidid\",\"modpes\":\"$modpes\",\"devicemodem\":\"$devicemodem\",\"delayping\":\"$delayping\",\"script\":\"$script\"}"
            perform_ping "$modem_data" &
        fi
    done
}

perform_ping() {
    local modem_data="$1"
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

        status_Internet=false

        for pinghost in $host; do
            ping_success=false

            case "$metodeping" in
                icmp)
                    if ping -q -c 3 -W 3 -I "${devicemodem}" "${pinghost}" > /dev/null; then
                        log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem succeeded"
                        ping_success=true
                    else
                        log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem failed"
                    fi
                    ;;
                curl)
                    if [[ $(curl --interface "${devicemodem}" -si --max-time 3 "http://${pinghost}" | grep -c 'Date:') == "1" ]]; then
                        log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem succeeded"
                        ping_success=true
                    else
                        log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem failed"
                    fi
                    ;;
                http)
                    if curl --interface "${devicemodem}" -Is --max-time 3 "http://${xhost}:${port_http}" >/dev/null; then
                        log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem succeeded"
                        ping_success=true
                    else
                        log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem failed"
                    fi
                    ;;
                https)
                    if curl --interface "${devicemodem}" -Is --max-time 3 "https://${xhost}:${port_https}" >/dev/null; then
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
            attempt=$((attempt + 1))
        fi
        sleep "$delayping"
    done
}

handle_rakitan() {
    if [ "$attempt" -eq "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Renew IP Started"
        "$RAKITANMANAGERDIR/modem-rakitan.sh" renew "$devicemodem" "$portmodem" "$interface"
        new_ip=$(ifconfig wwan0 | grep inet | grep -v inet6 | awk '{print $2}')
        if [ -z "$new_ip" ]; then
            new_ip="Changed"
        fi
        if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
            TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
            send_message "$TGMSG"
        fi
    elif [ "$attempt" -eq $((cobaping + 1)) ]; then
        log "[$jenis - $nama] Gagal PING | Restart Modem Started"
        "$RAKITANMANAGERDIR/modem-rakitan.sh" restart "$devicemodem" "$portmodem" "$interface"
        new_ip=$(ifconfig wwan0 | grep inet | grep -v inet6 | awk '{print $2}')
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

main() {
    parse_config
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
