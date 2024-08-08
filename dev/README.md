<h1 align="center">
  <br>RakitanManager<br>

</h1>

  <p align="center">
  <a target="_blank" href="https://github.com/rtaserver/RakitanManager/tree/v0.00.34-beta">
    <img src="https://img.shields.io/badge/source code-v0.00.34--beta-green.svg">
  </a>
  <a target="_blank" href="https://github.com/rtaserver/RakitanManager/releases/tag/v0.00.34-beta">
    <img src="https://img.shields.io/badge/New Release-v0.00.34--beta-orange.svg">
  </a>
  </p>

Installasi
---


Menggunakan Terminal OpenWrt / TTYD / PuTTY
```bash
# Copy Script Di Bawah Dan Paste Di Terminal
bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh')"
```

Manual Installasi
```
1. Download File IPK
2. Install Beberapa Paket Yang Di Butuhkan Di Menu Software
   Jangan Lupa Update List
   - modemmanager
   - python3-pip
   - jq
   - curl
   - adb
3. Install Paket Python di Terminal OpenWrt / TTYD / PuTTY
   - pip3 install requests
   - pip3 install huawei-lte-api
   Paste Satu Satu Di Atas Ke Terminal
4. Upload IPK Yang Sudah Di Download Ke Menu Software
   Upload Packages. Kemudian Upload Dan Install
5. Atau Upload IPK Ke Folder Root OpeWrt
   Kemudian Jalankan Perintah Ini Di Terminal
   - opkg install /luci-app-rakitanmanager_*.ipk --force-reinstall
```

lisensi
---


* [Apache License](https://github.com/rtaserver/RakitanManager/blob/main/LICENSE)
* pip3 [huawei-lte-api](https://github.com/Salamek/huawei-lte-api) by [Salamek](https://github.com/Salamek)
