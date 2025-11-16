#!/bin/bash
set -euo pipefail

# Enhanced error handling: on ERR -> call error_handler then exit
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR
trap 'on_signal TERM' TERM
trap 'on_signal INT' INT
trap cleanup EXIT

# Colors for output
readonly CLBlack="\e[0;30m"
readonly CLRed="\e[0;31m"
readonly CLGreen="\e[0;32m"
readonly CLYellow="\e[0;33m"
readonly CLBlue="\e[0;34m"
readonly CLPurple="\e[0;35m"
readonly CLCyan="\e[0;36m"
readonly CLWhite="\e[0;37m"
readonly CLReset="\e[0m"

# Global variables
readonly SCRIPT_DIR="/tmp/rakitanmanager"
readonly LOG_FILE="/tmp/rakitanmanager_install.log"
INSTALLED_PACKAGES=()
FAILED_PACKAGES=()
CLEANUP_DONE=0
EXIT_ON_ERROR=1

# Required packages list (adjust as needed)
readonly REQUIRED_PACKAGES=(
    "curl"
    "git"
    "git-http"
    "modemmanager"
    "python3-pip"
    "bc"
    "screen"
    "adb"
    "httping"
    "jq"
    "php8"
    "uhttpd"
    "unzip"
)

# Python packages
readonly PYTHON_PACKAGES=(
    "requests"
    "huawei-lte-api"
)

# Version info
LATEST_VER_MAIN=""
LATEST_VER_DEV=""
CURRENT_VERSION=""

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Called on signals INT/TERM
on_signal() {
    local sig="$1"
    log "Received signal: $sig"
    rollback_installation
    cleanup
    exit 130
}

# Error handler (called by trap ERR)
error_handler() {
    local exit_code=${1:-1}
    local line_no=${2:-0}
    local command=${3:-}
    log "ERROR: Command '$command' failed at line $line_no with exit code $exit_code"
    # Attempt rollback if installed some packages
    rollback_installation
    # ensure we exit non-zero so CI / caller sees failure
    exit "${exit_code:-1}"
}

# Cleanup function
cleanup() {
    if [ "$CLEANUP_DONE" -eq 1 ]; then
        return 0
    fi
    CLEANUP_DONE=1

    if [ -d "$SCRIPT_DIR" ]; then
        log "Cleaning up temporary files..."
        rm -rf "${SCRIPT_DIR:?}" 2>/dev/null || true
    fi
}

