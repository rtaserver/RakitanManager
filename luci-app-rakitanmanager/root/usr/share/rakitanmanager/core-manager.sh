#!/bin/bash
# Copyright 2024 RTA SERVER

# Source common utilities
UTILS_DIR="$(dirname "$0")"
if [ -f "$UTILS_DIR/utils.sh" ]; then
    source "$UTILS_DIR/utils.sh"
else
    # Fallback logging if utils.sh not found
    log_file="/var/log/rakitanmanager.log"
    exec 1>>"$log_file" 2>&1
    log() {
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    }
fi

# Ambil informasi perangkat
DEVICE_INFO=$(ubus call system board 2>/dev/null)
DEVICE_PROCESSOR=$(echo "$DEVICE_INFO" | jq -r '.system // "Unknown"')
DEVICE_MODEL=$(echo "$DEVICE_INFO" | jq -r '.model // "Unknown"')
DEVICE_BOARD=$(echo "$DEVICE_INFO" | jq -r '.board_name // "Unknown"')

# TELEGRAM
TOKEN_ID=$(uci -q get rakitanmanager.telegram.token)
CHAT_ID=$(uci -q get rakitanmanager.telegram.chatid)

# Load and process custom message
CUSTOM_MESSAGE=""
if [ -f "/www/rakitanmanager/bot_message.txt" ]; then
    CUSTOM_MESSAGE=$(cat /www/rakitanmanager/bot_message.txt)
    CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[DEVICE_PROCESSOR\]/$DEVICE_PROCESSOR/g")
    CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[DEVICE_MODEL\]/$DEVICE_MODEL/g")
    CUSTOM_MESSAGE=$(echo "$CUSTOM_MESSAGE" | sed "s/\[DEVICE_BOARD\]/$DEVICE_BOARD/g")
fi

# Fungsi untuk mengirim pesan balasan
send_message() {
    local message="$1"
    if [ -z "$TOKEN_ID" ] || [ -z "$CHAT_ID" ]; then
        log "Telegram credentials not configured"
        return 1
    fi
    
    if ! curl -s -X POST "https://api.telegram.org/bot$TOKEN_ID/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$message" >/dev/null 2>&1; then
        log "Kirim Pesan Telegram Gagal"
        return 1
    fi
    return 0
}

RAKITANMANAGERDIR="/usr/share/rakitanmanager"

test_bot() {
    if [ -f "$RAKITANMANAGERDIR/plugins/systeminfo.sh" ]; then
        local sysinfo=$(bash "$RAKITANMANAGERDIR/plugins/systeminfo.sh" 2>&1)
        send_message "===============
$sysinfo
==============="
    else
        log "systeminfo.sh not found"
        send_message "Test Bot: systeminfo.sh not found"
    fi
}

# Parsing konfigurasi dan menjalankan fungsi-fungsi yang diperlukan
json_file="/usr/share/rakitanmanager/data-modem.json"

