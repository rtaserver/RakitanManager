#!/bin/bash
# set -e

fix_sh() {
    sed -i 's/\r$//' /usr/bin/setuprakitanmanager.sh
    sed -i 's/\r$//' /usr/bin/rakitanmanager.sh
    sed -i 's/\r$//' /usr/bin/rakitanhilink.sh
    sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/adb-deviceinfo.sh
    sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/adb-refresh-network.sh
    sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/adb-sms.sh
    sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/service-openclash.sh
    sed -i 's/\r$//' /usr/share/rakitanmanager/plugins/systeminfo.sh
}

oIns="opkg install"
InsTxt="Installing"

chkIPK () {
	unset gbsPkg
	unset p7Pkg
	unset p8Pkg

	gbsPkg=$( opkg list-installed | grep -c "^git -\|^git-http -\|^bc -\|^screen -\|^httping -\|^adb -" )
	p7Pkg=$( opkg list-installed | grep -c "^php7-cli -\|^php7-mod-curl -" )
	p8Pkg=$( opkg list-installed | grep -c "^php8-cli -\|^php8-mod-curl -" )
		
	# Checking if packages installed
	if [[ $gbsPkg -lt 5 ]] && [[ $p7Pkg -lt 2 || $p8Pkg -lt 2 ]]; then
		echo -e "All/some required packages is not installed correctly or something wrong...."
		echo -e "Updating package repositories for Rakitan Manager..."
		opkg update
	fi
}

insIPK () {
	if [[ $(opkg list-installed | grep -c "^$1 -") == "0" ]]; then $oIns $1; fi
}


DIR="/tmp"
clear

if [ -f "$DIR/rakitanmanager.ipk" ]; then
    rm -rf "$DIR/rakitanmanager.ipk"
fi
if [ -f "/usr/bin/rakitanmanager" ]; then
    rm -rf "/usr/bin/rakitanmanager"
fi

if [ ! -d "$DIR/rakitanmanager" ]; then
    mkdir "$DIR/rakitanmanager"
fi


CLBlack="\e[0;30m"
CLRed="\e[0;31m"
CLGreen="\e[0;32m"
CLYellow="\e[0;33m"
CLBlue="\e[0;34m"
CLPurple="\e[0;35m"
CLCyan="\e[0;36m"
CLWhite="\e[0;37m"

BGBlack="\e[40m"
BGRed="\e[41m"
BGGreen="\e[42m"
BGYellow="\e[43m"
BGBlue="\e[44m"
BGPurple="\e[45m"
BGCyan="\e[46m"
BGWhite="\e[47m"

trap ctrl_c INT

ctrl_c() {
    clear
    echo -e "Penginstallan Rakitan Manager telah dibatalkan."
    exit 1
}

echo -e "${CLWhite} Sedang Menjalankan Script. Mohon Tunggu.."
echo -e "${CLWhite} Pastikan Koneksi Internet Lancar"

