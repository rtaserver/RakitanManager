#!/bin/bash
# Copyright 2024 RTA SERVER

log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}


log "Setup Modem RakitanManager"

rpid=$(pgrep "rakitanmanager")
if [[ -n $rpid ]]; then
    kill $rpid
fi

log "Setup php uhttpd"
uci set uhttpd.main.index_page='index.php'
uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
uci commit uhttpd

/etc/init.d/uhttpd restart
log "Setup php uhttpd Done"

log "Setup Package For Python3"
if which pip3 >/dev/null; then
    # Instal paket 'requests' jika belum terinstal
    if ! pip3 show requests >/dev/null; then
        log "Installing package 'requests'"
        if ! pip3 install requests >>"$log_file" 2>&1; then
            log "Error installing package 'requests'"
            log "Setup Gagal | Mohon Coba Kembali"
            exit 1  # Keluar dari skrip dengan status error
        fi
    else
        log "Package 'requests' already installed"
    fi

    # Instal paket 'huawei-lte-api' jika belum terinstal
    if ! pip3 show huawei-lte-api >/dev/null; then
        log "Installing package 'huawei-lte-api'"
        if ! pip3 install huawei-lte-api >>"$log_file" 2>&1; then
            log "Error installing package 'huawei-lte-api'"
            log "Setup Gagal | Mohon Coba Kembali"
            exit 1  # Keluar dari skrip dengan status error
        fi
    else
        log "Package 'huawei-lte-api' already installed"
    fi

    # Instal paket 'datetime' jika belum terinstal
    if ! pip3 show datetime >/dev/null; then
        log "Installing package 'datetime'"
        if ! pip3 install datetime >>"$log_file" 2>&1; then
            log "Error installing package 'datetime'"
            log "Setup Gagal | Mohon Coba Kembali"
            exit 1  # Keluar dari skrip dengan status error
        fi
    else
        log "Package 'datetime' already installed"
    fi

    # Instal paket 'logging' jika belum terinstal
    if ! pip3 show logging >/dev/null; then
        log "Installing package 'logging'"
        if ! pip3 install logging >>"$log_file" 2>&1; then
            log "Error installing package 'logging'"
            log "Setup Gagal | Mohon Coba Kembali"
            exit 1  # Keluar dari skrip dengan status error
        fi
    else
        log "Package 'logging' already installed"
    fi
else
    log "Error: 'pip3' command not found"
    log "Setup Gagal | Mohon Coba Kembali"
    exit 1  # Keluar dari skrip dengan status error
fi

sed -i 's/\r$//' /usr/bin/setuprakitanmanager.sh
sed -i 's/\r$//' /usr/bin/rakitanmanager.sh
sed -i 's/\r$//' /usr/bin/rakitanhilink.sh
sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/adb-deviceinfo.sh
sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/adb-refresh-network.sh
sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/adb-sms.sh
sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/service-openclash.sh
sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/systeminfo.sh
log "Setup Done | Modem RakitanManager Berhasil Di Install"
exit