parse_config() {
    modems=()
    
    if [ ! -f "$json_file" ]; then
        log "Config file not found: $json_file"
        return 1
    fi
    
    while IFS= read -r line; do
        modems+=("$line")
    done < <(jq -c '.modems[]' "$json_file" 2>/dev/null)
    
    if [ ${#modems[@]} -eq 0 ]; then
        log "No modems found in config"
        return 1
    fi
    
    return 0
}

perform_ping() {
    local modem_data="$1"
    local index="$2"
    
    # Parse modem configuration
    local status=$(jq -r '.status // "-1"' <<< "$modem_data")
    local cobaping=$(jq -r '.cobaping // "3"' <<< "$modem_data")
    local nama=$(jq -r '.nama // "Unknown"' <<< "$modem_data")
    local jenis=$(jq -r '.jenis // "unknown"' <<< "$modem_data")
    local metodeping=$(jq -r '.metodeping // "icmp"' <<< "$modem_data")
    local host=$(jq -r '.hostbug // "8.8.8.8"' <<< "$modem_data")
    local androidid=$(jq -r '.androidid // ""' <<< "$modem_data")
    local modpes=$(jq -r '.modpes // ""' <<< "$modem_data")
    local devicemodem=$(jq -r '.devicemodem // "disabled"' <<< "$modem_data")
    local delayping=$(jq -r '.delayping // "1"' <<< "$modem_data")
    local portmodem=$(jq -r '.portmodem // ""' <<< "$modem_data")
    local interface=$(jq -r '.interface // ""' <<< "$modem_data")
    local iporbit=$(jq -r '.iporbit // ""' <<< "$modem_data")
    local usernameorbit=$(jq -r '.usernameorbit // ""' <<< "$modem_data")
    local passwordorbit=$(jq -r '.passwordorbit // ""' <<< "$modem_data")
    local script=$(jq -r '.script // ""' <<< "$modem_data")

    local attempt=1
    local max_log_size=$((2 * 10000))

    while true; do
        # Log rotation
        if [ -f "$log_file" ]; then
            local log_size=$(wc -c < "$log_file" 2>/dev/null || echo 0)
            if [ "$log_size" -gt "$max_log_size" ]; then
                echo -n "" > "$log_file"
                log "Log dibersihkan karena melebihi ukuran maksimum."
            fi
        fi

        # Check if modem is disabled
        if [ "$status" = "-1" ]; then
            log "[$jenis - $nama] Modem disabled, stopping monitoring"
            break
        fi

        local status_Internet=false

        # Try pinging each host
        for pinghost in $host; do
            local ping_success=false

            case "$metodeping" in
                icmp)
                    if [ "$devicemodem" = "disabled" ]; then
                        if ping -q -c 3 -W 3 "$pinghost" > /dev/null 2>&1; then
                            log "[$jenis - $nama] ICMP ping to $pinghost succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] ICMP ping to $pinghost failed"
                        fi
                    else
                        if ping -q -c 3 -W 3 -I "$devicemodem" "$pinghost" > /dev/null 2>&1; then
                            log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] ICMP ping to $pinghost on interface $devicemodem failed"
                        fi
                    fi
                    ;;
                curl)
                    if [ "$devicemodem" = "disabled" ]; then
                        if curl -si --max-time 3 "http://$pinghost" 2>/dev/null | grep -q 'Date:'; then
                            log "[$jenis - $nama] CURL ping to $pinghost succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] CURL ping to $pinghost failed"
                        fi
                    else
                        if curl --interface "$devicemodem" -si --max-time 3 "http://$pinghost" 2>/dev/null | grep -q 'Date:'; then
                            log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] CURL ping to $pinghost on interface $devicemodem failed"
                        fi
                    fi
                    ;;
                http)
                    if type ping_func &>/dev/null; then
                        if ping_func "$pinghost" "http" 3; then
                            log "[$jenis - $nama] HTTP ping to $pinghost succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] HTTP ping to $pinghost failed"
                        fi
                    else
                        log "[$jenis - $nama] ping_func not available, skipping HTTP ping"
                    fi
                    ;;
                https)
                    if type ping_func &>/dev/null; then
                        if ping_func "$pinghost" "https" 3; then
                            log "[$jenis - $nama] HTTPS ping to $pinghost succeeded"
                            ping_success=true
                        else
                            log "[$jenis - $nama] HTTPS ping to $pinghost failed"
                        fi
                    else
                        log "[$jenis - $nama] ping_func not available, skipping HTTPS ping"
                    fi
                    ;;
                *)
                    log "[$jenis - $nama] Unknown ping method: $metodeping"
                    ;;
            esac

            if [ "$ping_success" = true ]; then
                status_Internet=true
                attempt=1
                break
            fi
        done

        # Handle failed ping
        if [ "$status_Internet" = false ]; then
            log "[$jenis - $nama] Gagal PING | Attempt: $attempt/$cobaping"
            
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
                *)
                    log "[$jenis - $nama] Unknown modem type"
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
    if [ "$attempt" -ge "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Renew IP Started"
        
        if [ -f "$RAKITANMANAGERDIR/modem-rakitan.sh" ]; then
            if "$RAKITANMANAGERDIR/modem-rakitan.sh" renew "$devicemodem" "$portmodem" "$interface"; then
                sleep 5
                local new_ip=$(get_ip_address "$interface" 2>/dev/null)
                if [ -z "$new_ip" ]; then
                    new_ip="Changed"
                fi
                log "[$jenis - $nama] IP renewed to: $new_ip"
                
                if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
                    local TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
                    send_message "$TGMSG"
                fi
                attempt=1
            else
                log "[$jenis - $nama] Failed to renew IP"
            fi
        else
            log "[$jenis - $nama] modem-rakitan.sh not found"
        fi
    fi
}

