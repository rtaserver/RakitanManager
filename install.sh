#!/bin/sh

# Ensure POSIX compliance and avoid bashisms (since OpenWrt often uses ash/dash)
# Using /bin/sh is safer on OpenWrt

# Colors only if output is a terminal
if [ -t 1 ]; then
    CLBlack="\033[0;30m"
    CLRed="\033[0;31m"
    CLGreen="\033[0;32m"
    CLYellow="\033[0;33m"
    CLBlue="\033[0;34m"
    CLPurple="\033[0;35m"
    CLCyan="\033[0;36m"
    CLWhite="\033[0;37m"
    CLReset="\033[0m"

    BGBlack="\033[40m"
    BGRed="\033[41m"
    BGGreen="\033[42m"
    BGYellow="\033[43m"
    BGBlue="\033[44m"
    BGPurple="\033[45m"
    BGCyan="\033[46m"
    BGWhite="\033[47m"
else
    # Disable colors
    CLBlack= CLRed= CLGreen= CLYellow= CLBlue= CLPurple= CLCyan= CLWhite= CLReset=
    BGBlack= BGRed= BGGreen= BGYellow= BGBlue= BGPurple= BGCyan= BGWhite=
fi

# Global variables
SCRIPT_DIR="/tmp/rakitanmanager"
LOG_FILE="/tmp/rakitanmanager_install.log"

# Use arrays via space-separated strings (POSIX-safe)
REQUIRED_PACKAGES="curl git git-http modemmanager python3-pip bc screen adb httping jq php8 uhttpd unzip"
PYTHON_PACKAGES="requests huawei-lte-api"

LATEST_VER_MAIN=""
LATEST_VER_DEV=""
CURRENT_VERSION=""

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Cleanup function
cleanup() {
    if [ -d "$SCRIPT_DIR" ]; then
        log "Cleaning up temporary files..."
        rm -rf "$SCRIPT_DIR" 2>/dev/null || true
    fi
}

# Trap EXIT to ensure cleanup
trap cleanup EXIT

# Rollback installation on failure
rollback_installation() {
    log "Rolling back installation..."

    # Simulate reverse removal (in POSIX, no true array reverse, so just remove as-is)
    for pkg in $REQUIRED_PACKAGES; do
        if opkg list-installed 2>/dev/null | grep -q "^$pkg "; then
            log "Removing package: $pkg"
            opkg remove "$pkg" 2>/dev/null || true
        fi
    done

    if opkg list-installed 2>/dev/null | grep -q "^luci-app-rakitanmanager "; then
        log "Removing luci-app-rakitanmanager"
        opkg remove luci-app-rakitanmanager 2>/dev/null || true
    fi

    pkill -f "core-manager.sh" 2>/dev/null || true
    pkill -f "rakitanmanager" 2>/dev/null || true

    log "Rollback completed"
}

