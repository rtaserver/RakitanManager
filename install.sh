#!/bin/bash

clear

#===================
W='\e[1;37m' # Putih
R='\e[31;1m' # Merah
G='\e[32;1m' # Hijau
Y='\e[33;1m' # Kuning
DB='\e[34;1m' # Biru Gelap
P='\e[35;1m' # Ungu
LB='\e[36;1m' # Biru Terang
#=====================

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
    read -n 1 -s -r -p "${Y}Ketik Apapun Untuk Kembali Ke Menu${W}"
    bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/main/install.sh')"
}

install_upgrade()
{
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
    sleep 1
    clear
    echo "Downloading files from repo..."
    rakitanmanager_api="https://api.github.com/repos/rtaserver/RakitanManager/releases"
    rakitanmanager_file="luci-app-rakitanmanager"
    if [ -f "$DIR/rakitanmanager.ipk" ]; then
        rm -f $DIR/rakitanmanager.ipk
    fi
    rakitanmanager_file_down="$(curl -s ${rakitanmanager_api} | grep "browser_download_url" | grep -oE "https.*${rakitanmanager_file}.*.ipk" | head -n 1)"
    wget -O $DIR/rakitanmanager.ipk ${rakitanmanager_file_down}
    opkg install $DIR/rakitanmanager.ipk --force-reinstall
    sleep 3
    finish
}

uninstaller() {
	echo "Menghapus Rakitan Manager"
	opkg remove luci-app-rakitanmanager
	clear
	echo "Menghapus Rakitan Manager Selesai"
	read -n 1 -s -r -p "${Y}Ketik Apapun Untuk Kembali Ke Menu${W}"
	bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/main/install.sh')"
}

echo -e "${DB} =================================================="
echo -e "${R}          RAKITAN MANAGER AUTO INSTALLER           "
echo -e "${DB} =================================================="
echo -e "${R} Versi Terinstall:     "
echo -e "${R} Versi Terbaru:     "
echo -e "${DB} =================================================="
echo -e "${LB} DAFTAR MENU :                                     "
echo -e "${LB} [\e[36m1\e[0m${LB}] Install / Upgrade Rakitan Manager                        "
echo -e "${LB} [\e[36m2\e[0m${LB}] Uninstall Rakitan Manager                            "
echo -e "${DB} =================================================="
echo -e "${W}"
echo -e   ""
echo -e   " Ketik [ x ] Atau [ Ctrl+C ] Untuk Keluar Dari Script"
read -p " Pilih Menu :  "  opt
echo -e   ""

case $opt in
1) clear ;
echo -e Proses Install / Upgrade Akan Di Jalankan, mohon ditunggu
echo -e
sleep 3
clear
install_upgrade
 ;;

2) clear ;
echo -e Proses Uninstall Rakitan Manager, mohon ditunggu
echo -e
sleep 3
clear
uninstaller
 ;;

x) exit ;;
*) echo "Anda salah tekan " ; sleep 1 ; bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/main/install.sh')" ;;
esac
