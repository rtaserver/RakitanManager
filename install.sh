#!/bin/bash
# Improved OpenWrt Rakitan Manager Installation Script
# This script manages the installation, upgrade, and removal of Rakitan Manager on OpenWrt

# Enable strict error handling
set -e

# Configuration variables
TEMP_DIR="/tmp"
RAKITAN_TEMP_DIR="$TEMP_DIR/rakitanmanager"
RAKITAN_WWW_DIR="/www/rakitanmanager"
RAKITAN_IPK="$RAKITAN_TEMP_DIR/rakitanmanager.ipk"
MAIN_BRANCH_URL="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main"
DEV_BRANCH_URL="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev"
INSTALLER_URL="https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh"

# Required packages
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
)

# Python packages
PYTHON_PACKAGES=(
    "requests"
    "huawei-lte-api"
    "datetime"
    "logging"
)

# Terminal colors
CLBlack="\e[0;30m"
CLRed="\e[0;31m"
CLGreen="\e[0;32m"
CLYellow="\e[0;33m"
CLBlue="\e[0;34m"
CLPurple="\e[0;35m"
CLCyan="\e[0;36m"
CLWhite="\e[0;37m"
CLReset="\e[0m"

# Background colors
BGBlack="\e[40m"
BGRed="\e[41m"
BGGreen="\e[42m"
BGYellow="\e[43m"
BGBlue="\e[44m"
BGPurple="\e[45m"
BGCyan="\e[46m"
BGWhite="\e[47m"

# Function to clean up before exit
cleanup() {
    # Remove temporary files
    if [ -f "$RAKITAN_IPK" ]; then
        rm -f "$RAKITAN_IPK"
    fi
}

# Function to handle cleanup on exit
trap_exit() {
    cleanup
    echo -e "${CLReset}"
    clear
    echo -e "${CLWhite}Penginstallan Rakitan Manager telah dibatalkan."
    exit 1
}

# Register trap for CTRL+C
trap trap_exit INT TERM

# Function to display header
display_header() {
    clear
    echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
    echo -e "${BGRed}              RAKITAN MANAGER AUTO INSTALLER              "
    echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
}

# Function to show a progress spinner
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    
    case "$level" in
        "info")
            echo -e "${CLBlue}[INFO]${CLWhite} ${message}${CLReset}"
            ;;
        "success")
            echo -e "${CLGreen}[SUCCESS]${CLWhite} ${message}${CLReset}"
            ;;
        "warning")
            echo -e "${CLYellow}[WARNING]${CLWhite} ${message}${CLReset}"
            ;;
        "error")
            echo -e "${CLRed}[ERROR]${CLWhite} ${message}${CLReset}"
            ;;
    esac
}

# Function to initialize directories
initialize_directories() {
    if [ -f "$RAKITAN_IPK" ]; then
        rm -f "$RAKITAN_IPK"
    fi

    if [ ! -d "$RAKITAN_TEMP_DIR" ]; then
        mkdir -p "$RAKITAN_TEMP_DIR"
    fi
}

