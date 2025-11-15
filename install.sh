#!/bin/bash
set -euo pipefail

# Enhanced error handling
trap 'error_handler $? $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT

# Colors for output
CLBlack="\e[0;30m"
CLRed="\e[0;31m"
CLGreen="\e[0;32m"
CLYellow="\e[0;33m"
CLBlue="\e[0;34m"
CLPurple="\e[0;35m"
CLCyan="\e[0;36m"
CLWhite="\e[0;37m"
CLReset="\e[0m"

BGBlack="\e[40m"
BGRed="\e[41m"
BGGreen="\e[42m"
BGYellow="\e[43m"
BGBlue="\e[44m"
BGPurple="\e[45m"
BGCyan="\e[46m"
BGWhite="\e[47m"

# Global variables
SCRIPT_DIR="/tmp/rakitanmanager"
LOG_FILE="/tmp/rakitanmanager_install.log"
INSTALLED_PACKAGES=()
FAILED_PACKAGES=()
DIR="${SCRIPT_DIR}"

# Required packages list
REQUIRED_PACKAGES=(
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
PYTHON_PACKAGES=(
    "requests"
    "huawei-lte-api"
)

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOG_FILE"
}

# Error handler
error_handler() {
    local exit_code=$1
    local line_no=$2
    local command=$3
    log "ERROR: Command '$command' failed at line $line_no with exit code $exit_code"
    # Don't auto-rollback on all errors, let specific functions handle it
    return 0
}

# Cleanup function
cleanup() {
    if [ -d "$SCRIPT_DIR" ]; then
        log "Cleaning up temporary files..."
        rm -rf "$SCRIPT_DIR" 2>/dev/null || true
    fi
}

# Rollback installation on failure
rollback_installation() {
    log "Rolling back installation..."

    # Remove installed packages
    for pkg in "${INSTALLED_PACKAGES[@]}"; do
        log "Removing package: $pkg"
        opkg remove "$pkg" 2>/dev/null || true
    done

    # Remove rakitanmanager if installed
    if opkg list-installed | grep -q "luci-app-rakitanmanager"; then
        log "Removing luci-app-rakitanmanager"
        opkg remove luci-app-rakitanmanager 2>/dev/null || true
    fi

    # Kill any running processes
    pkill -f "core-manager.sh" 2>/dev/null || true
    pkill -f "rakitanmanager" 2>/dev/null || true

    log "Rollback completed"
}

# Check system requirements
check_system_requirements() {
    log "Checking system requirements..."

    # Check if running on OpenWrt
    if [ ! -f /etc/os-release ] || ! grep -q "OpenWrt" /etc/os-release 2>/dev/null; then
        log "ERROR: This script is designed for OpenWrt systems only"
        return 1
    fi

    # Check available disk space (at least 50MB)
    local available_space
    available_space=$(df /tmp 2>/dev/null | tail -1 | awk '{print $4}')
    if [ -z "$available_space" ] || [ "$available_space" -lt 51200 ]; then
        log "WARNING: Low disk space. Need at least 50MB free space"
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
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log "⚠ $package installation failed, retrying in 2 seconds..."
                sleep 2
            fi
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

    printf "\r[%-${width}s] %d%% (%d/%d)" "$(printf '█%.0s' $(seq 1 $completed 2>/dev/null || echo ""))" "$percentage" "$current" "$total"
}

# Initialize script
init_script() {
    # Create temp directory
    mkdir -p "$SCRIPT_DIR" 2>/dev/null || true
    mkdir -p "$SCRIPT_DIR/rakitanmanager" 2>/dev/null || true

    # Initialize log file
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/dev/null"

    log "=== RakitanManager Installation Started ==="
    log "Log file: $LOG_FILE"
    log "Temp directory: $SCRIPT_DIR"

    # Check system requirements
    if ! check_system_requirements; then
        log "ERROR: System requirements check failed"
        return 1
    fi
    return 0
}