LatestMain() {
    local url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/version"
    wget -q -O "$DIR/rakitanmanager/LatestMain.txt" "$url"
    local ver=$(head -n 1 "$DIR/rakitanmanager/LatestMain.txt" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g')
    echo "$ver"
}

LatestDev() {
    local url="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/version"
    wget -q -O "$DIR/rakitanmanager/LatestDev.txt" "$url"
    local ver=$(head -n 1 "$DIR/rakitanmanager/LatestDev.txt" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g')
    echo "$ver"
}

LatestVerMain=$(LatestMain)
LatestVerDev=$(LatestDev)

if [ -z "$LatestVerMain" ]; then
    LatestVerMain="Versi Tidak Ada / Gagal Koneksi"
fi

if [ -z "$LatestVerDev" ]; then
    LatestVerDev="Versi Tidak Ada / Gagal Koneksi"
fi

if [ "$(uci get rakitanmanager.cfg.branch)" = "main" ]; then
    currentVersion=$(head -n 1 /www/rakitanmanager/versionmain.txt 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta | Branch Main/g')
fi

if [ "$(uci get rakitanmanager.cfg.branch)" = "dev" ]; then
    currentVersion=$(head -n 1 /www/rakitanmanager/versiondev.txt 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta | Brach Dev/g')
fi

if [ -z "$currentVersion" ]; then
    currentVersion="Versi Tidak Ada / Tidak Terinstall"
fi

sleep 2

finish(){
    fix_sh
    clear
    echo ""
    echo -e "${CLCyan}===================================="
    echo -e "${BGRed}========= INSTALL BERHASIL ========="
    echo -e "${CLCyan}===================================="
    echo ""
    echo -e "${CLWhite}Silahkan Cek Di Tab Modem Dan Pilih Rakitan Manager"
    echo -e "${CLWhite}Jika Tidak Ada Silahkan Clear Cache Kemudian Logout Dan Login Kembali"
    echo -e "${CLWhite}Atau Membuka Manual Di Tab Baru : 192.168.1.1/rakitanmanager"
    echo ""
    echo -e "${CLWhite}Ulangi Instalasi Jika Ada Yang Gagal :)"
    echo ""
    echo "Ketik Apapun Untuk Kembali Ke Menu"
    read -n 1 -s -r -p ""
    bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')"
}

gagal_install(){
    clear
    echo ""
    echo -e "${CLCyan}===================================="
    echo -e "${BGRed}=========== INSTALL GAGAL ==========="
    echo -e "${CLCyan}===================================="
    echo ""
    echo -e "${CLWhite}Terdapat Kegagalan Saat Menginstall $1"
    echo -e "${CLWhite}Silahkan Ulangi Instalasi Jika Ada Yang Gagal :)"
    echo ""
    echo "Ketik Apapun Untuk Kembali Ke Menu"
    read -n 1 -s -r -p ""
    bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')"
}

download_packages() {
    echo "Update dan instal prerequisites"

    chkIPK

    # Try install git, git-http, bc, screen is not installed
	if [[ $gbsPkg -lt 4 ]]; then
		echo -e "Try to install modemmanager, python3-pip, bc, screen, adb, httping, jq if not installed..." 
		insIPK modemmanager
		insIPK python3-pip
		insIPK bc
		insIPK screen
		insIPK adb
		insIPK httping
        insIPK jq

	else
		echo -e "Package: modemmanager, python3-pip, bc, screen, adb, httping, jq  already installed." 
	fi

    sleep 1
    clear

    # Try install PHP if php8/php7 is not installed
	if [[ $(ls {/bin,/usr/bin,/usr/sbin} | grep -c "^php8-cli\|^php7-cli") -lt 1 ]] && [[ $(ls /usr/lib/php* | grep -c "^curl.so") -lt 1 ]]; then
		# install php7 if php8 is not available on the repo
		if [[ $(opkg list | grep -c "^php8-cli -") == 0 ]];then
			# Try install php7
			echo -e "Try to install php7 deps..." 
			insIPK php7-cli
			insIPK php7-mod-curl
		else
			# Try install php8
			echo -e "Try to install php8 deps..."
			insIPK php8-cli
			insIPK php8-mod-curl
		fi
	else
		echo -e "Package: PHP packages already installed." 
	fi
	
    sleep 1
	# Rechecking all required packages
	chkIPK

    # Configure uhttpd
    uci set uhttpd.main.index_page='index.php'
    uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci commit uhttpd
    /etc/init.d/uhttpd restart
    sleep 1
    clear

    echo "Setup Package For Python3"
    if which pip3 >/dev/null; then
        # Instal paket 'requests' jika belum terinstal
        if ! pip3 show requests >/dev/null; then
            echo "Installing package 'requests'"
            if ! pip3 install requests; then
                echo -e "${CLRed}Error installing package 'requests'"
                echo -e "${CLRed}Setup Gagal | Mohon Coba Kembali"
                gagal_install "pip3 requests"
            fi
        else
            echo -e "${CLGreen}Package 'requests' sudah terinstal"
        fi

        # Instal paket 'huawei-lte-api' jika belum terinstal
        if ! pip3 show huawei-lte-api >/dev/null; then
            echo "Installing package 'huawei-lte-api'"
            if ! pip3 install huawei-lte-api; then
                echo -e "${CLRed}Error installing package 'huawei-lte-api'"
                echo -e "${CLRed}Setup Gagal | Mohon Coba Kembali"
                gagal_install "pip3 huawei-lte-api"
            fi
        else
            echo -e "${CLGreen}Package 'huawei-lte-api' sudah terinstal"
        fi

        # Instal paket 'datetime' jika belum terinstal
        if ! pip3 show datetime >/dev/null; then
            echo "Installing package 'datetime'"
            if ! pip3 install datetime; then
                echo -e "${CLRed}Error installing package 'datetime'"
                echo -e "${CLRed}Setup Gagal | Mohon Coba Kembali"
                gagal_install "pip3 datetime"
            fi
        else
            echo -e "${CLGreen}Package 'datetime' already installed"
        fi

        # Instal paket 'logging' jika belum terinstal
        if ! pip3 show logging >/dev/null; then
            echo "Installing package 'logging'"
            if ! pip3 install logging; then
                echo -e "${CLRed}Error installing package 'logging'"
                echo -e "${CLRed}Setup Gagal | Mohon Coba Kembali"
                gagal_install "pip3 logging"
            fi
        else
            echo -e "${CLGreen}Package 'logging' already installed"
        fi
    else
        echo -e "${CLRed}Error: 'pip3' command tidak ditemukan"
        echo -e "${CLRed}Setup Gagal | Mohon Coba Kembali"
        gagal_install "pip3"
    fi
    echo -e "${CLGreen}Setup Package Sukses"
    fix_sh
    clear
}

install_upgrade_main() {
    if pidof rakitanmanager.sh > /dev/null; then
        killall -9 rakitanmanager.sh
        echo "RakitanManager Berhasil Di Hentikan."
    else
        echo "RakitanManager is not running."
    fi
    download_packages
    sleep 1
    clear
    echo "Downloading files from repo Main..."
    
    local version_info_main=$(curl -s https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/version)
    local latest_version_main=$(echo "$version_info_main" | grep -o 'New Release-v[^"]*' | cut -d 'v' -f 2 | cut -d '-' -f1)
    
    # Define the file URL with the latest version
    local file_url_main="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/luci-app-rakitanmanager_${latest_version_main}-beta_all.ipk"
    
    # Download the latest version of the package
    if wget -O "$DIR/rakitanmanager/rakitanmanager.ipk" "$file_url_main"; then
        # Install the downloaded package
        opkg install "$DIR/rakitanmanager/rakitanmanager.ipk" --force-reinstall
    else
        echo "Error: Failed to download or install the package. Exiting."
        gagal_install "rakitanmanager main"
    fi

    # Remove the downloaded package file
    rm -rf "$DIR/rakitanmanager/rakitanmanager.ipk"
    
    # Set the branch to 'main' in configuration
    uci set rakitanmanager.cfg.branch='main'
    uci commit rakitanmanager
    wget -O "/www/rakitanmanager/hash.txt" "https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/hash.txt"
    clear
    sleep 1
    finish
}

install_upgrade_dev() {
    if pidof rakitanmanager.sh > /dev/null; then
        killall -9 rakitanmanager.sh
        echo "RakitanManager Berhasil Di Hentikan."
    else
        echo "RakitanManager is not running."
    fi
    download_packages
    sleep 1
    clear
    echo "Downloading files from repo Dev..."
    
    local version_info_dev=$(curl -s https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/version)
    local latest_version_dev=$(echo "$version_info_dev" | grep -o 'New Release-v[^"]*' | cut -d 'v' -f 2 | cut -d '-' -f1)
    
    # Define the file URL with the latest version
    local file_url_dev="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/luci-app-rakitanmanager_${latest_version_dev}-beta_all.ipk"
    
    # Download the latest version of the package
    if wget -O "$DIR/rakitanmanager/rakitanmanager.ipk" "$file_url_dev"; then
        # Install the downloaded package        
        opkg install "$DIR/rakitanmanager/rakitanmanager.ipk" --force-reinstall
    else
        echo "Error: Failed to download or install the package. Exiting."
        gagal_install "rakitanmanager dev"
    fi

    # Remove the downloaded package file
    rm -rf "$DIR/rakitanmanager/rakitanmanager.ipk"
    
    # Set the branch to 'dev' in configuration
    uci set rakitanmanager.cfg.branch='dev'
    uci commit rakitanmanager
    wget -O "/www/rakitanmanager/hash.txt" "https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/hash.txt"
    clear
    sleep 1
    finish
}

uninstaller() {
	echo "Menghapus Rakitan Manager"
    if pidof rakitanmanager.sh > /dev/null; then
        killall -9 rakitanmanager.sh
        echo "RakitanManager Berhasil Di Hentikan."
    else
        echo "RakitanManager is not running."
    fi
	opkg remove luci-app-rakitanmanager
	clear
	echo "Menghapus Rakitan Manager Selesai"
	read -n 1 -s -r -p "${CLWhite}Ketik Apapun Untuk Kembali Ke Menu"
	bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')"
}

clear
while true; do
        echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
        echo -e "${BGRed}              RAKITAN MANAGER AUTO INSTALLER              "
        echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
        echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
        echo -e "${CLWhite} Versi Terinstall: ${CLBlue}${currentVersion}  "
        echo -e "${CLWhite} Versi Terbaru: ${CLGreen}${LatestVerMain} | Branch Main | Utama"
        echo -e "${CLWhite} Versi Terbaru: ${CLYellow}${LatestVerDev} | Branch Dev | Pengembangan"
        echo -e "${CLCyan}╚════════════════════════════════════════════════════════╝"
        echo -e "${CLCyan}╔════════════════════════════════════════════════════════╗"
        echo -e "${CLWhite} Processor: ${CLYellow}$(ubus call system board | grep '\"system\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
        echo -e "${CLWhite} Device Model: ${CLYellow}$(ubus call system board | grep '\"model\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
        echo -e "${CLWhite} Device Board: ${CLYellow}$(ubus call system board | grep '\"board_name\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
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
        read -p " Pilih Menu :  "  opt
        echo -e   ""

        case $opt in
        1) clear ;
        echo -e Proses Install / Upgrade Branch Main Akan Di Jalankan, mohon ditunggu
        echo -e
        sleep 3
        clear
        install_upgrade_main
        ;;

        2) clear ;
        echo -e Proses Install / Upgrade Branch Dev Akan Di Jalankan, mohon ditunggu
        echo -e
        sleep 3
        clear
        install_upgrade_dev
        ;;

        3) clear ;
        echo -e Proses Install / Upgrade Packages, mohon ditunggu
        echo -e
        sleep 3
        clear
        download_packages
        ;;

        4) clear ;
        echo -e Proses Uninstall Rakitan Manager, mohon ditunggu
        echo -e
        sleep 3
        clear
        uninstaller
        ;;

        x) clear ;
        echo -e Terima Kasih Telah Menggunakan Script Ini
        echo -e
        sleep 2
        exit 1
        ;;
        *) clear ;
        echo -e Maaf, Tidak Ada Opsi Dengan Nomor Menu Tersebut, Silahkan Ulangi Kembali
        echo -e
        sleep 2
        ;;
        esac
done