handle_hp() {
    if [ "$attempt" -ge "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        
        if [ ! -f "$RAKITANMANAGERDIR/modem-hp.sh" ]; then
            log "[$jenis - $nama] modem-hp.sh not found"
            return
        fi
        
        if [ "$modpes" = "modpesv1" ]; then
            if "$RAKITANMANAGERDIR/modem-hp.sh" "$androidid" restart v1; then
                sleep 10
                local myipresult=$("$RAKITANMANAGERDIR/modem-hp.sh" "$androidid" myip 2>&1)
                local new_ip=$(echo "$myipresult" | grep "New IP" | awk -F": " '{print $2}')
                if [ -z "$new_ip" ]; then
                    new_ip="Changed"
                fi
                log "[$jenis - $nama] HP modem IP renewed to: $new_ip"
                
                if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
                    local TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
                    send_message "$TGMSG"
                fi
                attempt=1
            else
                log "[$jenis - $nama] Failed to restart HP modem"
            fi
        elif [ "$modpes" = "modpesv2" ]; then
            if "$RAKITANMANAGERDIR/modem-hp.sh" "$androidid" restart v2; then
                sleep 10
                local myipresult=$("$RAKITANMANAGERDIR/modem-hp.sh" "$androidid" myip 2>&1)
                local new_ip=$(echo "$myipresult" | grep "New IP" | awk -F": " '{print $2}')
                if [ -z "$new_ip" ]; then
                    new_ip="Changed"
                fi
                log "[$jenis - $nama] HP modem IP renewed to: $new_ip"
                
                if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
                    local TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
                    send_message "$TGMSG"
                fi
                attempt=1
            else
                log "[$jenis - $nama] Failed to restart HP modem"
            fi
        else
            log "[$jenis - $nama] Invalid modpes version: $modpes"
        fi
    fi
}

handle_orbit() {
    if [ "$attempt" -ge "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        
        if [ ! -f "$RAKITANMANAGERDIR/modem-orbit.py" ]; then
            log "[$jenis - $nama] modem-orbit.py not found"
            return
        fi
        
        if orbitresult=$(python3 "$RAKITANMANAGERDIR/modem-orbit.py" "$iporbit" "$usernameorbit" "$passwordorbit" 2>&1); then
            local new_ip=$(echo "$orbitresult" | grep "New IP" | awk -F": " '{print $2}')
            if [ -z "$new_ip" ]; then
                new_ip="Changed"
            fi
            log "[$jenis - $nama] Orbit modem IP renewed to: $new_ip"
            
            if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
                local TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
                send_message "$TGMSG"
            fi
            attempt=1
        else
            log "[$jenis - $nama] Failed to renew Orbit modem IP: $orbitresult"
        fi
    fi
}

handle_hilink() {
    if [ "$attempt" -ge "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        
        if [ ! -f "$RAKITANMANAGERDIR/modem-hilink.sh" ]; then
            log "[$jenis - $nama] modem-hilink.sh not found"
            return
        fi
        
        if hilinkresult=$("$RAKITANMANAGERDIR/modem-hilink.sh" "$iporbit" "$usernameorbit" "$passwordorbit" 2>&1); then
            local new_ip=$(echo "$hilinkresult" | grep "New IP" | awk -F": " '{print $2}')
            if [ -z "$new_ip" ]; then
                new_ip="Changed"
            fi
            log "[$jenis - $nama] Hilink modem IP renewed to: $new_ip"
            
            if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
                local TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
                send_message "$TGMSG"
            fi
            attempt=1
        else
            log "[$jenis - $nama] Failed to renew Hilink modem IP: $hilinkresult"
        fi
    fi
}

handle_mf90() {
    if [ "$attempt" -ge "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Restart Network Started"
        
        if [ ! -f "$RAKITANMANAGERDIR/modem-mf90.sh" ]; then
            log "[$jenis - $nama] modem-mf90.sh not found"
            return
        fi
        
        if mf90result=$("$RAKITANMANAGERDIR/modem-mf90.sh" "$iporbit" "$usernameorbit" "$passwordorbit" reboot 2>&1); then
            local new_ip=$(echo "$mf90result" | grep "New IP" | awk -F": " '{print $2}')
            if [ -z "$new_ip" ]; then
                new_ip="Changed"
            fi
            log "[$jenis - $nama] MF90 modem IP renewed to: $new_ip"
            
            # Disable WiFi after reboot
            "$RAKITANMANAGERDIR/modem-mf90.sh" "$iporbit" "$usernameorbit" "$passwordorbit" disable_wifi &>/dev/null
            
            if [ "$(uci -q get rakitanmanager.telegram.enabled)" = "1" ]; then
                local TGMSG=$(echo "$CUSTOM_MESSAGE" | sed -e "s/\[IP\]/$new_ip/g" -e "s/\[NAMAMODEM\]/$nama/g")
                send_message "$TGMSG"
            fi
            attempt=1
        else
            log "[$jenis - $nama] Failed to renew MF90 modem IP: $mf90result"
        fi
    fi
}

handle_customscript() {
    if [ "$attempt" -ge "$cobaping" ]; then
        log "[$jenis - $nama] Gagal PING | Custom Script Started"
        
        if [ -n "$script" ]; then
            local script_clean=$(echo "$script" | tr -d '\r')
            if eval "$script_clean" 2>&1 | while read line; do log "[$jenis - $nama] $line"; done; then
                log "[$jenis - $nama] Custom script executed successfully"
                sleep 10
                attempt=1
            else
                log "[$jenis - $nama] Custom script execution failed"
            fi
        else
            log "[$jenis - $nama] No custom script defined"
        fi
    fi
}

update_status() {
    local index="$1"
    local status="$2"
    
    if [ -z "$index" ] || [ -z "$status" ]; then
        return 1
    fi

    local ip_gateway=$(ip address show br-lan 2>/dev/null | grep -w 'inet' | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | tr -d '\n')
    if [ -z "$ip_gateway" ]; then
        ip_gateway=$(uci -q get network.lan.ipaddr 2>/dev/null | awk -F '/' '{print $1}' | tr -d '\n')
    fi
    
    if [ -z "$ip_gateway" ]; then
        log "Cannot determine gateway IP for status update"
        return 1
    fi

    curl -sL -m 5 --retry 2 -o /dev/null -X GET "http://$ip_gateway:80/rakitanmanager?update_status=$index&status=$status" 2>/dev/null
}

main() {
    log "Starting RakitanManager..."
    
    if ! parse_config; then
        log "Failed to parse config, exiting"
        exit 1
    fi
    
    log "Monitoring ${#modems[@]} modem(s)"

    local i=0
    for modem_data in "${modems[@]}"; do
        perform_ping "$modem_data" "$i" &
        ((i++))
    done
    
    wait
}

rakitanmanager_stop() {
    if pgrep -f "core-manager.sh" > /dev/null; then
        pkill -9 -f "core-manager.sh"
        log "RakitanManager Berhasil Dihentikan."
    else
        log "RakitanManager is not running."
    fi
}

# Parse command line options
while getopts ":skrpcvh" rakitanmanager; do
    case $rakitanmanager in
        s)
            main
            exit 0
            ;;
        k)
            rakitanmanager_stop
            exit 0
            ;;
        *)
            echo "Usage: $0 [-s start] [-k stop] or $0 bot_test"
            exit 1
            ;;
    esac
done

# Handle positional arguments
action="$1"
case $action in
    "bot_test")
        test_bot
        ;;
    "")
        echo "Usage: $0 [-s start] [-k stop] or $0 bot_test"
        exit 1
        ;;
    *)
        echo "Unknown action: $action"
        exit 1
        ;;
esac