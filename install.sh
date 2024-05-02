#!/bin/bash
# RTASERVER.

DIR=/tmp

clear
echo ""
echo -e "\e[1;35m========== OpenWrt Rakitan Manager ==========\e[0m"
echo -e "\e[1;35m=========== Auto Script Installer ===========\e[0m"
echo ""

install_update(){
    echo "Update and install prerequisites"
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
                echo -e "\e[1;31mError installing package 'requests'\e[0m"
                echo -e "\e[1;31mSetup Gagal | Mohon Coba Kembali\e[0m"
                exit  # Keluar dari skrip dengan status error
            fi
        else
            echo -e "\e[1;32mPackage 'requests' already installed\e[0m"
        fi

        # Instal paket 'huawei-lte-api' jika belum terinstal
        if ! pip3 show huawei-lte-api >/dev/null; then
            echo "Installing package 'huawei-lte-api'"
            if ! pip3 install huawei-lte-api; then
                echo -e "\e[1;31mError installing package 'huawei-lte-api'\e[0m"
                echo -e "\e[1;31mSetup Gagal | Mohon Coba Kembali\e[0m"
                exit  # Keluar dari skrip dengan status error
            fi
        else
            echo -e "\e[1;32mPackage 'huawei-lte-api' already installed\e[0m"
        fi
    else
        echo -e "\e[1;31mError: 'pip3' command not found\e[0m"
        echo -e "\e[1;31mSetup Gagal | Mohon Coba Kembali\e[0m"
        exit  # Keluar dari skrip dengan status error
    fi
    sleep 1
}

finish(){
    clear
    echo ""
    echo -e "\e[1;32m====================================\e[0m"
    echo -e "\e[1;32m========= INSTALL BERHASIL =========\e[0m"
    echo -e "\e[1;32m====================================\e[0m"
    echo ""
    echo -e "\e[1;33mSilahkan Cek Di Tab Modem Dan Pilih Rakitan Manager\e[0m"
    echo -e "\e[1;33mJika Tidak Ada Silahkan Clear Cache Kemudian Logout Dan Login Kembali\e[0m"
    echo -e "\e[1;33mAtau Membuka Manual Di Tab Baru : 192.168.1.1/rakitanmanager\e[0m"
    echo ""
    echo -e "\e[1;33mUlangi Instalasi ? Jika Ada Yang Gagal\e[0m"
    echo -e "\e[1;33m[Y] Untuk Mengulang Installasi\e[0m"
    echo -e "\e[1;33m[N] Untuk Menyelesaikan Script\e[0m"
    read -p "(y/n)? " yn
    case $yn in
        [Yy]* ) install_update; break;;
        [Nn]* ) exit;;
        * ) echo -e "\e[1;31mMohon Hanya Masukan 'y' atau 'n'.\e[0m";;
    esac
}

download_files()
{
    clear
    echo "Downloading files from repo..."
    rakitanmanager_api="https://api.github.com/repos/rtaserver/RakitanManager/releases"
    rakitanmanager_file="luci-app-rakitanmanager"
    if [ -f "$DIR/rakitanmanager.ipk" ]; then
        rm -f $DIR/rakitanmanager.ipk
    fi
    if [ $1 == "1" ]; then
        rakitanmanager_file_down="$(curl -s ${rakitanmanager_api} | grep "browser_download_url" | grep -oE "https.*${rakitanmanager_file}.*_21_02.ipk" | head -n 1)"
        wget -O $DIR/rakitanmanager.ipk ${rakitanmanager_file_down}
        opkg install $DIR/rakitanmanager.ipk --force-reinstall
        sleep 3
    fi
    if [ $1 == "2" ]; then
        rakitanmanager_file_down="$(curl -s ${rakitanmanager_api} | grep "browser_download_url" | grep -oE "https.*${rakitanmanager_file}.*_23_05.ipk" | head -n 1)"
        wget -O $DIR/rakitanmanager.ipk ${rakitanmanager_file_down}
        opkg install $DIR/rakitanmanager.ipk --force-reinstall
        sleep 3
    fi

    finish
}

echo ""
while true; do
    echo "============================================"
    echo "Install Beberapa Dependens yang di Butukan."
    echo ""
    echo -e "\e[1;36m[Y]\e[0m Untuk Install"
    echo -e "\e[1;36m[N]\e[0m Untuk Keluar Dari Script"
    echo "============================================"
    read -p "(y/n)? " yn
    case $yn in
        [Yy]* ) install_update; break;;
        [Nn]* ) exit;;
        * ) echo -e "\e[1;31mMohon Hanya Masukan 'y' atau 'n'.\e[0m";;
    esac
done

echo ""

while true; do
    echo "============================================"
    echo "Download Dan Install IPK RakitanManager."
    echo ""
    echo -e "\e[1;36m[1]\e[0m Untuk Versi OpenWrt 21.02 Ke Atas Kecuali 23.05"
    echo -e "\e[1;36m[2]\e[0m Untuk Versi OpenWrt 23.05 Ke Atas"
    echo -e "\e[1;36m[X]\e[0m Untuk Keluar Dari Script"
    echo "============================================"
    read -p "(1/2/x)? " version
    case $version in
        [1]* ) download_files "1"; break;;
        [2]* ) download_files "2"; break;;
        [Xx]* ) exit;;
        * ) echo -e "\e[1;31mMohon Hanya Masukan '1' '2' Atau 'X'.\e[0m";;
    esac
done