# Rollback installation on failure
rollback_installation() {
    # don't attempt rollback if nothing installed
    if [ ${#INSTALLED_PACKAGES[@]} -eq 0 ]; then
        log "Rollback: no packages recorded as installed"
    else
        log "Rolling back installation..."
        for ((i=${#INSTALLED_PACKAGES[@]}-1; i>=0; i--)); do
            local pkg="${INSTALLED_PACKAGES[$i]}"
            log "Removing package: $pkg"
            opkg remove "$pkg" 2>/dev/null || true
        done
    fi

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

    # Check available disk space (at least 50MB)
    local available_space
    available_space=$(df /tmp 2>/dev/null | awk 'NR==2 {print $4}' || echo "")
    if [ -z "$available_space" ]; then
        log "WARNING: Could not determine available disk space"
    elif [ "$available_space" -lt 51200 ]; then
        log "WARNING: Low disk space detected: ${available_space}KB. Need at least 50MB"
    fi

    # Check internet connectivity
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
        log "ERROR: No internet connectivity detected"
        return 1
    fi

    log "System requirements check passed"
    return 0
}

# Enhanced package installation with retry
install_package() {
    local package="$1"
    local max_retries=3
    local retry_count=0

    if opkg list-installed 2>/dev/null | grep -q "^${package} "; then
        log "✓ $package already installed"
        return 0
    fi

    while [ $retry_count -lt $max_retries ]; do
        log "Installing $package (attempt $((retry_count + 1))/$max_retries)..."
        if opkg install "$package" >>"$LOG_FILE" 2>&1; then
            INSTALLED_PACKAGES+=("$package")
            log "✓ $package installed successfully"
            return 0
        fi
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            log "⚠ $package installation failed, retrying in 2 seconds..."
            sleep 2
        fi
    done

    log "✗ Failed to install $package after $max_retries attempts"
    FAILED_PACKAGES+=("$package")
    return 1
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local bar=""
    for ((i=0; i<completed; i++)); do
        bar+="█"
    done
    printf "\r[%-${width}s] %d%% (%d/%d)" "$bar" "$percentage" "$current" "$total"
}

# Initialize script
init_script() {
    mkdir -p "$SCRIPT_DIR" 2>/dev/null || {
        log "ERROR: Failed to create temp directory $SCRIPT_DIR"
        return 1
    }

    if ! touch "$LOG_FILE" 2>/dev/null; then
        echo "WARNING: Cannot write to log file $LOG_FILE, logging disabled"
    fi

    log "=== RakitanManager Installation Started ==="
    log "Log file: $LOG_FILE"
    log "Temp directory: $SCRIPT_DIR"

    if ! check_system_requirements; then
        log "ERROR: System requirements check failed"
        return 1
    fi
    return 0
}

# Get latest version from GitHub (simple)
get_latest_version() {
    local branch="$1"
    local url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/${branch}/version"
    local output_file="$SCRIPT_DIR/Latest_${branch}.txt"
    if wget -q -T 10 -t 2 -O "$output_file" "$url" 2>/dev/null; then
        head -n 1 "$output_file" 2>/dev/null | tr -d '[:space:]' || echo ""
    else
        echo ""
    fi
}

get_version_info() {
    LATEST_VER_MAIN=$(get_latest_version "main")
    LATEST_VER_DEV=$(get_latest_version "dev")

    [ -z "$LATEST_VER_MAIN" ] && LATEST_VER_MAIN="Versi Tidak Ada / Gagal Koneksi"
    [ -z "$LATEST_VER_DEV" ] && LATEST_VER_DEV="Versi Tidak Ada / Gagal Koneksi"

    local current_branch
    current_branch=$(uci get rakitanmanager.cfg.branch 2>/dev/null || echo "")

    CURRENT_VERSION=""
    if [ "$current_branch" = "main" ] && [ -f /www/rakitanmanager/versionmain.txt ]; then
        CURRENT_VERSION=$(head -n 1 /www/rakitanmanager/versionmain.txt 2>/dev/null || echo "")
    elif [ "$current_branch" = "dev" ] && [ -f /www/rakitanmanager/versiondev.txt ]; then
        CURRENT_VERSION=$(head -n 1 /www/rakitanmanager/versiondev.txt 2>/dev/null || echo "")
    fi
    [ -z "$CURRENT_VERSION" ] && CURRENT_VERSION="Versi Tidak Ada / Tidak Terinstall"
}

# finish/gagal_install: skip interactive read when NONINTERACTIVE=1
finish() {
    clear
    echo ""
    echo -e "${CLCyan}===================================="
    echo -e "${BGRed}========= INSTALL BERHASIL ========="
    echo -e "${CLCyan}====================================\n"
    echo -e "${CLWhite}Silahkan Cek Di Tab Modem Dan Pilih Rakitan Manager"
    echo -e "${CLWhite}Jika Tidak Ada Silahkan Clear Cache Kemudian Logout Dan Login Kembali"
    echo -e "${CLWhite}Atau Membuka Manual Di Tab Baru : 192.168.1.1/rakitanmanager\n"
    echo -e "${CLWhite}Ulangi Instalasi Jika Ada Yang Gagal :)\n"

    if [ "${NONINTERACTIVE:-0}" != "1" ]; then
        read -n 1 -s -r -p "Ketik Apapun Untuk Kembali Ke Menu"
        exec bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')" || exit 0
    else
        log "Install complete (non-interactive)."
        exit 0
    fi
}

gagal_install() {
    local component="$1"
    clear
    echo ""
    echo -e "${CLCyan}===================================="
    echo -e "${BGRed}=========== INSTALL GAGAL ==========="
    echo -e "${CLCyan}====================================\n"
    echo -e "${CLWhite}Terdapat Kegagalan Saat Menginstall $component"
    echo -e "${CLWhite}Silahkan Ulangi Instalasi Jika Ada Yang Gagal :)\n"

    if [ "${NONINTERACTIVE:-0}" != "1" ]; then
        read -n 1 -s -r -p "Ketik Apapun Untuk Kembali Ke Menu"
        exec bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')" || exit 1
    else
        log "Install failed for $component (non-interactive)."
        exit 1
    fi
}

# Install system packages
install_system_packages() {
    log "Installing system packages..."
    local total_packages=${#REQUIRED_PACKAGES[@]}
    local installed_count=0
    local failed=0
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! install_package "$pkg"; then
            ((failed++)) || true
        fi
        ((installed_count++)) || true
        show_progress "$installed_count" "$total_packages"
    done
    echo ""
    if [ $failed -gt 0 ]; then
        log "WARNING: $failed package(s) failed to install: ${FAILED_PACKAGES[*]}"
        return 1
    fi
    log "✓ All system packages installed successfully"
    return 0
}

# Configure web server
configure_web_server() {
    log "Configuring web server..."
    if command -v uci >/dev/null 2>&1; then
        uci set uhttpd.main.index_page='index.php' 2>/dev/null || true
        uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi' 2>/dev/null || true
        uci commit uhttpd 2>/dev/null || true
        if [ -x /etc/init.d/uhttpd ]; then
            /etc/init.d/uhttpd restart >>"$LOG_FILE" 2>&1 || log "⚠ Failed to restart uhttpd"
        fi
    fi
    log "✓ Web server configuration completed"
}

# Install Python packages
install_python_packages() {
    log "Installing Python packages..."
    if ! command -v pip3 >/dev/null 2>&1; then
        log "ERROR: pip3 not found"
        return 1
    fi
    log "Upgrading pip..."
    pip3 install --upgrade pip --quiet >>"$LOG_FILE" 2>&1 || log "⚠ Failed to upgrade pip"
    local failed_python_packages=()
    for pkg in "${PYTHON_PACKAGES[@]}"; do
        if pip3 show "$pkg" >/dev/null 2>&1; then
            log "✓ Python package $pkg already installed"
        else
            log "Installing Python package: $pkg"
            if pip3 install "$pkg" --quiet >>"$LOG_FILE" 2>&1; then
                log "✓ Python package $pkg installed"
            else
                log "✗ Failed to install Python package: $pkg"
                failed_python_packages+=("$pkg")
            fi
        fi
    done
    if [ ${#failed_python_packages[@]} -gt 0 ]; then
        log "WARNING: Some Python packages failed to install: ${failed_python_packages[*]}"
        return 1
    fi
    log "✓ All Python packages installed successfully"
    return 0
}

# Download and install package with retry
download_and_install_package() {
    local branch="$1"
    local max_retries=3
    local retry_count=0
    log "Downloading RakitanManager package from $branch branch..."
    local version_url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/$branch/version"
    local version_info
    version_info=$(curl -s --connect-timeout 10 --max-time 30 "$version_url" 2>/dev/null || wget -qO- --timeout=10 "$version_url" 2>/dev/null || true)
    if [ -z "$version_info" ]; then
        log "ERROR: Failed to get version information for branch $branch"
        return 1
    fi
    # try to extract version string robustly
    local latest_version
    latest_version=$(echo "$version_info" | head -n1 | sed 's/[^0-9\.]*//g' | tr -d '[:space:]' || echo "")
    if [ -z "$latest_version" ]; then
        log "ERROR: Failed to parse version information"
        return 1
    fi
    log "Latest version: $latest_version"
    local package_url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/$branch/luci-app-rakitanmanager_${latest_version}-beta_all.ipk"
    local package_file="$SCRIPT_DIR/rakitanmanager_${branch}.ipk"
    while [ $retry_count -lt $max_retries ]; do
        log "Download attempt $((retry_count + 1))/$max_retries"
        local download_success=0
        if command -v curl >/dev/null 2>&1; then
            if curl -L --connect-timeout 30 --max-time 300 -o "$package_file" "$package_url" >>"$LOG_FILE" 2>&1; then
                download_success=1
            fi
        elif command -v wget >/dev/null 2>&1; then
            if wget -T 30 -t 3 -O "$package_file" "$package_url" >>"$LOG_FILE" 2>&1; then
                download_success=1
            fi
        else
            log "ERROR: Neither curl nor wget available"
            return 1
        fi
        if [ "$download_success" -eq 1 ] && [ -f "$package_file" ] && [ -s "$package_file" ]; then
            local file_size
            file_size=$(du -h "$package_file" | cut -f1)
            log "✓ Package downloaded successfully ($file_size)"
            log "Installing package..."
            if opkg install "$package_file" --force-reinstall >>"$LOG_FILE" 2>&1; then
                log "✓ Package installed successfully"
                rm -f "$package_file" 2>/dev/null || true
                return 0
            else
                log "✗ Package installation failed"
            fi
        else
            log "✗ Downloaded package file is invalid or empty"
        fi
        ((retry_count++)) || true
        if [ $retry_count -lt $max_retries ]; then
            log "Retrying in 3 seconds..."
            sleep 3
        fi
    done
    log "✗ Failed to download/install package after $max_retries attempts"
    return 1
}

# Stop existing services
stop_services() {
    log "Stopping existing RakitanManager services..."
    pkill -f "core-manager.sh" 2>/dev/null || true
    pkill -f "rakitanmanager" 2>/dev/null || true
    sleep 2
    log "✓ Services stopped"
}

# Combined installation function
install_packages() {
    log "Starting package installation process..."
    local has_errors=0
    if ! install_system_packages; then
        log "WARNING: Some system packages failed to install"
        has_errors=1
    fi
    configure_web_server
    if ! install_python_packages; then
        log "WARNING: Some Python packages failed to install"
        has_errors=1
    fi
    log "✓ Package installation process completed"
    return $has_errors
}

# Install/Upgrade main
install_upgrade_main() {
    log "Starting RakitanManager installation from main branch..."
    if ! init_script; then
        gagal_install "initialization"
        return 1
    fi
    stop_services
    install_packages || true
    if download_and_install_package "main"; then
        if command -v uci >/dev/null 2>&1; then
            uci set rakitanmanager.cfg.branch='main' 2>/dev/null || true
            uci commit rakitanmanager 2>/dev/null || true
        fi
        log "✓ RakitanManager main branch installed successfully"
        finish
    else
        log "ERROR: Failed to install RakitanManager package"
        gagal_install "rakitanmanager main"
    fi
}

# Install/Upgrade dev
install_upgrade_dev() {
    log "Starting RakitanManager installation from dev branch..."
    if ! init_script; then
        gagal_install "initialization"
        return 1
    fi
    stop_services
    install_packages || true
    if download_and_install_package "dev"; then
        if command -v uci >/dev/null 2>&1; then
            uci set rakitanmanager.cfg.branch='dev' 2>/dev/null || true
            uci commit rakitanmanager 2>/dev/null || true
        fi
        log "✓ RakitanManager dev branch installed successfully"
        finish
    else
        log "ERROR: Failed to install RakitanManager package"
        gagal_install "rakitanmanager dev"
    fi
}

# Uninstaller (unchanged mostly)
uninstaller() {
    log "Starting RakitanManager uninstallation..."
    stop_services
    if opkg list-installed 2>/dev/null | grep -q "^luci-app-rakitanmanager "; then
        log "Removing luci-app-rakitanmanager package..."
        if opkg remove luci-app-rakitanmanager >>"$LOG_FILE" 2>&1; then
            log "✓ Package removed successfully"
        else
            log "⚠ Failed to remove package completely"
        fi
    else
        log "Package not installed"
    fi
    if command -v uci >/dev/null 2>&1; then
        uci delete rakitanmanager 2>/dev/null || true
        uci commit 2>/dev/null || true
    fi
    rm -rf /usr/share/rakitanmanager 2>/dev/null || true
    rm -rf /www/rakitanmanager 2>/dev/null || true
    rm -f /var/log/rakitanmanager.log 2>/dev/null || true
    log "✓ RakitanManager uninstalled successfully"
    if [ "${NONINTERACTIVE:-0}" != "1" ]; then
        clear
        echo -e "${CLGreen}Menghapus Rakitan Manager Selesai${CLReset}"
        read -n 1 -s -r -p "Ketik Apapun Untuk Kembali Ke Menu"
        exec bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')" || exit 0
    else
        log "Uninstall complete (non-interactive)."
        exit 0
    fi
}

# show_menu (unchanged but uses CURRENT_VERSION / LATEST_* from get_version_info)
show_menu() {
    clear
    echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
    echo -e "${BGRed}              RAKITAN MANAGER AUTO INSTALLER              ${CLReset}"
    echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
    echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
    echo -e "${CLWhite} Versi Terinstall: ${CLBlue}${CURRENT_VERSION}${CLReset}"
    echo -e "${CLWhite} Versi Terbaru: ${CLGreen}${LATEST_VER_MAIN} | Branch Main | Utama${CLReset}"
    echo -e "${CLWhite} Versi Terbaru: ${CLYellow}${LATEST_VER_DEV} | Branch Dev | Pengembangan${CLReset}"
    echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
    echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
    local cpu_info model_info board_info
    cpu_info=$(ubus call system board 2>/dev/null | grep '\"system\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}' 2>/dev/null || echo 'Unknown')
    model_info=$(ubus call system board 2>/dev/null | grep '\"model\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}' 2>/dev/null || echo 'Unknown')
    board_info=$(ubus call system board 2>/dev/null | grep '\"board_name\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}' 2>/dev/null || echo 'Unknown')
    echo -e "${CLWhite} Processor: ${CLYellow}${cpu_info}${CLReset}"
    echo -e "${CLWhite} Device Model: ${CLYellow}${model_info}${CLReset}"
    echo -e "${CLWhite} Device Board: ${CLYellow}${board_info}${CLReset}"
    echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
    echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
    echo -e "${CLCyan}║ ${CLBlue}DAFTAR MENU :                                          ${CLCyan}║"
    echo -e "${CLCyan}║ ${CLWhite}[${CLCyan}◦1${CLWhite}] Install / Upgrade Rakitan Manager | ${CLGreen}Branch Main   ${CLCyan}║"
    echo -e "${CLCyan}║ ${CLWhite}[${CLCyan}◦2${CLWhite}] Install / Upgrade Rakitan Manager | ${CLYellow}Branch Dev    ${CLCyan}║"
    echo -e "${CLCyan}║ ${CLWhite}[${CLCyan}◦3${CLWhite}] Update Packages Saja                              ${CLCyan}║"
    echo -e "${CLCyan}║ ${CLWhite}[${CLCyan}◦4${CLWhite}] Uninstall Rakitan Manager                         ${CLCyan}║"
    echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝${CLReset}"
    echo -e ""
    echo -e " Ketik [ x ] Atau [ Ctrl+C ] Untuk Keluar Dari Script"
    echo -e " Jika Ingin Menjalankan Ulang ketik rakitanmanager di Terminal Kemudian Enter"
}

# Main execution
main() {
    # allow errors inside menu (we already handle ERR)
    set +e
    if ! init_script; then
        echo -e "${CLRed}Failed to initialize script${CLReset}"
        exit 1
    fi
    get_version_info

    # NONINTERACTIVE mode support:
    if [ "${NONINTERACTIVE:-0}" = "1" ]; then
        BR="${BRANCH:-dev}"
        case "$BR" in
            main) log "Non-interactive: installing main"; opkg update >>"$LOG_FILE" 2>&1 || log "WARNING: opkg update failed"; install_upgrade_main ;;
            dev)  log "Non-interactive: installing dev";  opkg update >>"$LOG_FILE" 2>&1 || log "WARNING: opkg update failed"; install_upgrade_dev ;;
            uninstall|remove) log "Non-interactive: uninstalling"; uninstaller ;;
            packages) log "Non-interactive: install packages"; opkg update >>"$LOG_FILE" 2>&1 || log "WARNING: opkg update failed"; install_packages; exit $? ;;
            *) log "Unknown BRANCH value '$BR' (use main|dev|uninstall|packages)"; exit 2 ;;
        esac
        exit 0
    fi

    while true; do
        show_menu
        read -r -p " Pilih Menu :  " opt
        echo -e ""
        case $opt in
            1)
                clear
                echo -e "${CLYellow}Proses Install / Upgrade Branch Main Akan Di Jalankan, mohon ditunggu${CLReset}"
                echo -e ""
                sleep 1
                opkg update >>"$LOG_FILE" 2>&1 || log "WARNING: opkg update failed"
                install_upgrade_main
                ;;
            2)
                clear
                echo -e "${CLYellow}Proses Install / Upgrade Branch Dev Akan Di Jalankan, mohon ditunggu${CLReset}"
                echo -e ""
                sleep 1
                opkg update >>"$LOG_FILE" 2>&1 || log "WARNING: opkg update failed"
                install_upgrade_dev
                ;;
            3)
                clear
                echo -e "${CLYellow}Proses Install / Upgrade Packages, mohon ditunggu${CLReset}"
                echo -e ""
                sleep 1
                opkg update >>"$LOG_FILE" 2>&1 || log "WARNING: opkg update failed"
                if install_packages; then
                    log "✓ Package update completed successfully"
                    echo -e "${CLGreen}Setup Package Sukses${CLReset}"
                else
                    log "⚠ Package update completed with warnings"
                    echo -e "${CLYellow}Setup Package Selesai Dengan Beberapa Masalah${CLReset}"
                fi
                read -n 1 -s -r -p "Ketik Apapun Untuk Kembali Ke Menu"
                ;;
            4)
                clear
                echo -e "${CLYellow}Proses Uninstall Rakitan Manager, mohon ditunggu${CLReset}"
                echo -e ""
                sleep 1
                uninstaller
                ;;
            x|X)
                clear
                echo -e "${CLGreen}Terima Kasih Telah Menggunakan Script Ini${CLReset}"
                echo -e ""
                sleep 1
                cleanup
                exit 0
                ;;
            *)
                clear
                echo -e "${CLRed}Maaf, Tidak Ada Opsi Dengan Nomor Menu Tersebut, Silahkan Ulangi Kembali${CLReset}"
                echo -e ""
                sleep 1
                ;;
        esac
    done
}

# Start
main
