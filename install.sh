#!/bin/bash
DIR="/tmp"
clear

if [ -f "$DIR/rakitanmanager.ipk" ]; then
    rm -rf "$DIR/rakitanmanager.ipk"
fi

#===================
W='\e[1;37m' # Putih
R='\e[31;1m' # Merah
G='\e[32;1m' # Hijau
Y='\e[33;1m' # Kuning
DB='\e[34;1m' # Biru Gelap
P='\e[35;1m' # Ungu
LB='\e[36;1m' # Biru Terang
#=====================

echo -e "${LB} Sedang Menjalankan Script. Mohon Tunggu.."
echo -e "${LB} Pastikan Koneksi Internet Lancar"

latestVersion=$(curl -s 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/version' | head -n 1 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g')
if [ -z "$latestVersion" ]; then
    latestVersion="Versi Tidak Ada / Tidak Terinstall"
fi

latestVersionDev=$(curl -s 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/version' | head -n 1 | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]' | sed 's/bt/beta/g')
if [ -z "$latestVersionDev" ]; then
    latestVersionDev="Versi Tidak Ada / Tidak Terinstall"
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
    echo -e "${G}====================================${W}"
    echo -e "${G}========= INSTALL BERHASIL =========${W}"
    echo -e "${G}====================================${W}"
    echo ""
    echo -e "${Y}Silahkan Cek Di Tab Modem Dan Pilih Rakitan Manager${W}"
    echo -e "${Y}Jika Tidak Ada Silahkan Clear Cache Kemudian Logout Dan Login Kembali${W}"
    echo -e "${Y}Atau Membuka Manual Di Tab Baru : 192.168.1.1/rakitanmanager${W}"
    echo ""
    echo -e "${Y}Ulangi Instalasi Jika Ada Yang Gagal :)"
    echo ""
    echo "Ketik Apapun Untuk Kembali Ke Menu"
    read -n 1 -s -r -p ""
    bash -c "$(wget -qO - --no-cache 'https://raw.githubusercontent.com/rtaserver/RakitanManager/main/install.sh')"
}


download_packages() {
    if pidof rakitanmanager.sh > /dev/null; then
        killall -9 rakitanmanager.sh
        echo "RakitanManager Berhasil Di Hentikan."
    else
        echo "RakitanManager is not running."
    fi
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
                echo -e "${R}Error installing package 'requests'${W}"
                echo -e "${R}Setup Gagal | Mohon Coba Kembali${W}"
                exit  # Keluar dari skrip dengan status error
            fi
        else
            echo -e "${G}Package 'requests' sudah terinstal${W}"
        fi

        # Instal paket 'huawei-lte-api' jika belum terinstal
        if ! pip3 show huawei-lte-api >/dev/null; then
            echo "Installing package 'huawei-lte-api'"
            if ! pip3 install huawei-lte-api; then
                echo -e "${R}Error installing package 'huawei-lte-api'${W}"
                echo -e "${R}Setup Gagal | Mohon Coba Kembali${W}"
                exit  # Keluar dari skrip dengan status error
            fi
        else
            echo -e "${G}Package 'huawei-lte-api' sudah terinstal${W}"
        fi
    else
        echo -e "${R}Error: 'pip3' command tidak ditemukan${W}"
        echo -e "${R}Setup Gagal | Mohon Coba Kembali${W}"
        exit  # Keluar dari skrip dengan status error
    fi
}

install_upgrade_main() {
    download_packages
    sleep 1
    clear
    echo "Downloading files from repo Main..."
    local version_info_main=$(curl -s https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/version)
    local latest_version_main=$(echo "$version_info_main" | grep -o 'New Release-v[^"]*' | cut -d 'v' -f 2 | cut -d '-' -f1)
    
    # Define the file URL with the latest version
    local file_url_main="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/luci-app-rakitanmanager_${latest_version_main}-beta_all.ipk"
    
    # Download the latest version of the package
    wget --no-cache -O "$DIR/rakitanmanager.ipk" "$file_url_main"
    
    # Install the downloaded package
    opkg install "$DIR/rakitanmanager.ipk" --force-reinstall
    sleep 3
    
    # Remove the downloaded package file
    rm -rf "$DIR/rakitanmanager.ipk"
    
    # Set the branch to 'main' in configuration
    uci set rakitanmanager.cfg.branch='main'
    uci commit rakitanmanager
    clear
    sleep 1
    finish
}

install_upgrade_dev() {
    download_packages
    sleep 1
    clear
    echo "Downloading files from repo Dev..."
    local version_info_dev=$(curl -s https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/version)
    local latest_version_dev=$(echo "$version_info_dev" | grep -o 'New Release-v[^"]*' | cut -d 'v' -f 2 | cut -d '-' -f1)
    
    # Define the file URL with the latest version
    local file_url_dev="https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/luci-app-rakitanmanager_${latest_version_dev}-beta_all.ipk"
    
    # Download the latest version of the package
    wget --no-cache -O "$DIR/rakitanmanager.ipk" "$file_url_dev"
    
    # Install the downloaded package
    opkg install "$DIR/rakitanmanager.ipk" --force-reinstall
    sleep 3
    
    # Remove the downloaded package file
    rm -rf "$DIR/rakitanmanager.ipk"
    
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
	read -n 1 -s -r -p "${Y}Ketik Apapun Untuk Kembali Ke Menu${W}"
	bash -c "$(wget -qO - --no-cache 'https://raw.githubusercontent.com/rtaserver/RakitanManager/main/install.sh')"
}

clear
echo -e "${DB} =================================================="
echo -e "${R}          RAKITAN MANAGER AUTO INSTALLER           "
echo -e "${DB} =================================================="
echo -e "${R} Versi Terinstall: ${LB}${currentVersion}  "
echo -e "${R} Versi Terbaru: ${G}${latestVersion} | Branch Main"
echo -e "${R} Versi Terbaru: ${G}${latestVersionDev} | Branch Dev"
echo -e "${DB} =================================================="
echo -e "${G} Processor: ${LB}$(ubus call system board | grep '\"system\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
echo -e "${G} Device Model: ${LB}$(ubus call system board | grep '\"model\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
echo -e "${G} Device Board: ${LB}$(ubus call system board | grep '\"board_name\"' | sed 's/ \+/ /g' | awk -F'\"' '{print $4}')"
echo -e "${DB} =================================================="
echo -e "${LB} DAFTAR MENU :                                     "
echo -e "${LB} [\e[36m1\e[0m${LB}] Install / Upgrade Rakitan Manager | ${G}Branch Main"
echo -e "${LB} [\e[36m2\e[0m${LB}] Install / Upgrade Rakitan Manager | ${G}Branch Dev"
echo -e "${LB} [\e[36m3\e[0m${LB}] Uninstall Rakitan Manager"
echo -e "${DB} =================================================="
echo -e "${W}"
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
echo -e Proses Uninstall Rakitan Manager, mohon ditunggu
echo -e
sleep 3
clear
uninstaller
 ;;

x) exit ;;
*) echo "Anda salah tekan " ; sleep 1 ; bash -c "$(wget -qO - --no-cache 'https://raw.githubusercontent.com/rtaserver/RakitanManager/main/install.sh')" ;;
esac