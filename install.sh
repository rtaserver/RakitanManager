#!/bin/sh

# Colors only if output is a terminal
if [ -t 1 ]; then
    CLBlack="\033[0;30m"    CLRed="\033[0;31m"      CLGreen="\033[0;32m"
    CLYellow="\033[0;33m"   CLBlue="\033[0;34m"     CLPurple="\033[0;35m"
    CLCyan="\033[0;36m"     CLWhite="\033[0;37m"    CLReset="\033[0m"
    CLBoldBlack="\033[1;30m"  CLBoldRed="\033[1;31m"    CLBoldGreen="\033[1;32m"
    CLBoldYellow="\033[1;33m" CLBoldBlue="\033[1;34m"   CLBoldPurple="\033[1;35m"
    CLBoldCyan="\033[1;36m"   CLBoldWhite="\033[1;37m"
    BGBlack="\033[40m"      BGRed="\033[41m"        BGGreen="\033[42m"
    BGYellow="\033[43m"     BGBlue="\033[44m"       BGPurple="\033[45m"
    BGCyan="\033[46m"       BGWhite="\033[47m"
    CLBlink="\033[5m"       CLBold="\033[1m"        CLUnderline="\033[4m"
    CLInverse="\033[7m"
else
    CLBlack="" CLRed="" CLGreen="" CLYellow="" CLBlue="" CLPurple="" CLCyan="" CLWhite="" CLReset=""
    CLBoldBlack="" CLBoldRed="" CLBoldGreen="" CLBoldYellow="" CLBoldBlue="" CLBoldPurple="" CLBoldCyan="" CLBoldWhite=""
    BGBlack="" BGRed="" BGGreen="" BGYellow="" BGBlue="" BGPurple="" BGCyan="" BGWhite=""
    CLBlink="" CLBold="" CLUnderline="" CLInverse=""
fi

# Global variables
SCRIPT_DIR="/tmp/rakitanmanager"
LOG_FILE="/tmp/rakitanmanager_install.log"
REQUIRED_PACKAGES="curl git git-http modemmanager python3-pip bc screen adb httping jq php8 uhttpd unzip"
PYTHON_PACKAGES="requests huawei-lte-api"
LATEST_VER_MAIN=""
LATEST_VER_DEV=""
CURRENT_VERSION=""

# Enhanced logging with icons
log() {
    icon="➤"
    case "$1" in
        "✓") icon="\033[1;32m✓\033[0m"; shift ;;
        "✗") icon="\033[1;31m✗\033[0m"; shift ;;
        "⚠") icon="\033[1;33m⚠\033[0m"; shift ;;
        "ℹ") icon="\033[1;34mℹ\033[0m"; shift ;;
    esac
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${icon} $*" | tee -a "$LOG_FILE"
}

cleanup() {
    if [ -d "$SCRIPT_DIR" ]; then
        log "ℹ" "Cleaning up temporary files..."
        rm -rf "$SCRIPT_DIR" 2>/dev/null || true
    fi
}

stop_services() {
    if pidof core-manager.sh >/dev/null 2>&1; then
        log "ℹ" "Stopping RakitanManager services..."
        pkill -f "core-manager.sh" 2>/dev/null || true
        pkill -f "rakitanmanager" 2>/dev/null || true
        sleep 2
        log "✓" "Services stopped"
    else
        log "ℹ" "RakitanManager services are not running."
    fi
}

install_package() {
    pkg="$1"
    max_retries=3
    retry=0

    if opkg list-installed 2>/dev/null | grep -q "^$pkg "; then
        log "✓" "$pkg already installed"
        return 0
    fi

    while [ $retry -lt $max_retries ]; do
        log "⚠" "Installing $pkg (attempt $((retry + 1))/$max_retries)..."
        if opkg install "$pkg" >>"$LOG_FILE" 2>&1; then
            log "✓" "$pkg installed successfully"
            return 0
        fi
        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            log "⚠" "Failed, retrying in 2s..."
            sleep 2
        fi
    done

    log "✗" "Failed to install $pkg after $max_retries attempts"
    return 1
}

