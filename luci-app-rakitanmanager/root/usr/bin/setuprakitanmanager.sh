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
else
    log "Error: 'pip3' command not found"
    log "Setup Gagal | Mohon Coba Kembali"
    exit 1  # Keluar dari skrip dengan status error
fi

log "Setup Done | Modem RakitanManager Berhasil Di Install"
exit