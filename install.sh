#!/bin/sh

# Colors only if output is a terminal
if [ -t 1 ]; then
    # Base Colors
    CLBlack="\033[0;30m"    CLRed="\033[0;31m"      CLGreen="\033[0;32m"
    CLYellow="\033[0;33m"   CLBlue="\033[0;34m"     CLPurple="\033[0;35m"
    CLCyan="\033[0;36m"     CLWhite="\033[0;37m"    CLReset="\033[0m"
    
    # Bold Colors
    CLBoldBlack="\033[1;30m"  CLBoldRed="\033[1;31m"    CLBoldGreen="\033[1;32m"
    CLBoldYellow="\033[1;33m" CLBoldBlue="\033[1;34m"   CLBoldPurple="\033[1;35m"
    CLBoldCyan="\033[1;36m"   CLBoldWhite="\033[1;37m"
    
    # Background Colors
    BGBlack="\033[40m"      BGRed="\033[41m"        BGGreen="\033[42m"
    BGYellow="\033[43m"     BGBlue="\033[44m"       BGPurple="\033[45m"
    BGCyan="\033[46m"       BGWhite="\033[47m"
    
    # Special Effects
    CLBlink="\033[5m"       CLBold="\033[1m"        CLUnderline="\033[4m"
    CLInverse="\033[7m"
else
    # Disable colors if not terminal
    CLBlack= CLRed= CLGreen= CLYellow= CLBlue= CLPurple= CLCyan= CLWhite= CLReset=
    CLBoldBlack= CLBoldRed= CLBoldGreen= CLBoldYellow= CLBoldBlue= CLBoldPurple= CLBoldCyan= CLBoldWhite=
    BGBlack= BGRed= BGGreen= BGYellow= BGBlue= BGPurple= BGCyan= BGWhite=
    CLBlink= CLBold= CLUnderline= CLInverse=
fi

# Global variables
SCRIPT_DIR="/tmp/rakitanmanager"
LOG_FILE="/tmp/rakitanmanager_install.log"

REQUIRED_PACKAGES="curl git git-http modemmanager python3-pip bc screen adb httping jq php8 uhttpd unzip"
PYTHON_PACKAGES="requests huawei-lte-api"

LATEST_VER_MAIN=""
LATEST_VER_DEV=""
CURRENT_VERSION=""
OPENWRT_TYPE=""   # Global untuk tipe (stable/snapshot)
PKG_MANAGER=""    # opkg atau apk
ARCH=""           # Arsitektur
BRANCH=""         # Branch OpenWrt (misal openwrt-23.05 atau SNAPSHOT)
REPO_URL="https://raw.githubusercontent.com/rtaserver/RakitanManager/package"  # Bisa diganti ke feed jika ada

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

# trap cleanup EXIT

stop_services() {
    if pidof core-manager.sh > /dev/null; then
        log "ℹ" "Stopping RakitanManager services..."
        pkill -f "core-manager.sh" 2>/dev/null
        pkill -f "rakitanmanager" 2>/dev/null
        log "✓" "Services stopped"
    else
        log "ℹ" "RakitanManager services are not running."
        return
    fi
}

install_package() {
    pkg="$1"
    max_retries=3
    retry=0

    if $PKG_MANAGER list-installed 2>/dev/null | grep -q "^$pkg "; then
        log "✓" "$pkg already installed"
        return 0
    fi

    while [ $retry -lt $max_retries ]; do
        log "⚠" "Installing $pkg (attempt $((retry + 1))/$max_retries)..."
        if $PKG_MANAGER install "$pkg" >>"$LOG_FILE" 2>&1; then
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

# Enhanced progress bar
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
    printf "${CLGreen}%${filled}s" | tr ' ' '█'
    printf "${CLYellow}%${empty}s" | tr ' ' '░'
    printf "${CLBoldWhite}] ${CLBoldCyan}%3d%%${CLBoldWhite} ${label}" "$percentage"
}