# Get latest version from GitHub
LatestMain() {
    local url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/version"
    local output_file="$DIR/rakitanmanager/LatestMain.txt"
    
    if wget -q -T 10 -t 3 -O "$output_file" "$url" 2>/dev/null; then
        local ver=$(head -n 1 "$output_file" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g')
        echo "$ver"
    else
        echo ""
    fi
}

LatestDev() {
    local url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/version"
    local output_file="$DIR/rakitanmanager/LatestDev.txt"
    
    if wget -q -T 10 -t 3 -O "$output_file" "$url" 2>/dev/null; then
        local ver=$(head -n 1 "$output_file" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g')
        echo "$ver"
    else
        echo ""
    fi
}

# Get version information
get_version_info() {
    local LatestVerMain=$(LatestMain)
    local LatestVerDev=$(LatestDev)
    local currentVersion=""

    if [ -z "$LatestVerMain" ]; then
        LatestVerMain="Versi Tidak Ada / Gagal Koneksi"
    fi

    if [ -z "$LatestVerDev" ]; then
        LatestVerDev="Versi Tidak Ada / Gagal Koneksi"
    fi

    # Get current installed version
    local current_branch=$(uci get rakitanmanager.cfg.branch 2>/dev/null || echo "")
    
    if [ "$current_branch" = "main" ] && [ -f /www/rakitanmanager/versionmain.txt ]; then
        currentVersion=$(head -n 1 /www/rakitanmanager/versionmain.txt 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta | Branch Main/g')
    elif [ "$current_branch" = "dev" ] && [ -f /www/rakitanmanager/versiondev.txt ]; then
        currentVersion=$(head -n 1 /www/rakitanmanager/versiondev.txt 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta | Branch Dev/g')
    fi

    if [ -z "$currentVersion" ]; then
        currentVersion="Versi Tidak Ada / Tidak Terinstall"
    fi

    # Export as globals
    export LATEST_VER_MAIN="$LatestVerMain"
    export LATEST_VER_DEV="$LatestVerDev"
    export CURRENT_VERSION="$currentVersion"
}

finish(){
    clear
    echo ""
    echo -e "${CLCyan}===================================="
    echo -e "${BGRed}========= INSTALL BERHASIL ========="
    echo -e "${CLCyan}====================================\n"
    echo -e "${CLWhite}Silahkan Cek Di Tab Modem Dan Pilih Rakitan Manager"
    echo -e "${CLWhite}Jika Tidak Ada Silahkan Clear Cache Kemudian Logout Dan Login Kembali"
    echo -e "${CLWhite}Atau Membuka Manual Di Tab Baru : 192.168.1.1/rakitanmanager\n"
    echo -e "${CLWhite}Ulangi Instalasi Jika Ada Yang Gagal :)\n"
    read -n 1 -s -r -p "Ketik Apapun Untuk Kembali Ke Menu"
    exec bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')"
}

gagal_install(){
    clear
    echo ""
    echo -e "${CLCyan}===================================="
    echo -e "${BGRed}=========== INSTALL GAGAL ==========="
    echo -e "${CLCyan}====================================\n"
    echo -e "${CLWhite}Terdapat Kegagalan Saat Menginstall $1"
    echo -e "${CLWhite}Silahkan Ulangi Instalasi Jika Ada Yang Gagal :)\n"
    read -n 1 -s -r -p "Ketik Apapun Untuk Kembali Ke Menu"
    exec bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')"
}

# Install system packages
install_system_packages() {
    log "Installing system packages..."

    local total_packages=${#REQUIRED_PACKAGES[@]}
    local installed_count=0
    local failed=0

    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! install_package "$pkg"; then
            failed=$((failed + 1))
        fi
        installed_count=$((installed_count + 1))
        show_progress "$installed_count" "$total_packages"
    done

    echo ""  # New line after progress bar

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

    # Configure uhttpd for PHP support
    if command -v uci >/dev/null 2>&1; then
        uci set uhttpd.main.index_page='index.php' 2>/dev/null || true
        uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi' 2>/dev/null || true
        uci commit uhttpd 2>/dev/null || true

        # Restart uhttpd service
        if [ -x /etc/init.d/uhttpd ]; then
            /etc/init.d/uhttpd restart >>"$LOG_FILE" 2>&1 || log "⚠ Failed to restart uhttpd"
        fi
    fi

    log "✓ Web server configuration attempted"
}

# Install Python packages
install_python_packages() {
    log "Installing Python packages..."

    if ! command -v pip3 >/dev/null 2>&1; then
        log "ERROR: pip3 not found"
        return 1
    fi

    # Upgrade pip if needed
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

    # Get version info
    local version_url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/$branch/version"
    local version_info
    
    version_info=$(curl -s --connect-timeout 10 --max-time 30 "$version_url" 2>/dev/null || wget -qO- --timeout=10 "$version_url" 2>/dev/null)

    if [ -z "$version_info" ]; then
        log "ERROR: Failed to get version information"
        return 1
    fi

    local latest_version
    latest_version=$(echo "$version_info" | grep -o 'New Release-v[^"]*' | head -1 | cut -d 'v' -f 2 | cut -d '-' -f1)

    if [ -z "$latest_version" ]; then
        log "ERROR: Failed to parse version information"
        return 1
    fi

    log "Latest version: $latest_version"

    local package_url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/$branch/luci-app-rakitanmanager_${latest_version}-beta_all.ipk"
    local package_file="$SCRIPT_DIR/rakitanmanager.ipk"

    while [ $retry_count -lt $max_retries ]; do
        log "Download attempt $((retry_count + 1))/$max_retries"

        # Try curl first, then wget
        if command -v curl >/dev/null 2>&1; then
            curl -L --connect-timeout 30 --max-time 300 -o "$package_file" "$package_url" >>"$LOG_FILE" 2>&1
        elif command -v wget >/dev/null 2>&1; then
            wget -T 30 -t 3 -O "$package_file" "$package_url" >>"$LOG_FILE" 2>&1
        else
            log "ERROR: Neither curl nor wget available"
            return 1
        fi

        # Verify package file
        if [ -f "$package_file" ] && [ -s "$package_file" ]; then
            log "✓ Package downloaded successfully ($(du -h "$package_file" | cut -f1))"

            log "Installing package..."
            if opkg install "$package_file" --force-reinstall >>"$LOG_FILE" 2>&1; then
                log "✓ Package installed successfully"
                rm -f "$package_file"
                return 0
            else
                log "✗ Package installation failed"
            fi
        else
            log "✗ Downloaded package file is invalid or empty"
        fi

        retry_count=$((retry_count + 1))
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

    # Kill any running processes
    pkill -f "core-manager.sh" 2>/dev/null || true
    pkill -f "rakitanmanager" 2>/dev/null || true

    # Wait for processes to stop
    sleep 2

    log "✓ Services stopped"
}

# Combined installation function
install_packages() {
    log "Starting package installation process..."

    # Install system packages
    if ! install_system_packages; then
        log "WARNING: Some system packages failed to install"
    fi

    # Configure web server
    configure_web_server

    # Install Python packages
    if ! install_python_packages; then
        log "WARNING: Some Python packages failed to install"
    fi

    log "✓ Package installation process completed"
    return 0
}

install_upgrade_main() {
    log "Starting RakitanManager installation from main branch..."

    # Initialize script
    if ! init_script; then
        gagal_install "initialization"
        return 1
    fi

    # Stop existing services
    stop_services

    # Install prerequisites
    install_packages

    # Download and install package
    if download_and_install_package "main"; then
        # Set branch configuration
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

install_upgrade_dev() {
    log "Starting RakitanManager installation from dev branch..."

    # Initialize script
    if ! init_script; then
        gagal_install "initialization"
        return 1
    fi

    # Stop existing services
    stop_services

    # Install prerequisites
    install_packages

    # Download and install package
    if download_and_install_package "dev"; then
        # Set branch configuration
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

uninstaller() {
    log "Starting RakitanManager uninstallation..."

    # Stop services
    stop_services

    # Remove package
    if opkg list-installed 2>/dev/null | grep -q "luci-app-rakitanmanager"; then
        log "Removing luci-app-rakitanmanager package..."
        if opkg remove luci-app-rakitanmanager >>"$LOG_FILE" 2>&1; then
            log "✓ Package removed successfully"
        else
            log "⚠ Failed to remove package completely"
        fi
    else
        log "Package not installed"
    fi

    # Clean up configuration
    if command -v uci >/dev/null 2>&1; then
        uci delete rakitanmanager 2>/dev/null || true
        uci commit 2>/dev/null || true
    fi

    # Clean up data files
    rm -rf /usr/share/rakitanmanager 2>/dev/null || true
    rm -rf /www/rakitanmanager 2>/dev/null || true
    rm -f /var/log/rakitanmanager.log 2>/dev/null || true

    log "✓ RakitanManager uninstalled successfully"

    clear
    echo -e "${CLGreen}Menghapus Rakitan Manager Selesai${CLReset}"
    read -n 1 -s -r -p "Ketik Apapun Untuk Kembali Ke Menu"
    exec bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')"
}

# Main menu function
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
    
    # Get system info safely
    local cpu_info=$(ubus call system board 2>/dev/null | grep '\"system\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}' 2>/dev/null || echo 'Unknown')
    local model_info=$(ubus call system board 2>/dev/null | grep '\"model\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}' 2>/dev/null || echo 'Unknown')
    local board_info=$(ubus call system board 2>/dev/null | grep '\"board_name\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}' 2>/dev/null || echo 'Unknown')
    
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
    # Disable error exit for interactive menu
    set +e
    
    # Initialize script
    if ! init_script; then
        echo -e "${CLRed}Failed to initialize script${CLReset}"
        exit 1
    fi

    # Get version information
    get_version_info

    while true; do
        show_menu
        read -p " Pilih Menu :  " opt
        echo -e ""

        case $opt in
            1)
                clear
                echo -e "${CLYellow}Proses Install / Upgrade Branch Main Akan Di Jalankan, mohon ditunggu${CLReset}"
                echo -e ""
                sleep 3
                opkg update >>"$LOG_FILE" 2>&1 || log "WARNING: opkg update failed"
                install_upgrade_main
                ;;
            2)
                clear
                echo -e "${CLYellow}Proses Install / Upgrade Branch Dev Akan Di Jalankan, mohon ditunggu${CLReset}"
                echo -e ""
                sleep 3
                opkg update >>"$LOG_FILE" 2>&1 || log "WARNING: opkg update failed"
                install_upgrade_dev
                ;;
            3)
                clear
                echo -e "${CLYellow}Proses Install / Upgrade Packages, mohon ditunggu${CLReset}"
                echo -e ""
                sleep 3
                opkg update >>"$LOG_FILE" 2>&1 || log "WARNING: opkg update failed"
                if install_packages; then
                    log "✓ Package update completed successfully"
                    echo -e "${CLGreen}Setup Package Sukses${CLReset}"
                    read -n 1 -s -r -p "Ketik Apapun Untuk Kembali Ke Menu"
                else
                    log "✗ Package update had some failures"
                    echo -e "${CLYellow}Setup Package Selesai Dengan Beberapa Masalah${CLReset}"
                    read -n 1 -s -r -p "Ketik Apapun Untuk Kembali Ke Menu"
                fi
                ;;
            4)
                clear
                echo -e "${CLYellow}Proses Uninstall Rakitan Manager, mohon ditunggu${CLReset}"
                echo -e ""
                sleep 3
                uninstaller
                ;;
            x|X)
                clear
                echo -e "${CLGreen}Terima Kasih Telah Menggunakan Script Ini${CLReset}"
                echo -e ""
                sleep 2
                cleanup
                exit 0
                ;;
            *)
                clear
                echo -e "${CLRed}Maaf, Tidak Ada Opsi Dengan Nomor Menu Tersebut, Silahkan Ulangi Kembali${CLReset}"
                echo -e ""
                sleep 2
                ;;
        esac
    done
}

# Signal handler for clean exit
trap 'echo -e "\n${CLYellow}Installation cancelled by user${CLReset}"; cleanup; exit 1' INT TERM

# Start the script
main