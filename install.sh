#!/bin/bash
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

#===================
colors=( "\e[31;1m" "\e[32;1m" "\e[33;1m" "\e[34;1m" "\e[35;1m" "\e[36;1m" ) # Array of rainbow colors
#=====================

trap ctrl_c INT

ctrl_c() {
    clear
    echo -e "Penginstallan Rakitan Manager telah dibatalkan."
    exit 1
}

echo -e "${colors[0]} Sedang Menjalankan Script. Mohon Tunggu.."
echo -e "${colors[0]} Pastikan Koneksi Internet Lancar"

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
    currentVersion=$(head -n 1 /www/rakitanmanager/versionmain.txt 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g')
fi

if [ "$(uci get rakitanmanager.cfg.branch)" = "dev" ]; then
    currentVersion=$(head -n 1 /www/rakitanmanager/versiondev.txt 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g')
fi

if [ -z "$currentVersion" ]; then
    currentVersion="Versi Tidak Ada / Tidak Terinstall"
fi

sleep 2

finish(){
    clear
    echo ""
    echo -e "${colors[0]}===================================="
    echo -e "${colors[0]}========= INSTALL BERHASIL ========="
    echo -e "${colors[0]}===================================="
    echo ""
    echo -e "${colors[1]}Silahkan Cek Di Tab Modem Dan Pilih Rakitan Manager"
    echo -e "${colors[2]}Jika Tidak Ada Silahkan Clear Cache Kemudian Logout Dan Login Kembali"
    echo -e "${colors[3]}Atau Membuka Manual Di Tab Baru : 192.168.1.1/rakitanmanager"
    echo ""
    echo -e "${colors[4]}Ulangi Instalasi Jika Ada Yang Gagal :)"
    echo ""
    echo "Ketik Apapun Untuk Kembali Ke Menu"
    read -n 1 -s -r -p ""
    bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')"
}


download_packages() {
    echo "Update dan instal prerequisites"
    clear
    opkg update
    sleep 1
    clear
    uci set uhttpd.main.index_page='index.php'
    uci set uhttpd.main.interpreter='.php=/usr/bin/php-cgi'
    uci commit uhttpd
    /etc/init.d/uhttpd restart
    sleep 1
    clear
    opkg install modemmanager
    sleep 1
    clear
    opkg install python3-pip
    sleep 1
    clear
    opkg install jq
    sleep 1
    clear
    opkg install adb
    sleep 1
    clear
    echo "Setup Package For Python3"
    if which pip3 >/dev/null; then
        # Instal paket 'requests' jika belum terinstal
        if ! pip3 show requests >/dev/null; then
            echo "Installing package 'requests'"
            if ! pip3 install requests; then
                echo -e "${colors[0]}Error installing package 'requests'"
                echo -e "${colors[0]}Setup Gagal | Mohon Coba Kembali"
                exit  # Keluar dari skrip dengan status error
            fi
        else
            echo -e "${colors[0]}Package 'requests' sudah terinstal"
        fi

        # Instal paket 'huawei-lte-api' jika belum terinstal
        if ! pip3 show huawei-lte-api >/dev/null; then
            echo "Installing package 'huawei-lte-api'"
            if ! pip3 install huawei-lte-api; then
                echo -e "${colors[0]}Error installing package 'huawei-lte-api'"
                echo -e "${colors[0]}Setup Gagal | Mohon Coba Kembali"
                exit  # Keluar dari skrip dengan status error
            fi
        else
            echo -e "${colors[0]}Package 'huawei-lte-api' sudah terinstal"
        fi
    else
        echo -e "${colors[0]}Error: 'pip3' command tidak ditemukan"
        echo -e "${colors[0]}Setup Gagal | Mohon Coba Kembali"
        exit  # Keluar dari skrip dengan status error
    fi
    echo -e "${colors[0]}Setup Package Sukses"
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
    wget -O "$DIR/rakitanmanager/rakitanmanager.ipk" "$file_url_main"
    
    # Install the downloaded package
    opkg install "$DIR/rakitanmanager/rakitanmanager.ipk" --force-reinstall
    sleep 3
    
    # Remove the downloaded package file
    rm -rf "$DIR/rakitanmanager/rakitanmanager.ipk"
    
    # Set the branch to 'main' in configuration
    uci set rakitanmanager.cfg.branch='main'
    uci commit rakitanmanager
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
    wget -O "$DIR/rakitanmanager/rakitanmanager.ipk" "$file_url_dev"
    
    # Install the downloaded package
    opkg install "$DIR/rakitanmanager/rakitanmanager.ipk" --force-reinstall
    sleep 3
    
    # Remove the downloaded package file
    rm -rf "$DIR/rakitanmanager/rakitanmanager.ipk"
    
    # Set the branch to 'dev' in configuration
    uci set rakitanmanager.cfg.branch='dev'
    uci commit rakitanmanager
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
	read -n 1 -s -r -p "${colors[3]}Ketik Apapun Untuk Kembali Ke Menu${colors[0]}"
	bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')"
}

clear
while true; do
    for color in "${colors[@]}"; do
        echo -e "${color}==================================================="
        echo -e "${color}          RAKITAN MANAGER AUTO INSTALLER           "
        echo -e "${color}==================================================="
        echo -e "${color} Versi Terinstall: ${colors[5]}${currentVersion}  "
        echo -e "${color} Versi Terbaru: ${colors[1]}${LatestVerMain} | Branch Main | Utama"
        echo -e "${color} Versi Terbaru: ${colors[1]}${LatestVerDev} | Branch Dev | Pengembangan"
        echo -e "${color}==================================================="
        echo -e "${color} Processor: ${colors[5]}$(ubus call system board | grep '\"system\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
        echo -e "${color} Device Model: ${colors[5]}$(ubus call system board | grep '\"model\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
        echo -e "${color} Device Board: ${colors[5]}$(ubus call system board | grep '\"board_name\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
        echo -e "${color}==================================================="
        echo -e "${color} Sekedar Informasi"
        echo -e "${color}  - Branch Main : Build Yang Sudah Sekiranya Lancar"
        echo -e "${color}  - Branch Dev  : Build Yang Masih Pengembangan"
        echo -e "${color}                  Sebelum Di Alihkan Ke Branch Main"
        echo -e "${color} Maka Dari Itu Jika Ada Yang Error / Bug"
        echo -e "${color} Bisa Langsung Hubungi Saya Agar Bisa Di Perbaiki"
        echo -e "${color} Terimakasih Atas Partisipasinya :)"
        echo -e "${color}==================================================="
        echo -e "${colors[5]} DAFTAR MENU :                                     "
        echo -e "${colors[5]} [\e[36m1\e[0m${colors[5]}] Install / Upgrade Rakitan Manager | ${colors[1]}Branch Main"
        echo -e "${colors[5]} [\e[36m2\e[0m${colors[5]}] Install / Upgrade Rakitan Manager | ${colors[1]}Branch Dev"
        echo -e "${colors[5]} [\e[36m3\e[0m${colors[5]}] Update Packages Saja"
        echo -e "${colors[5]} [\e[36m4\e[0m${colors[5]}] Uninstall Rakitan Manager"
        echo -e "${colors[5]}==================================================="
        echo -e "${colors[0]}"
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
done