show_progress() {
    current="$1"
    total="$2"
    label="$3"
    
    if [ "$total" -eq 0 ]; then total=1; fi
    percentage=$((current * 100 / total))
    bar_length=30
    filled=$((percentage * bar_length / 100))
    empty=$((bar_length - filled))
    
    printf "\r${CLBoldWhite}["
    i=0; while [ $i -lt $filled ]; do printf "${CLGreen}█"; i=$((i + 1)); done
    i=0; while [ $i -lt $empty ]; do printf "${CLYellow}░"; i=$((i + 1)); done
    printf "${CLBoldWhite}] ${CLBoldCyan}%3d%%${CLBoldWhite} ${label}${CLReset}" "$percentage"
}

detect_openwrt_type() {
    if [ -f /etc/openwrt_release ]; then
        if grep -q "SNAPSHOT" /etc/openwrt_release 2>/dev/null; then
            echo "snapshot"
            return
        fi
    fi
    
    if command -v apk >/dev/null 2>&1; then
        echo "snapshot"
    elif command -v opkg >/dev/null 2>&1; then
        echo "stable"
    else
        echo "unknown"
    fi
}

check_system_requirements() {
    log "ℹ" "Checking system requirements..."

    openwrt_type=$(detect_openwrt_type)
    if [ "$openwrt_type" = "stable" ]; then
        log "✓" "OpenWrt type stable detected"
    elif [ "$openwrt_type" = "snapshot" ]; then
        log "✓" "OpenWrt type snapshot detected"
    else
        log "⚠" "Cannot determine OpenWrt type, assuming stable"
    fi

    opkg update >>"$LOG_FILE" 2>&1 || log "⚠" "opkg update failed"

    CORE_PACKAGES="procps-ng-pkill jq coreutils-sleep"
    total=$(echo "$CORE_PACKAGES" | wc -w)
    current=0
    failed=0
    
    printf "\n${CLBoldWhite}📦 Installing Core Packages:${CLReset}\n"
    for pkg in $CORE_PACKAGES; do
        current=$((current + 1))
        show_progress "$current" "$total" "Installing ${pkg}"
        if ! install_package "$pkg"; then
            failed=$((failed + 1))
            log "✗" "Missing required package: $pkg"
        fi
    done
    printf "\n\n"
    
    if [ "$failed" -gt 0 ]; then
        log "✗" "System requirements check failed with $failed missing packages"
        return 1
    fi

    log "✓" "System requirements check passed"
    return 0
}

init_script() {
    mkdir -p "$SCRIPT_DIR/rakitanmanager" 2>/dev/null || {
        log "✗" "Failed to create temp directory"
        return 1
    }

    touch "$LOG_FILE" 2>/dev/null || log "⚠" "Logging may be limited"

    log "ℹ" "=== RakitanManager Installation Started ==="
    check_system_requirements || return 1
    return 0
}

get_latest_version() {
    branch="$1"
    url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/${branch}/version"
    out="$SCRIPT_DIR/Latest$(echo "$branch" | awk '{print toupper(substr($0,1,1)) substr($0,2)}').txt"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL -m 10 -o "$out" "$url" 2>>"$LOG_FILE"; then
            head -n1 "$out" | tr -d ' \t\n\r' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g'
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q -T 10 -O "$out" "$url" 2>>"$LOG_FILE"; then
            head -n1 "$out" | tr -d ' \t\n\r' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g'
            return 0
        fi
    fi
    
    echo ""
    return 1
}