# Fungsi deteksi OpenWrt yang ditingkatkan
detect_openwrt() {
    if [ ! -f /etc/openwrt_release ]; then
        log "✗" "/etc/openwrt_release not found"
        return 1
    fi
    . /etc/openwrt_release  # Muat variabel DISTRIB_*

    if [ -x "/bin/opkg" ]; then
        PKG_MANAGER="opkg"
    elif [ -x "/usr/bin/apk" ]; then
        PKG_MANAGER="apk"
    else
        log "✗" "No supported package manager (opkg/apk)"
        return 1
    fi

    if [ ! -x "/sbin/fw4" ]; then
        log "⚠" "firewall4 not detected; may not be modern OpenWrt"
    fi

    ARCH="$DISTRIB_ARCH"
    case "$DISTRIB_RELEASE" in
        *"23.05"*) BRANCH="openwrt-23.05"; OPENWRT_TYPE="stable" ;;
        *"24.10"*) BRANCH="openwrt-24.10"; OPENWRT_TYPE="stable" ;;
        "SNAPSHOT") BRANCH="SNAPSHOT"; OPENWRT_TYPE="snapshot" ;;
        *) log "✗" "Unsupported release: $DISTRIB_RELEASE"; return 1 ;;
    esac

    log "✓" "Detected: $OPENWRT_TYPE ($DISTRIB_RELEASE, arch: $ARCH, manager: $PKG_MANAGER)"
    return 0
}