# Check system requirements
check_system_requirements() {
    log "Checking system requirements..."

    if [ ! -f /etc/os-release ]; then
        log "ERROR: /etc/os-release not found"
        return 1
    fi

    if ! grep -q "OpenWrt" /etc/os-release 2>/dev/null; then
        log "ERROR: This script is designed for OpenWrt systems only"
        return 1
    fi

    available_space=$(df /tmp 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$available_space" ] && [ "$available_space" -lt 51200 ]; then
        log "WARNING: Low disk space: ${available_space}KB (<50MB)"
    fi

    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
        log "ERROR: No internet connectivity"
        return 1
    fi

    log "System requirements check passed"
    return 0
}

# Install package with retry (POSIX-compatible loop)
install_package() {
    pkg="$1"
    max_retries=3
    retry=0

    if opkg list-installed 2>/dev/null | grep -q "^$pkg "; then
        log "✓ $pkg already installed"
        return 0
    fi

    while [ $retry -lt $max_retries ]; do
        log "Installing $pkg (attempt $((retry + 1))/$max_retries)..."
        if opkg install "$pkg" >>"$LOG_FILE" 2>&1; then
            log "✓ $pkg installed successfully"
            return 0
        fi
        retry=$((retry + 1))
        if [ $retry -lt $max_retries ]; then
            log "⚠ Failed, retrying in 2s..."
            sleep 2
        fi
    done

    log "✗ Failed to install $pkg after $max_retries attempts"
    return 1
}

# Progress indicator (simplified)
show_progress() {
    current="$1"
    total="$2"
    if [ "$total" -eq 0 ]; then total=1; fi
    percentage=$((current * 100 / total))
    printf "\r[%3d%%] (%d/%d)" "$percentage" "$current" "$total"
}

# Initialize
init_script() {
    mkdir -p "$SCRIPT_DIR/rakitanmanager" 2>/dev/null || {
        log "ERROR: Failed to create temp directory"
        return 1
    }

    touch "$LOG_FILE" 2>/dev/null || log "WARNING: Logging may be limited"

    log "=== RakitanManager Installation Started ==="
    check_system_requirements || return 1
    return 0
}

# Get version from branch
get_latest_version() {
    branch="$1"
    url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/${branch}/version"
    out="$SCRIPT_DIR/Latest$(echo "$branch" | tr '[:lower:]' '[:upper:]' | cut -c1)$(echo "$branch" | cut -c2-).txt"

    if wget -q -T 10 -O "$out" "$url" 2>/dev/null || curl -s -m 10 -o "$out" "$url" 2>/dev/null; then
        head -n1 "$out" | tr -d ' \t\n\r' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g'
    else
        echo ""
    fi
}

get_version_info() {
    LATEST_VER_MAIN=$(get_latest_version "main")
    LATEST_VER_DEV=$(get_latest_version "dev")

    [ -z "$LATEST_VER_MAIN" ] && LATEST_VER_MAIN="Versi Tidak Ada / Gagal Koneksi"
    [ -z "$LATEST_VER_DEV" ] && LATEST_VER_DEV="Versi Tidak Ada / Gagal Koneksi"

    current_branch=$(uci get rakitanmanager.cfg.branch 2>/dev/null || echo "")

    if [ "$current_branch" = "main" ] && [ -f /www/rakitanmanager/versionmain.txt ]; then
        CURRENT_VERSION=$(head -n1 /www/rakitanmanager/versionmain.txt | tr -d ' \t\n\r' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta | Branch Main/g')
    elif [ "$current_branch" = "dev" ] && [ -f /www/rakitanmanager/versiondev.txt ]; then
        CURRENT_VERSION=$(head -n1 /www/rakitanmanager/versiondev.txt | tr -d ' \t\n\r' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta | Branch Dev/g')
    else
        CURRENT_VERSION="Versi Tidak Ada / Tidak Terinstall"
    fi
}

# Success message
finish() {
    clear
    echo ""
    echo "${CLCyan}===================================="
    echo "${BGRed}========= INSTALL BERHASIL ========="
    echo "${CLCyan}===================================="
    echo ""
    echo "${CLWhite}Silahkan Cek Di Tab Modem Dan Pilih Rakitan Manager"
    echo "${CLWhite}Jika Tidak Ada: Clear Cache, Logout/Login, atau buka manual di:"
    echo "${CLWhite}http://192.168.1.1/rakitanmanager"
    echo ""
    echo "${CLWhite}Ulangi Instalasi Jika Ada Yang Gagal :)${CLReset}"
    echo ""
    read -r -n1 -s -p "Tekan tombol apa saja untuk kembali ke menu..."
    echo ""
    # Instead of exec (which can fail), just exit and let user re-run
    exit 0
}

gagal_install() {
    component="$1"
    clear
    echo ""
    echo "${CLCyan}===================================="
    echo "${BGRed}=========== INSTALL GAGAL ==========="
    echo "${CLCyan}===================================="
    echo ""
    echo "${CLWhite}Gagal saat menginstall: $component${CLReset}"
    echo "${CLWhite}Silakan ulangi instalasi.${CLReset}"
    echo ""
    read -r -n1 -s -p "Tekan tombol apa saja untuk kembali ke menu..."
    echo ""
    exit 1
}

install_system_packages() {
    set -- $REQUIRED_PACKAGES
    total=0
    for pkg; do total=$((total + 1)); done

    current=0
    failed=0
    for pkg in $REQUIRED_PACKAGES; do
        current=$((current + 1))
        show_progress "$current" "$total"
        if ! install_package "$pkg"; then
            failed=$((failed + 1))
        fi
    done
    echo ""

    if [ "$failed" -gt 0 ]; then
        log "WARNING: $failed package(s) failed"
        return 1
    fi
    return 0
}

configure_web_server() {
    if command -v uci >/dev/null 2>&1; then
        uci set uhttpd.main.index_page='index.php' 2>/dev/null
        uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi' 2>/dev/null
        uci commit uhttpd 2>/dev/null
        [ -x /etc/init.d/uhttpd ] && /etc/init.d/uhttpd restart >>"$LOG_FILE" 2>&1
    fi
    log "✓ Web server configured"
}

install_python_packages() {
    if ! command -v pip3 >/dev/null 2>&1; then
        log "ERROR: pip3 not found"
        return 1
    fi

    pip3 install --upgrade pip --quiet >>"$LOG_FILE" 2>&1 || true

    failures=""
    for pkg in $PYTHON_PACKAGES; do
        if pip3 show "$pkg" >/dev/null 2>&1; then
            log "✓ Python package $pkg already installed"
        else
            log "Installing Python package: $pkg"
            if pip3 install "$pkg" --quiet >>"$LOG_FILE" 2>&1; then
                log "✓ $pkg installed"
            else
                log "✗ Failed: $pkg"
                failures="$failures $pkg"
            fi
        fi
    done

    if [ -n "$failures" ]; then
        log "WARNING: Failed Python packages:$failures"
        return 1
    fi
    return 0
}

download_and_install_package() {
    branch="$1"
    max_retries=3
    retry=0

    version_url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/$branch/version"
    version_info=$(curl -s --connect-timeout 10 "$version_url" 2>/dev/null || wget -qO- --timeout=10 "$version_url" 2>/dev/null)

    if [ -z "$version_info" ]; then
        log "ERROR: Cannot fetch version info"
        return 1
    fi

    # Extract version like "New Release-v1.2.3-beta" → "1.2.3"
    latest_version=$(echo "$version_info" | grep -o 'v[0-9.]*' | head -1 | cut -c2-)
    if [ -z "$latest_version" ]; then
        log "ERROR: Cannot parse version"
        return 1
    fi

    package_url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/$branch/luci-app-rakitanmanager_${latest_version}-beta_all.ipk"
    package_file="$SCRIPT_DIR/rakitanmanager.ipk"

    while [ $retry -lt $max_retries ]; do
        log "Download attempt $((retry + 1))"

        if command -v curl >/dev/null 2>&1; then
            curl -L --connect-timeout 30 --max-time 300 -o "$package_file" "$package_url" >>"$LOG_FILE" 2>&1
        elif command -v wget >/dev/null 2>&1; then
            wget -T 30 -O "$package_file" "$package_url" >>"$LOG_FILE" 2>&1
        else
            log "ERROR: No downloader available"
            return 1
        fi

        if [ -s "$package_file" ]; then
            if opkg install "$package_file" --force-reinstall >>"$LOG_FILE" 2>&1; then
                rm -f "$package_file"
                return 0
            fi
        fi

        retry=$((retry + 1))
        [ $retry -lt $max_retries ] && sleep 3
    done

    log "✗ Package install failed after $max_retries tries"
    return 1
}

stop_services() {
    pkill -f "core-manager.sh" 2>/dev/null
    pkill -f "rakitanmanager" 2>/dev/null
    sleep 2
    log "✓ Services stopped"
}

install_packages() {
    install_system_packages || log "⚠ System packages had issues"
    configure_web_server
    install_python_packages || log "⚠ Python packages had issues"
    return 0  # Always continue
}

install_upgrade_main() {
    init_script || gagal_install "init"
    stop_services
    install_packages
    if download_and_install_package "main"; then
        uci set rakitanmanager.cfg.branch='main' 2>/dev/null
        uci commit rakitanmanager 2>/dev/null
        finish
    else
        gagal_install "RakitanManager (main)"
    fi
}

install_upgrade_dev() {
    init_script || gagal_install "init"
    stop_services
    install_packages
    if download_and_install_package "dev"; then
        uci set rakitanmanager.cfg.branch='dev' 2>/dev/null
        uci commit rakitanmanager 2>/dev/null
        finish
    else
        gagal_install "RakitanManager (dev)"
    fi
}

uninstaller() {
    stop_services
    if opkg list-installed | grep -q "^luci-app-rakitanmanager "; then
        opkg remove luci-app-rakitanmanager >>"$LOG_FILE" 2>&1
    fi
    uci delete rakitanmanager 2>/dev/null
    uci commit 2>/dev/null
    rm -rf /usr/share/rakitanmanager /www/rakitanmanager /var/log/rakitanmanager.log 2>/dev/null
    log "✓ Uninstalled"
    clear
    echo "${CLGreen}Menghapus Rakitan Manager Selesai${CLReset}"
    read -r -n1 -s -p "Tekan tombol apa saja..."
    exit 0
}

show_menu() {
    get_version_info

    clear
    cpu_info=$(ubus call system board 2>/dev/null | sed -n 's/.*"system":[[:space:]]*"\([^"]*\)".*/\1/p' || echo 'Unknown')
    model_info=$(ubus call system board 2>/dev/null | sed -n 's/.*"model":[[:space:]]*"\([^"]*\)".*/\1/p' || echo 'Unknown')
    board_info=$(ubus call system board 2>/dev/null | sed -n 's/.*"board_name":[[:space:]]*"\([^"]*\)".*/\1/p' || echo 'Unknown')

    cat <<EOF
${CLCyan}╔════════════════════════════════════════════════════════╗
${BGRed}              RAKITAN MANAGER AUTO INSTALLER              ${CLReset}
${CLCyan}╚════════════════════════════════════════════════════════╝
${CLCyan}╔════════════════════════════════════════════════════════╗
${CLWhite} Versi Terinstall: ${CLBlue}${CURRENT_VERSION}${CLReset}
${CLWhite} Versi Terbaru: ${CLGreen}${LATEST_VER_MAIN} | Branch Main | Utama${CLReset}
${CLWhite} Versi Terbaru: ${CLYellow}${LATEST_VER_DEV} | Branch Dev | Pengembangan${CLReset}
${CLCyan}╚════════════════════════════════════════════════════════╝
${CLCyan}╔════════════════════════════════════════════════════════╗
${CLWhite} Processor: ${CLYellow}${cpu_info}${CLReset}
${CLWhite} Device Model: ${CLYellow}${model_info}${CLReset}
${CLWhite} Device Board: ${CLYellow}${board_info}${CLReset}
${CLCyan}╚════════════════════════════════════════════════════════╝
${CLCyan}╔════════════════════════════════════════════════════════╗
${CLCyan}║ ${CLBlue}DAFTAR MENU :                                          ${CLCyan}║
${CLCyan}║ ${CLWhite}[${CLCyan}1${CLWhite}] Install / Upgrade Rakitan Manager | ${CLGreen}Branch Main   ${CLCyan}║
${CLCyan}║ ${CLWhite}[${CLCyan}2${CLWhite}] Install / Upgrade Rakitan Manager | ${CLYellow}Branch Dev    ${CLCyan}║
${CLCyan}║ ${CLWhite}[${CLCyan}3${CLWhite}] Update Packages Saja                              ${CLCyan}║
${CLCyan}║ ${CLWhite}[${CLCyan}4${CLWhite}] Uninstall Rakitan Manager                         ${CLCyan}║
${CLCyan}╚════════════════════════════════════════════════════════╝${CLReset}

 Ketik [ x ] atau [ Ctrl+C ] untuk keluar.
EOF
}

main() {
    if ! init_script; then
        echo "${CLRed}Gagal inisialisasi${CLReset}" >&2
        exit 1
    fi

    while true; do
        show_menu
        printf " Pilih Menu: "
        read -r opt
        echo

        case "$opt" in
            1)
                clear; echo "${CLYellow}Memulai instalasi Branch Main...${CLReset}"; sleep 2
                opkg update >>"$LOG_FILE" 2>&1 || log "WARN: opkg update failed"
                install_upgrade_main
                ;;
            2)
                clear; echo "${CLYellow}Memulai instalasi Branch Dev...${CLReset}"; sleep 2
                opkg update >>"$LOG_FILE" 2>&1 || log "WARN: opkg update failed"
                install_upgrade_dev
                ;;
            3)
                clear; echo "${CLYellow}Memperbarui packages...${CLReset}"; sleep 2
                opkg update >>"$LOG_FILE" 2>&1 || log "WARN: opkg update failed"
                install_packages
                echo "${CLGreen}Pembaruan selesai.${CLReset}"
                read -r -n1 -s -p "Tekan tombol apa saja..."
                ;;
            4)
                clear; echo "${CLYellow}Mencopot Rakitan Manager...${CLReset}"; sleep 2
                uninstaller
                ;;
            x|X)
                echo "${CLGreen}Terima kasih!${CLReset}"; exit 0
                ;;
            *)
                echo "${CLRed}Pilihan tidak valid.${CLReset}"; sleep 2
                ;;
        esac
    done
}

main