get_version_info() {
    LATEST_VER_MAIN=$(get_latest_version "main")
    LATEST_VER_DEV=$(get_latest_version "dev")

    [ -z "$LATEST_VER_MAIN" ] && LATEST_VER_MAIN="Tidak Tersedia"
    [ -z "$LATEST_VER_DEV" ] && LATEST_VER_DEV="Tidak Tersedia"

    current_branch=$(uci get rakitanmanager.cfg.branch 2>/dev/null || echo "")

    if [ "$current_branch" = "main" ] && [ -f /www/rakitanmanager/versionmain.txt ]; then
        CURRENT_VERSION=$(head -n1 /www/rakitanmanager/versionmain.txt | tr -d ' \t\n\r' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta | Branch Main/g')
    elif [ "$current_branch" = "dev" ] && [ -f /www/rakitanmanager/versiondev.txt ]; then
        CURRENT_VERSION=$(head -n1 /www/rakitanmanager/versiondev.txt | tr -d ' \t\n\r' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta | Branch Dev/g')
    else
        CURRENT_VERSION="Belum Terinstall"
    fi
}

finish() {
    clear
    cat << EOF

${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${BGGreen}${CLBoldWhite}                  ✅ INSTALL BERHASIL ✅                     ${CLReset}${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}

${CLBoldWhite}╭──────────────────────────────────────────────────────────────────╮${CLReset}
${CLBoldWhite}│${CLGreen}  🚀 RakitanManager telah berhasil terinstall!                   ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│                                                                  │${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Akses melalui: http://192.168.1.1/rakitanmanager             ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Username: admin | Password: admin (default)                  ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│                                                                  │${CLReset}
${CLBoldWhite}│${CLBlue}  💡 Tips:                                                       ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  • Clear cache browser jika tampilan tidak muncul                ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  • Restart router jika diperlukan                               ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  • Cek log: /tmp/rakitanmanager_install.log                     ${CLBoldWhite}│${CLReset}
${CLBoldWhite}╰──────────────────────────────────────────────────────────────────╯${CLReset}

${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite} Tekan ${CLBoldGreen}apa saja${CLBoldWhite} untuk keluar dari installer...                     ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}

EOF
    read -r -n1 -s
    exit 0
}

gagal_install() {
    component="$1"
    clear
    cat << EOF

${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${BGRed}${CLBoldWhite}                  ❌ INSTALL GAGAL ❌                        ${CLReset}${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}

${CLBoldWhite}╭──────────────────────────────────────────────────────────────────╮${CLReset}
${CLBoldWhite}│${CLRed}  ❗ Gagal menginstall: ${CLBoldYellow}${component}${CLReset}
${CLBoldWhite}│                                                                  │${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Cek log error di: ${CLCyan}${LOG_FILE}${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Pastikan koneksi internet stabil                             ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Coba ulangi instalasi dengan opsi yang sama                  ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│                                                                  │${CLReset}
${CLBoldWhite}│${CLBlue}  💡 Solusi umum:                                                ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  • Periksa ruang penyimpanan: df -h                             ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  • Update package list: opkg update                             ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  • Restart router sebelum mencoba lagi                          ${CLBoldWhite}│${CLReset}
${CLBoldWhite}╰──────────────────────────────────────────────────────────────────╯${CLReset}

${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite} Tekan ${CLBoldGreen}apa saja${CLBoldWhite} untuk keluar dari installer...                     ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}

EOF
    read -r -n1 -s
    exit 1
}

install_system_packages() {
    set -- $REQUIRED_PACKAGES
    total=$#
    current=0
    failed=0
    
    printf "\n${CLBoldWhite}📦 Installing System Packages:${CLReset}\n"
    
    for pkg in $REQUIRED_PACKAGES; do
        current=$((current + 1))
        show_progress "$current" "$total" "Installing ${pkg}"
        if ! install_package "$pkg"; then
            failed=$((failed + 1))
        fi
    done
    printf "\n\n"
    
    if [ "$failed" -gt 0 ]; then
        log "⚠" "$failed package(s) failed to install (non-critical)"
    fi
    return 0
}

configure_web_server() {
    if command -v uci >/dev/null 2>&1; then
        uci set uhttpd.main.index_page='index.php' 2>/dev/null || true
        uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi' 2>/dev/null || true
        uci commit uhttpd 2>/dev/null || true
        
        if [ -x /etc/init.d/uhttpd ]; then
            /etc/init.d/uhttpd restart >>"$LOG_FILE" 2>&1 || log "⚠" "Web server restart failed"
        fi
    fi
    log "✓" "Web server configured"
}

install_python_packages() {
    if ! command -v pip3 >/dev/null 2>&1; then
        log "✗" "pip3 not found - skipping Python packages"
        return 0
    fi

    printf "\n${CLBoldWhite}🐍 Installing Python Packages:${CLReset}\n"
    pip3 install --upgrade pip --quiet >>"$LOG_FILE" 2>&1 || true

    total=$(echo "$PYTHON_PACKAGES" | wc -w)
    current=0
    
    for pkg in $PYTHON_PACKAGES; do
        current=$((current + 1))
        show_progress "$current" "$total" "Installing ${pkg}"
        
        if pip3 show "$pkg" >/dev/null 2>&1; then
            log "✓" "Python package $pkg already installed"
        else
            if pip3 install "$pkg" --quiet >>"$LOG_FILE" 2>&1; then
                log "✓" "$pkg installed"
            else
                log "⚠" "Failed: $pkg (non-critical)"
            fi
        fi
    done
    printf "\n\n"

    return 0
}

download_and_install_package() {
    branch="$1"
    branch_name=$(echo "$branch" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
    max_retries=3
    
    openwrt_type=$(detect_openwrt_type)
    log "ℹ" "Terdeteksi OpenWrt ${openwrt_type}"

    printf "\n${CLBoldWhite}⏬ Downloading RakitanManager (${branch_name} Branch):${CLReset}\n"
    
    version_url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/$branch/version"
    version_info=""
    
    if command -v curl >/dev/null 2>&1; then
        version_info=$(curl -fsSL --connect-timeout 10 "$version_url" 2>>"$LOG_FILE")
    elif command -v wget >/dev/null 2>&1; then
        version_info=$(wget -qO- --timeout=10 "$version_url" 2>>"$LOG_FILE")
    fi

    if [ -z "$version_info" ]; then
        log "✗" "Cannot fetch version info"
        return 1
    fi

    latest_version=$(echo "$version_info" | grep -o 'v[0-9.]*' | head -1 | cut -c2-)
    if [ -z "$latest_version" ]; then
        log "✗" "Cannot parse version"
        return 1
    fi

    log "ℹ" "Latest version: $latest_version"
    
    package_file="$SCRIPT_DIR/rakitanmanager_pkg"
    
    if [ "$openwrt_type" = "snapshot" ]; then
        package_ext="apk"
        package_patterns="luci-app-rakitanmanager-${latest_version}-r1.apk luci-app-rakitanmanager-${latest_version}.apk"
    else
        package_ext="ipk"
        package_patterns="luci-app-rakitanmanager_${latest_version}-1_all.ipk luci-app-rakitanmanager_${latest_version}_all.ipk"
    fi
    
    success=0
    
    for pattern in $package_patterns; do
        package_url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/$branch/$pattern"
        log "ℹ" "Trying: $pattern"
        
        retry=0
        while [ $retry -lt $max_retries ]; do
            downloaded=0
            
            if command -v curl >/dev/null 2>&1; then
                if curl -fL --connect-timeout 15 --max-time 60 -o "$package_file" "$package_url" 2>>"$LOG_FILE"; then
                    downloaded=1
                fi
            elif command -v wget >/dev/null 2>&1; then
                if wget -T 15 -O "$package_file" "$package_url" 2>>"$LOG_FILE"; then
                    downloaded=1
                fi
            fi
            
            if [ $downloaded -eq 1 ] && [ -s "$package_file" ]; then
                log "✓" "Package downloaded: $pattern"
                
                log "ℹ" "Installing package ($package_ext format)"
                if opkg install "$package_file" --force-reinstall >>"$LOG_FILE" 2>&1; then
                    success=1
                    break 2
                else
                    log "⚠" "Installation failed, trying next pattern..."
                fi
            fi
            
            retry=$((retry + 1))
            if [ $retry -lt $max_retries ]; then
                log "⚠" "Retrying... ($retry/$max_retries)"
                sleep 3
            fi
        done
    done
    
    rm -f "$package_file" 2>/dev/null
    
    if [ $success -eq 0 ]; then
        log "✗" "Failed to download or install package for version $latest_version"
        return 1
    fi
    
    log "✓" "RakitanManager successfully installed!"
    return 0
}

install_packages() {
    install_system_packages
    configure_web_server
    install_python_packages
    return 0
}

install_upgrade_main() {
    clear
    cat << EOF

${CLBoldCyan}╔════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite}      🌿 Installing RakitanManager (MAIN BRANCH)       ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════╝${CLReset}

EOF
    
    stop_services
    install_packages
    if download_and_install_package "main"; then
        uci set rakitanmanager.cfg.branch='main' 2>/dev/null || true
        uci commit rakitanmanager 2>/dev/null || true
        finish
    else
        gagal_install "RakitanManager (main branch)"
    fi
}

install_upgrade_dev() {
    clear
    cat << EOF

${CLBoldCyan}╔════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite}      🔥 Installing RakitanManager (DEV BRANCH)        ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════╝${CLReset}

EOF
    
    stop_services
    install_packages
    if download_and_install_package "dev"; then
        uci set rakitanmanager.cfg.branch='dev' 2>/dev/null || true
        uci commit rakitanmanager 2>/dev/null || true
        finish
    else
        gagal_install "RakitanManager (dev branch)"
    fi
}

uninstaller() {
    clear
    cat << EOF

${CLBoldCyan}╔════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite}          🗑️  Uninstalling RakitanManager              ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════╝${CLReset}

EOF
    
    stop_services
    
    if opkg list-installed 2>/dev/null | grep -q "^luci-app-rakitanmanager "; then
        log "ℹ" "Removing package..."
        opkg remove luci-app-rakitanmanager >>"$LOG_FILE" 2>&1 || log "⚠" "Package removal failed"
    fi
    
    uci delete rakitanmanager 2>/dev/null || true
    uci commit 2>/dev/null || true
    
    rm -rf /usr/share/rakitanmanager /www/rakitanmanager /var/log/rakitanmanager.log 2>/dev/null || true
    
    log "✓" "Uninstallation completed"

    clear
    cat << EOF

${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${BGGreen}${CLBoldWhite}                ✅ UNINSTALL BERHASIL ✅                    ${CLReset}${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}

${CLBoldWhite}╭──────────────────────────────────────────────────────────────────╮${CLReset}
${CLBoldWhite}│${CLGreen}  ✔ Semua komponen RakitanManager telah dihapus                  ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Anda dapat menginstall ulang kapan saja                      ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  ➤ File konfigurasi dan data user telah dihapus                 ${CLBoldWhite}│${CLReset}
${CLBoldWhite}╰──────────────────────────────────────────────────────────────────╯${CLReset}

${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite} Tekan ${CLBoldGreen}apa saja${CLBoldWhite} untuk kembali ke menu...                        ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}

EOF
    read -r -n1 -s
}

show_menu() {
    get_version_info

    clear
    
    cpu_info=$(ubus call system board 2>/dev/null | grep -o '"system"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo 'Unknown')
    model_info=$(ubus call system board 2>/dev/null | grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo 'Unknown')
    
    cat << EOF

${CLBoldCyan}╔══════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLReset} ${CLBoldWhite}🚀 RAKITAN MANAGER AUTO INSTALLER${CLReset} ${CLBoldYellow}v2.1${CLReset} ${CLBoldWhite}🚀${CLReset}        ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚══════════════════════════════════════════════════════════════════╝${CLReset}

${CLBoldCyan}╔══════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLReset} ${CLBoldWhite}💻 Sistem Informasi${CLReset}                                          ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLYellow}• CPU:${CLReset} ${cpu_info}
${CLBoldCyan}║${CLReset} ${CLYellow}• Model:${CLReset} ${model_info}
${CLBoldCyan}╚══════════════════════════════════════════════════════════════════╝${CLReset}

${CLBoldCyan}╔══════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLReset} ${CLBoldWhite}📦 Versi Terinstall${CLReset}                                          ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLGreen}• Saat Ini:${CLReset} ${CLBoldWhite}${CURRENT_VERSION}${CLReset}
${CLBoldCyan}║${CLReset} ${CLGreen}• Main Branch:${CLReset} ${CLBoldGreen}${LATEST_VER_MAIN}${CLReset}
${CLBoldCyan}║${CLReset} ${CLYellow}• Dev Branch:${CLReset} ${CLBoldYellow}${LATEST_VER_DEV}${CLReset}
${CLBoldCyan}╚══════════════════════════════════════════════════════════════════╝${CLReset}