check_system_requirements() {
    log "ℹ" "Checking system requirements..."
    detect_openwrt || return 1

    $PKG_MANAGER update >>"$LOG_FILE" 2>&1 || log "⚠" "$PKG_MANAGER update failed"

    REQUIRED_PACKAGES="procps-ng-pkill jq coreutils-sleep"
    total=$(echo "$REQUIRED_PACKAGES" | wc -w)
    current=0
    failed=0
    printf "\n${CLBoldWhite}📦 Installing Required Packages:${CLReset}\n"
    for pkg in $REQUIRED_PACKAGES; do
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

get_latest_version () {
    branch="$1"
    url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/${branch}/version"
    out="$SCRIPT_DIR/Latest$(echo "$branch" | awk '{print toupper(substr($0,1,1)) substr($0,2)}').txt"

    if wget -q -T 10 -O "$out" "$url" 2>/dev/null || curl -s -m 10 -o "$out" "$url" 2>/dev/null; then
        head -n1 "$out" | tr -d ' \t\n\r' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g'
    else
        echo ""
    fi
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

# Enhanced finish screen
finish() {
    clear
    printf "%b" "
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
${CLBoldWhite}│${CLBlue}  • Cek log untuk troubleshooting: /tmp/rakitanmanager_install.log${CLBoldWhite}│${CLReset}
${CLBoldWhite}╰──────────────────────────────────────────────────────────────────╯${CLReset}

${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite} Tekan ${CLBoldGreen}apa saja${CLBoldWhite} untuk keluar dari installer...                     ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}
"
    read -r -n1 -s
    exit 0
}

# Enhanced error screen
gagal_install() {
    component="$1"
    clear
    printf "%b" "
${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${BGRed}${CLBoldWhite}                  ❌ INSTALL GAGAL ❌                        ${CLReset}${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}

${CLBoldWhite}╭──────────────────────────────────────────────────────────────────╮${CLReset}
${CLBoldWhite}│${CLRed}  ❗ Gagal menginstall komponen: ${CLBoldYellow}${component}                      ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│                                                                  │${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Cek log error di: ${CLCyan}${LOG_FILE}                          ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Pastikan koneksi internet stabil                             ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Coba ulangi instalasi dengan opsi yang sama                  ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│                                                                  │${CLReset}
${CLBoldWhite}│${CLBlue}  💡 Solusi umum:                                                ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  • Periksa ruang penyimpanan: df -h                             ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  • Update package list: $PKG_MANAGER update                     ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  • Restart router sebelum mencoba lagi                          ${CLBoldWhite}│${CLReset}
${CLBoldWhite}╰──────────────────────────────────────────────────────────────────╯${CLReset}

${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite} Tekan ${CLBoldGreen}apa saja${CLBoldWhite} untuk keluar dari installer...                     ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}
"
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
        log "⚠" "$failed package(s) failed to install"
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
    log "✓" "Web server configured"
}

install_python_packages() {
    if ! command -v pip3 >/dev/null 2>&1; then
        log "✗" "pip3 not found"
        return 1
    fi

    printf "\n${CLBoldWhite}🐍 Installing Python Packages:${CLReset}\n"
    pip3 install --upgrade pip --quiet >>"$LOG_FILE" 2>&1 || true

    failures=""
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
                log "✗" "Failed: $pkg"
                failures="$failures $pkg"
            fi
        fi
    done
    printf "\n\n"

    if [ -n "$failures" ]; then
        log "⚠" "Failed Python packages:$failures"
        return 1
    fi
    return 0
}

download_and_install_package() {
    branch="$1"
    branch_name=$(echo "$branch" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
    max_retries=3

    printf "\n${CLBoldWhite}⏬ Downloading RakitanManager (${branch_name} Branch):${CLReset}\n"

    version_url="$REPO_URL/${branch}/version"
    version_info=$(curl -s --connect-timeout 10 "$version_url" 2>/dev/null || wget -qO- --timeout=10 "$version_url" 2>/dev/null)

    if [ -z "$version_info" ]; then
        log "✗" "Cannot fetch version info"
        return 1
    fi

    latest_version=$(echo "$version_info" | head -n1 | tr -d ' \t\n\r')

    package_file="$SCRIPT_DIR/rakitanmanager_pkg"
    success=0
    tried_urls=""
    patterns=()
    if [ "$OPENWRT_TYPE" = "stable" ]; then
        patterns=("luci-app-rakitanmanager_${latest_version}-1_all.ipk" "luci-app-rakitanmanager_${latest_version}_all.ipk")
    else
        patterns=("luci-app-rakitanmanager-${latest_version}-r1.apk" "luci-app-rakitanmanager-${latest_version}.apk")
    fi

    for pattern in "${patterns[@]}"; do
        package_url="$REPO_URL/$branch/$pattern"
        tried_urls="$tried_urls\n  • $package_url"
        log "ℹ" "Mencoba URL: $package_url"

        retry=0
        while [ $retry -lt $max_retries ]; do
            if command -v curl >/dev/null 2>&1; then
                curl -fL --connect-timeout 15 --max-time 60 -o "$package_file" "$package_url" >>"$LOG_FILE" 2>&1
            elif command -v wget >/dev/null 2>&1; then
                wget -T 15 -O "$package_file" "$package_url" >>"$LOG_FILE" 2>&1
            else
                log "✗" "No downloader available"
                return 1
            fi

            if [ -s "$package_file" ]; then
                log "✓" "Package berhasil diunduh: $(basename "$package_file")"

                if [ "$PKG_MANAGER" = "opkg" ]; then
                    log "ℹ" "Menginstall package OpenWrt Stabil (.ipk)"
                    if opkg install "$package_file" --force-reinstall >>"$LOG_FILE" 2>&1; then
                        success=1
                        break 2
                    fi
                else
                    log "ℹ" "Menginstall package OpenWrt Snapshot (.apk)"
                    if apk add --allow-untrusted "$package_file" >>"$LOG_FILE" 2>&1; then
                        success=1
                        break 2
                    fi
                fi
            fi

            retry=$((retry + 1))
            if [ $retry -lt $max_retries ]; then
                log "⚠" "Gagal, mencoba ulang ($retry/$max_retries)..."
                sleep 3
            fi
        done
    done

    rm -f "$package_file" "$index_file" 2>/dev/null

    if [ $success -eq 0 ]; then
        log "✗" "Gagal menemukan package yang cocok untuk versi $latest_version"
        log "ℹ" "URL yang telah dicoba:$tried_urls"
        return 1
    fi

    log "✓" "RakitanManager berhasil diinstall!"
    return 0
}

install_packages() {
    install_system_packages || log "⚠" "System packages had issues"
    configure_web_server
    install_python_packages || log "⚠" "Python packages had issues"
    return 0
}

install_upgrade_main() {
    printf "\n${CLBoldCyan}╔════════════════════════════════════════════════════════╗${CLReset}\n"
    printf "${CLBoldCyan}║${CLBoldWhite}      🌿 Installing RakitanManager (MAIN BRANCH)       ${CLBoldCyan}║${CLReset}\n"
    printf "${CLBoldCyan}╚════════════════════════════════════════════════════════╝${CLReset}\n"
    
    stop_services
    install_packages
    if download_and_install_package "main"; then
        uci set rakitanmanager.cfg.branch='main' 2>/dev/null
        uci commit rakitanmanager 2>/dev/null
        finish
    else
        gagal_install "RakitanManager (main branch)"
    fi
}

install_upgrade_dev() {
    printf "\n${CLBoldCyan}╔════════════════════════════════════════════════════════╗${CLReset}\n"
    printf "${CLBoldCyan}║${CLBoldWhite}      🔥 Installing RakitanManager (DEV BRANCH)        ${CLBoldCyan}║${CLReset}\n"
    printf "${CLBoldCyan}╚════════════════════════════════════════════════════════╝${CLReset}\n"
    
    stop_services
    install_packages
    if download_and_install_package "dev"; then
        uci set rakitanmanager.cfg.branch='dev' 2>/dev/null
        uci commit rakitanmanager 2>/dev/null
        finish
    else
        gagal_install "RakitanManager (dev branch)"
    fi
}

uninstaller() {
    printf "\n${CLBoldCyan}╔════════════════════════════════════════════════════════╗${CLReset}\n"
    printf "${CLBoldCyan}║${CLBoldWhite}          🗑️  Uninstalling RakitanManager              ${CLBoldCyan}║${CLReset}\n"
    printf "${CLBoldCyan}╚════════════════════════════════════════════════════════╝${CLReset}\n"
    
    stop_services
    if $PKG_MANAGER list-installed 2>/dev/null | grep -q "^luci-app-rakitanmanager "; then
        $PKG_MANAGER remove luci-app-rakitanmanager >>"$LOG_FILE" 2>&1
    fi
    uci delete rakitanmanager 2>/dev/null
    uci commit 2>/dev/null
    rm -rf /usr/share/rakitanmanager /www/rakitanmanager /var/log/rakitanmanager.log 2>/dev/null
    log "✓" "Uninstallation completed"

    clear
    printf "%b" "
${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${BGGreen}${CLBoldWhite}                ✅ UNINSTALL BERHASIL ✅                    ${CLReset}${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}

${CLBoldWhite}╭──────────────────────────────────────────────────────────────────╮${CLReset}
${CLBoldWhite}│${CLGreen}  ✔ Semua komponen RakitanManager telah dihapus                  ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLYellow}  ➤ Anda dapat menginstall ulang kapan saja                      ${CLBoldWhite}│${CLReset}
${CLBoldWhite}│${CLBlue}  ➤ File konfigurasi dan data user telah dihapus permanen        ${CLBoldWhite}│${CLReset}
${CLBoldWhite}╰──────────────────────────────────────────────────────────────────╯${CLReset}

${CLBoldCyan}╔════════════════════════════════════════════════════════════════════╗${CLReset}
${CLBoldCyan}║${CLBoldWhite} Tekan ${CLBoldGreen}apa saja${CLBoldWhite} untuk kembali ke menu...                        ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚════════════════════════════════════════════════════════════════════╝${CLReset}
"
    read -r -n1 -s
}

# Enhanced main menu
show_menu() {
    get_version_info

    clear
    cpu_info=$(ubus call system board 2>/dev/null | sed -n 's/.*"system":[[:space:]]*"\([^"]*\)".*/\1/p' || echo 'Unknown')
    model_info=$(ubus call system board 2>/dev/null | sed -n 's/.*"model":[[:space:]]*"\([^"]*\)".*/\1/p' || echo 'Unknown')
    board_info=$(ubus call system board 2>/dev/null | sed -n 's/.*"board_name":[[:space:]]*"\([^"]*\)".*/\1/p' || echo 'Unknown')

    # Get terminal width
    term_width=$(tput cols 2>/dev/null || echo 80)
    box_width=$((term_width - 4))
    
    printf "%b" "
${CLBoldCyan}╔${CLReset}=$(printf '=%.0s' $(seq 1 $box_width))${CLBoldCyan}╗${CLReset}
${CLBoldCyan}║${CLReset} ${CLBoldWhite}🚀${CLReset} ${CLBoldBlue}RAKITAN MANAGER AUTO INSTALLER${CLReset} ${CLBoldYellow}v2.1${CLReset} ${CLBoldWhite}🚀${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚${CLReset}=$(printf '=%.0s' $(seq 1 $box_width))${CLBoldCyan}╝${CLReset}

${CLBoldCyan}╔${CLReset}=$(printf '=%.0s' $(seq 1 $box_width))${CLBoldCyan}╗${CLReset}
${CLBoldCyan}║${CLReset} ${CLBoldWhite}💻 Sistem Informasi${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLYellow}• CPU:${CLReset} ${cpu_info} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLYellow}• Model:${CLReset} ${model_info} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLYellow}• Board:${CLReset} ${board_info} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLYellow}• Type:${CLReset} ${OPENWRT_TYPE^} (${PKG_MANAGER}) ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚${CLReset}=$(printf '=%.0s' $(seq 1 $box_width))${CLBoldCyan}╝${CLReset}

${CLBoldCyan}╔${CLReset}=$(printf '=%.0s' $(seq 1 $box_width))${CLBoldCyan}╗${CLReset}
${CLBoldCyan}║${CLReset} ${CLBoldWhite}📦 Versi Terinstall${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLGreen}• Saat Ini:${CLReset} ${CLBoldWhite}${CURRENT_VERSION}${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLGreen}• Main Branch:${CLReset} ${CLBoldGreen}${LATEST_VER_MAIN}${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLYellow}• Dev Branch:${CLReset} ${CLBoldYellow}${LATEST_VER_DEV}${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚${CLReset}=$(printf '=%.0s' $(seq 1 $box_width))${CLBoldCyan}╝${CLReset}

${CLBoldCyan}╔${CLReset}=$(printf '=%.0s' $(seq 1 $box_width))${CLBoldCyan}╗${CLReset}
${CLBoldCyan}║${CLReset} ${CLBoldWhite}🎮 MENU UTAMA${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldGreen}1${CLWhite}] ${CLGreen}Install/Upgrade - Main Branch${CLReset} ${CLBoldWhite}(Stabil)${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldYellow}2${CLWhite}] ${CLYellow}Install/Upgrade - Dev Branch${CLReset} ${CLBoldWhite}(Terbaru)${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldBlue}3${CLWhite}] ${CLBlue}Update Dependencies${CLReset} ${CLBoldWhite}(Packages saja)${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldRed}4${CLWhite}] ${CLRed}Uninstall RakitanManager${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}║${CLReset} ${CLWhite}[${CLBoldWhite}x${CLWhite}] ${CLWhite}Keluar${CLReset} ${CLBoldCyan}║${CLReset}
${CLBoldCyan}╚${CLReset}=$(printf '=%.0s' $(seq 1 $box_width))${CLBoldCyan}╝${CLReset}

${CLBoldWhite}╭─${CLReset}=$(printf '─%.0s' $(seq 1 $((box_width-2))))${CLBoldWhite}─╮${CLReset}
${CLBoldWhite}│${CLReset} ${CLBoldYellow}ℹ${CLReset} ${CLYellow}Tips: Pilih branch DEV untuk fitur terbaru (mungkin belum stabil)${CLReset} ${CLBoldWhite}│${CLReset}
${CLBoldWhite}╰─${CLReset}=$(printf '─%.0s' $(seq 1 $((box_width-2))))${CLBoldWhite}─╯${CLReset}
"
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
                printf "${CLBoldCyan}╔════════════════════════════════════════════════════════╗${CLReset}\n"
                printf "${CLBoldCyan}║${CLBoldWhite}          🔧 Updating System Dependencies             ${CLBoldCyan}║${CLReset}\n"
                printf "${CLBoldCyan}╚════════════════════════════════════════════════════════╝${CLReset}\n"
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