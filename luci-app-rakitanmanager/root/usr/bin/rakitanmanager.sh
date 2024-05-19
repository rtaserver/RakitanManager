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



# Fungsi untuk mengirim pesan balasan
send_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TOKEN_ID/sendMessage" -d "chat_id=$CHAT_ID" -d "text=$message" >/dev/null
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
cobaping_modem=()
jenis_modem=()
nama_modem=()
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

parse_json() {
    modems=$(jq -r '.modems | length' "$json_file")
    for ((i = 0; i < modems; i++)); do
        cobaping_modem[$i]=$(jq -r ".modems[$i].cobaping" "$json_file")
        jenis_modem[$i]=$(jq -r ".modems[$i].jenis" "$json_file")
        nama_modem[$i]=$(jq -r ".modems[$i].nama" "$json_file")
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
    cobaping="${1:-}"
    nama="${2:-}"
    jenis="${3:-}"
    motodeping="${4:-}"
    host="${5:-}"
    androidid="${6:-}"
    devicemodem="${7:-}"
    delayping="${8:-}"
    if [ -z "$delayping" ]; then
	    delayping="1"
    fi
    portmodem="${9:-}"
    interface="${10:-}"
    iporbit="${11:-}"
    usernameorbit="${12:-}"
    passwordorbit="${13:-}"
    script="${14:-}"

    attempt=1

    while true; do
        log_size=$(wc -c < "$log_file")
        max_size=$((2 * 5000))
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

            ping_success=false

            if [ "$motodeping" = "icmp" ]; then
                # ICMP ping dengan antarmuka kustom
                ping -q -c 3 -W 3 -I ${devicemodem} ${xhost} > /dev/null
                if [ $? -eq 0 ]; then
                    log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem succeeded"
                    ping_success=true
                else
                    log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem failed"
                fi
            elif [ "$motodeping" = "curl" ]; then
                # CURL ping dengan antarmuka kustom
                if [[ "$xhost" =~ "http://" ]]; then
                    cv_type="$xhost"
                elif [[ "$xhost" =~ "https://" ]]; then
                    cv_type=$(echo -e "$xhost" | sed 's|https|http|g')
                elif [[ "$xhost" =~ [.] ]]; then
                    cv_type=http://"$xhost"
                fi
                if [[ $(curl --interface ${devicemodem} -si ${cv_type} | grep -c 'Date:') == "1" ]]; then
                    log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem succeeded"
                    ping_success=true
                else
                    log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem failed"
                fi
            elif [ "$motodeping" = "http" ]; then
                # HTTP ping dengan antarmuka kustom
                if curl -Is --max-time 3 http://${xhost}:${port_http} --interface ${devicemodem} >/dev/null; then
                    log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem succeeded"
                    ping_success=true
                else
                    log "[$jenis - $nama] HTTP ping to $pinghost on interface $devicemodem failed"
                fi
            elif [ "$motodeping" = "https" ]; then
                # HTTPS ping dengan antarmuka kustom
                if curl -Is --max-time 3 https://${xhost}:${port_https} --interface ${devicemodem} >/dev/null; then
                    log "[$jenis - $nama] HTTPS ping to $pinghost on interface $devicemodem succeeded"
                    ping_success=true
                else
                    log "[$jenis - $nama] HTTPS ping to $pinghost on interface $devicemodem failed"
                fi
            fi

            if [ "$ping_success" = true ]; then
                status_Internet=true
                attempt=1
                break
            fi
        done

        if [ "$status_Internet" = false ]; then
            log "[$jenis - $nama] Gagal PING | $attempt"
            if [ "$jenis" = "rakitan" ]; then
                case $attempt in
                    $cobaping)
                        unset new_rakitan_ip
                        log "[$jenis - $nama] Gagal PING | Renew IP Started"
                        echo AT+CFUN=4 | atinout - "$portmodem" - >/dev/null
                        log "[$jenis - $nama] Renew IP Sukses"
                        sleep 10
                        new_rakitan_ip=$(ifconfig $devicemodem | grep inet | grep -v inet6 | awk '{print $2}' | awk -F : '{print $2}')
                        [ -z "$new_rakitan_ip" ] && new_rakitan_ip="Tidak Ada IP"
                        log "[$jenis - $nama] New IP: $new_rakitan_ip"
                        TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_rakitan_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
                        if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                            send_message "$TGMSG"
                        fi
                        ;;
                    $((cobaping + 1)))
                        unset new_rakitan_ip
                        log "[$jenis - $nama] Gagal PING | Restart Modem Started"
                        echo AT^RESET | atinout - "$portmodem" - >/dev/null
                        log "[$jenis - $nama] Restart Modem Sukses"
                        sleep 20
                        attempt=1
                        new_rakitan_ip=$(ifconfig $devicemodem | grep inet | grep -v inet6 | awk '{print $2}')
                        [ -z "$new_rakitan_ip" ] && new_rakitan_ip="Tidak Ada IP"
                        log "[$jenis - $nama] New IP: $new_rakitan_ip"
                        TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_rakitan_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
                        if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                            send_message "$TGMSG"
                        fi
                        ;;
                esac
            elif [ "$jenis" = "hp" ]; then
                case $attempt in
                    $cobaping)
                        unset new_hp_ip
                        log "[$jenis - $nama] Gagal PING | Restart Network Started"
                        $RAKITANPLUGINS/adb-refresh-network.sh $androidid >/dev/null
                        log "[$jenis - $nama] Gagal PING | Restart Network Sukses"
                        sleep 10
                        attempt=1
                        new_hp_ip=$($RAKITANPLUGINS/adb-refresh-network.sh $androidid myip)
                        log "[$jenis - $nama] New IP: $new_hp_ip"
                        TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_hp_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
                        if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                            send_message "$TGMSG"
                        fi
                        ;;
                esac
            elif [ "$jenis" = "orbit" ]; then
                case $attempt in
                    $cobaping)
                        unset orbitresult
                        unset new_ip_orbit
                        log "[$jenis - $nama] Gagal PING | Restart Network Started"
                        orbitresult=$(python3 /usr/bin/modem-orbit.py "$iporbit" "$usernameorbit" "$passwordorbit" || /usr/bin/rakitanhilink.sh iphunter || curl -d "isTest=false&goformId=REBOOT_DEVICE" -X POST http://$iporbit/reqproc/proc_post)
                        log "[$jenis - $nama] Gagal PING | Restart Network Sukses"
                        sleep 10
                        attempt=1
                        new_ip_orbit=$(echo "$orbitresult" | grep "New IP" | awk -F": " '{print $2}')
                        TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip_orbit/g" -e "s/\[NAMAMODEM\]/$nama/g")
                        if [ "$(uci get rakitanmanager.telegram.enabled)" = "1" ]; then
                            send_message "$TGMSG"
                        fi
                        ;;
                esac
            elif [ "$jenis" = "customscript" ]; then
                case $attempt in
                    $cobaping)
                        log "[$jenis - $nama] Gagal PING | Custom Script Started"
                        echo "$script" > /usr/share/rakitanmanager/${nama}-customscript.sh
                        chmod +x /usr/share/rakitanmanager/${nama}-customscript.sh
                        /usr/share/rakitanmanager/${nama}-customscript.sh
                        sleep 10
                        attempt=1
                        ;;
                esac
            fi
            attempt=$((attempt + 1))
        fi
        sleep "$delayping"
    done
}

main() {
    parse_json

    # Loop through each modem and perform actions
    for ((i = 0; i < ${#jenis_modem[@]}; i++)); do
        perform_ping "${cobaping_modem[$i]}" "${nama_modem[$i]}" "${jenis_modem[$i]}" "${metodeping_modem[$i]}" "${hostbug_modem[$i]}" "${androidid_modem[$i]}" "${devicemodem_modem[$i]}" "${delayping_modem[$i]}" "${port_modem[$i]}" "${interface_modem[$i]}" "${iporbit_modem[$i]}" "${usernameorbit_modem[$i]}" "${passwordorbit_modem[$i]}" "${script_modem[$i]}" &
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
esac