${CLBoldCyan}╔══════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLReset} ${CLBoldWhite}🎮 MENU UTAMA${CLReset}                                                ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldGreen}1${CLWhite}] ${CLGreen}Install/Upgrade - Main Branch${CLReset} ${CLBoldWhite}(Stabil)${CLReset}          ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldYellow}2${CLWhite}] ${CLYellow}Install/Upgrade - Dev Branch${CLReset} ${CLBoldWhite}(Terbaru)${CLReset}          ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldBlue}3${CLWhite}] ${CLBlue}Update Dependencies${CLReset} ${CLBoldWhite}(Packages saja)${CLReset}            ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldRed}4${CLWhite}] ${CLRed}Uninstall RakitanManager${CLReset}                              ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldWhite}x${CLWhite}] ${CLWhite}Keluar${CLReset}                                                    ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚══════════════════════════════════════════════════════════════════╝${CLReset}

${CLBoldWhite}╭────────────────────────────────────────────────────────────────╮${CLReset}
${CLBoldWhite}│${CLReset} ${CLBoldYellow}ℹ${CLReset} ${CLYellow}Tips: Pilih branch DEV untuk fitur terbaru${CLReset}                ${CLBoldWhite}│${CLReset}
${CLBoldWhite}╰────────────────────────────────────────────────────────────────╯${CLReset}