# Function to get the latest version from branch
get_latest_version() {
    local branch="$1"
    local url
    local version_file
    
    if [ "$branch" = "main" ]; then
        url="${MAIN_BRANCH_URL}/version"
        version_file="$RAKITAN_TEMP_DIR/LatestMain.txt"
    else
        url="${DEV_BRANCH_URL}/version"
        version_file="$RAKITAN_TEMP_DIR/LatestDev.txt"
    fi
    
    # Use curl instead of wget for better error handling
    if ! curl -s -o "$version_file" "$url"; then
        echo "Versi Tidak Ada / Gagal Koneksi"
        return 1
    fi
    
    # Get version from file
    local ver=$(head -n 1 "$version_file" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g')
    
    if [ -z "$ver" ]; then
        echo "Versi Tidak Ada / Gagal Koneksi"
        return 1
    fi
    
    echo "$ver"
}

# Function to get current installed version
get_current_version() {
    local branch
    if command_exists uci && [ -f /etc/config/rakitanmanager ]; then
        branch=$(uci get rakitanmanager.cfg.branch 2>/dev/null)
    else
        branch=""
    fi
    
    local version_file
    if [ "$branch" = "main" ]; then
        version_file="$RAKITAN_WWW_DIR/versionmain.txt"
    elif [ "$branch" = "dev" ]; then
        version_file="$RAKITAN_WWW_DIR/versiondev.txt"
    else
        echo "Versi Tidak Ada / Tidak Terinstall"
        return 0
    fi
    
    if [ -f "$version_file" ]; then
        local ver=$(head -n 1 "$version_file" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta | Branch '"$branch"'/g')
        echo "$ver"
    else
        echo "Versi Tidak Ada / Tidak Terinstall"
    fi
}

# Function to check and install a package
check_and_install() {
    local package="$1"
    if opkg list-installed | grep -q "^$package -"; then
        log_message "info" "$package sudah terpasang."
        return 0
    else
        log_message "info" "$package belum terpasang. Menginstal $package..."
        if opkg install "$package"; then
            log_message "success" "$package berhasil diinstal."
            return 0
        else
            log_message "error" "Gagal menginstal $package."
            return 1
        fi
    fi
}

# Function to check and install Python packages
check_and_install_python() {
    local package="$1"
    if pip3 show "$package" >/dev/null 2>&1; then
        log_message "info" "Python package '$package' sudah terinstal."
        return 0
    else
        log_message "info" "Installing Python package '$package'..."
        if pip3 install "$package"; then
            log_message "success" "Python package '$package' berhasil diinstal."
            return 0
        else
            log_message "error" "Error installing Python package '$package'."
            return 1
        fi
    fi
}

# Function to configure uhttpd
configure_uhttpd() {
    log_message "info" "Configuring uhttpd..."
    
    if command_exists uci; then
        uci set uhttpd.main.index_page='index.php'
        uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
        uci commit uhttpd
        
        if /etc/init.d/uhttpd restart; then
            log_message "success" "uhttpd successfully configured."
            return 0
        else
            log_message "error" "Failed to restart uhttpd."
            return 1
        fi
    else
        log_message "error" "uci command not found. Cannot configure uhttpd."
        return 1
    fi
}

# Function to update pip
update_pip() {
    if command_exists pip3; then
        local pip_current_version=$(pip3 --version | awk '{print $2}')
        local pip_latest_version=$(pip3 install pip --upgrade --dry-run 2>&1 | grep 'pip-' | awk '{print $2}' | cut -d'-' -f2)
        
        if [ "$pip_current_version" = "$pip_latest_version" ]; then
            log_message "success" "Pip sudah up-to-date dengan versi $pip_current_version"
            return 0
        else
            log_message "info" "Upgrading pip from $pip_current_version to $pip_latest_version..."
            if pip3 install --upgrade pip; then
                log_message "success" "Pip berhasil diupgrade ke versi $pip_latest_version"
                return 0
            else
                log_message "error" "Error upgrading pip"
                return 1
            fi
        fi
    else
        log_message "error" "pip3 command not found"
        return 1
    fi
}

# Function to stop running services
stop_services() {
    if pidof core-manager.sh > /dev/null; then
        log_message "info" "Stopping RakitanManager service..."
        if killall -9 core-manager.sh; then
            log_message "success" "RakitanManager berhasil dihentikan."
            return 0
        else
            log_message "error" "Failed to stop RakitanManager service."
            return 1
        fi
    else
        log_message "info" "RakitanManager service is not running."
        return 0
    fi
}

# Function to download and install packages
download_packages() {
    log_message "info" "Updating package lists and installing prerequisites..."
    
    # Update package lists
    opkg update
    
    # Install required packages
    local failed_packages=()
    for pkg in "${REQUIRED_PACKAGES[@]}"; do
        if ! check_and_install "$pkg"; then
            failed_packages+=("$pkg")
        fi
    done
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        log_message "error" "Failed to install the following packages: ${failed_packages[*]}"
        return 1
    fi
    
    # Configure uhttpd
    if ! configure_uhttpd; then
        log_message "warning" "uhttpd configuration failed but continuing..."
    fi
    
    # Update pip and install Python packages
    log_message "info" "Setting up Python packages..."
    if ! update_pip; then
        log_message "warning" "Failed to update pip, but continuing with installation..."
    fi
    
    local failed_py_packages=()
    for pkg in "${PYTHON_PACKAGES[@]}"; do
        if ! check_and_install_python "$pkg"; then
            failed_py_packages+=("$pkg")
        fi
    done
    
    if [ ${#failed_py_packages[@]} -gt 0 ]; then
        log_message "error" "Failed to install the following Python packages: ${failed_py_packages[*]}"
        return 1
    fi
    
    log_message "success" "All required packages installed successfully."
    return 0
}

# Function to download and install Rakitan Manager
install_rakitan_manager() {
    local branch="$1"
    local branch_url
    
    if [ "$branch" = "main" ]; then
        branch_url="$MAIN_BRANCH_URL"
    else
        branch_url="$DEV_BRANCH_URL"
    fi
    
    log_message "info" "Downloading files from repo $branch..."
    
    # Get version information
    local version_info=$(curl -s "$branch_url/version")
    if [ -z "$version_info" ]; then
        log_message "error" "Failed to fetch version information."
        return 1
    fi
    
    local latest_version=$(echo "$version_info" | grep -o 'New Release-v[^"]*' | cut -d 'v' -f 2 | cut -d '-' -f1)
    if [ -z "$latest_version" ]; then
        log_message "error" "Failed to parse version information."
        return 1
    fi
    
    # Define the file URL with the latest version
    local file_url="$branch_url/luci-app-rakitanmanager_${latest_version}-beta_all.ipk"
    
    # Download the latest version of the package
    log_message "info" "Downloading package from $file_url..."
    if ! curl -s -o "$RAKITAN_IPK" "$file_url"; then
        log_message "error" "Failed to download package."
        return 1
    fi
    
    # Install the downloaded package
    log_message "info" "Installing package..."
    if ! opkg install "$RAKITAN_IPK" --force-reinstall; then
        log_message "error" "Failed to install package."
        return 1
    fi
    
    # Set the branch in configuration
    if command_exists uci; then
        uci set rakitanmanager.cfg.branch="$branch"
        uci commit rakitanmanager
    else
        log_message "warning" "uci command not found. Cannot update branch configuration."
    fi
    
    log_message "success" "Rakitan Manager ($branch branch) installed successfully."
    return 0
}

# Function for successful installation notification
installation_success() {
    display_header
    echo ""
    echo -e "${CLCyan}===================================="
    echo -e "${BGGreen}========= INSTALL BERHASIL ========="
    echo -e "${CLCyan}===================================="
    echo ""
    echo -e "${CLWhite}Silahkan Cek Di Tab Modem Dan Pilih Rakitan Manager"
    echo -e "${CLWhite}Jika Tidak Ada Silahkan Clear Cache Kemudian Logout Dan Login Kembali"
    echo -e "${CLWhite}Atau Membuka Manual Di Tab Baru : 192.168.1.1/rakitanmanager"
    echo ""
    echo -e "${CLWhite}Ulangi Instalasi Jika Ada Yang Gagal :)"
    echo ""
    echo -e "${CLWhite}Ketik Apapun Untuk Kembali Ke Menu${CLReset}"
    read -n 1 -s -r -p ""
    bash -c "$(curl -sL "$INSTALLER_URL")"
}

# Function for installation failure notification
installation_failure() {
    local component="$1"
    display_header
    echo ""
    echo -e "${CLCyan}===================================="
    echo -e "${BGRed}=========== INSTALL GAGAL ==========="
    echo -e "${CLCyan}===================================="
    echo ""
    echo -e "${CLWhite}Terdapat Kegagalan Saat Menginstall ${component}"
    echo -e "${CLWhite}Silahkan Periksa Log Error di Atas dan Ulangi Instalasi"
    echo ""
    echo -e "${CLWhite}Ketik Apapun Untuk Kembali Ke Menu${CLReset}"
    read -n 1 -s -r -p ""
    bash -c "$(curl -sL "$INSTALLER_URL")"
}

# Function to uninstall Rakitan Manager
uninstall_rakitan_manager() {
    log_message "info" "Menghapus Rakitan Manager..."
    
    # Stop services
    stop_services
    
    # Remove package
    if opkg remove luci-app-rakitanmanager; then
        log_message "success" "Rakitan Manager berhasil dihapus."
        
        # Remove configuration files
        if [ -d "$RAKITAN_WWW_DIR" ]; then
            rm -rf "$RAKITAN_WWW_DIR"
        fi
        
        # Remove UCI configuration
        if command_exists uci && [ -f /etc/config/rakitanmanager ]; then
            rm -f /etc/config/rakitanmanager
        fi
        
        return 0
    else
        log_message "error" "Gagal menghapus Rakitan Manager."
        return 1
    fi
}

# Function to get system information
get_system_info() {
    local system=""
    local model=""
    local board=""
    
    if command_exists ubus; then
        system=$(ubus call system board | grep '\"system\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')
        model=$(ubus call system board | grep '\"model\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')
        board=$(ubus call system board | grep '\"board_name\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')
    fi
    
    if [ -z "$system" ]; then
        system="Unknown"
    fi
    
    if [ -z "$model" ]; then
        model="Unknown"
    fi
    
    if [ -z "$board" ]; then
        board="Unknown"
    fi
    
    echo "system=$system&model=$model&board=$board"
}

# Function to display the main menu
display_menu() {
    # Get versions
    local latest_main=$(get_latest_version "main")
    local latest_dev=$(get_latest_version "dev")
    local current_version=$(get_current_version)
    
    # Get system info
    local system_info=$(get_system_info)
    local processor=$(echo "$system_info" | cut -d'&' -f1 | cut -d'=' -f2)
    local model=$(echo "$system_info" | cut -d'&' -f2 | cut -d'=' -f2)
    local board=$(echo "$system_info" | cut -d'&' -f3 | cut -d'=' -f2)
    
    clear
    echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
    echo -e "${BGRed}              RAKITAN MANAGER AUTO INSTALLER              "
    echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
    echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
    echo -e "${CLWhite} Versi Terinstall: ${CLBlue}${current_version}  "
    echo -e "${CLWhite} Versi Terbaru: ${CLGreen}${latest_main} | Branch Main | Utama"
    echo -e "${CLWhite} Versi Terbaru: ${CLYellow}${latest_dev} | Branch Dev | Pengembangan"
    echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
    echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
    echo -e "${CLWhite} Processor: ${CLYellow}${processor}"
    echo -e "${CLWhite} Device Model: ${CLYellow}${model}"
    echo -e "${CLWhite} Device Board: ${CLYellow}${board}"
    echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
    echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
    echo -e "${CLCyan}║ ${CLBlue}DAFTAR MENU :                                          ${CLCyan}║"
    echo -e "${CLCyan}║ ${CLWhite}[${CLCyan}◦1${CLWhite}] Install / Upgrade Rakitan Manager | ${CLGreen}Branch Main   ${CLCyan}║"
    echo -e "${CLCyan}║ ${CLWhite}[${CLCyan}◦2${CLWhite}] Install / Upgrade Rakitan Manager | ${CLYellow}Branch Dev    ${CLCyan}║"
    echo -e "${CLCyan}║ ${CLWhite}[${CLCyan}◦3${CLWhite}] Update Packages Saja                              ${CLCyan}║"
    echo -e "${CLCyan}║ ${CLWhite}[${CLCyan}◦4${CLWhite}] Uninstall Rakitan Manager                         ${CLCyan}║"
    echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
    echo -e "${CLWhite}"
    echo -e   ""
    echo -e   " Ketik [ x ] Atau [ Ctrl+C ] Untuk Keluar Dari Script"
    echo -e   " Jika Ingin Menjalankan Ulang ketik rakitanmanager di Terminal Kemudian Enter"
}

# Function to install or upgrade Rakitan Manager (main branch)
install_main() {
    log_message "info" "Memulai proses instalasi branch Main..."
    
    # Stop running services
    stop_services
    
    # Download and install required packages
    if ! download_packages; then
        installation_failure "package dependencies"
        return 1
    fi
    
    # Install Rakitan Manager
    if ! install_rakitan_manager "main"; then
        installation_failure "Rakitan Manager (main branch)"
        return 1
    fi
    
    # Installation successful
    installation_success
    return 0
}

# Function to install or upgrade Rakitan Manager (dev branch)
install_dev() {
    log_message "info" "Memulai proses instalasi branch Dev..."
    
    # Stop running services
    stop_services
    
    # Download and install required packages
    if ! download_packages; then
        installation_failure "package dependencies"
        return 1
    fi
    
    # Install Rakitan Manager
    if ! install_rakitan_manager "dev"; then
        installation_failure "Rakitan Manager (dev branch)"
        return 1
    fi
    
    # Installation successful
    installation_success
    return 0
}

# Main function
main() {
    # Initialize directories
    initialize_directories
    
    # Display welcome message
    log_message "info" "Selamat datang di Rakitan Manager Installer"
    log_message "info" "Pastikan koneksi internet lancar"
    
    # Main menu loop
    while true; do
        # Display menu
        display_menu
        
        # Get user choice
        read -p " Pilih Menu :  " opt
        echo -e ""
        
        # Process user choice
        case $opt in
            1)
                clear
                log_message "info" "Proses Install / Upgrade Branch Main akan dijalankan..."
                sleep 2
                install_main
                ;;
            2)
                clear
                log_message "info" "Proses Install / Upgrade Branch Dev akan dijalankan..."
                sleep 2
                install_dev
                ;;
            3)
                clear
                log_message "info" "Proses Update Packages, mohon ditunggu..."
                sleep 2
                if download_packages; then
                    log_message "success" "Packages berhasil diupdate."
                else
                    log_message "error" "Gagal update packages."
                fi
                sleep 2
                ;;
            4)
                clear
                log_message "info" "Proses Uninstall Rakitan Manager, mohon ditunggu..."
                sleep 2
                if uninstall_rakitan_manager; then
                    log_message "success" "Rakitan Manager berhasil dihapus."
                else
                    log_message "error" "Gagal menghapus Rakitan Manager."
                fi
                sleep 2
                ;;
            x|X)
                clear
                log_message "info" "Terima Kasih Telah Menggunakan Script Ini"
                sleep 2
                cleanup
                exit 0
                ;;
            *)
                clear
                log_message "warning" "Maaf, tidak ada opsi dengan nomor menu tersebut, silahkan ulangi kembali"
                sleep 2
                ;;
        esac
    done
}

# Run the main function
main