EOF
}

main() {
    if ! init_script; then
        printf "%b" "${CLBoldRed}✗ Gagal inisialisasi skrip.${CLReset}\n" >&2
        exit 1
    fi

    while true; do
        show_menu
        printf "${CLBoldWhite}➤${CLReset} ${CLBoldYellow}Pilih Menu:${CLReset} "
        read -r opt
        echo

        case "$opt" in
            1)
                install_upgrade_main
                ;;
            2)
                install_upgrade_dev
                ;;
            3)
                clear
                cat << EOF

${CLBoldCyan}╔════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite}          🔧 Updating System Dependencies             ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════╝${CLReset}

EOF
                install_packages
                printf "\n${CLBoldGreen}✓${CLReset} ${CLBoldWhite}Update dependencies selesai!${CLReset}\n"
                read -r -n1 -s -p "$(printf "${CLBoldWhite}Tekan tombol apa saja untuk kembali ke menu...${CLReset}")"
                ;;
            4)
                uninstaller
                ;;
            x|X)
                printf "\n${CLBoldGreen}✓${CLReset} ${CLBoldWhite}Terima kasih telah menggunakan RakitanManager Installer!${CLReset}\n\n"
                exit 0
                ;;
            *)
                printf "${CLBoldRed}✗${CLReset} ${CLBoldWhite}Pilihan tidak valid. Tekan tombol apa saja untuk ulangi...${CLReset}\n"
                read -r -n1 -s
                ;;
        esac
    done
}

main