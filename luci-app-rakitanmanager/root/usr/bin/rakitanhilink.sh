#!/bin/bash
#IP Hunter by ais sia
#Upload by Aryo Brokolly
clear


service(){
 case $1 in
  "00")
  echo -e "Auto"
  ;;
  "03")
  echo -e "4G Only"
  ;;
 esac
}
ipmodem=$(echo -e "$1")
pass=$(echo -e "$2")

ipmod(){
echo -e "IP Address Modem Anda ${ipmodem}"
}
login(){
data=$(curl -s http://$ipmodem/api/webserver/SesTokInfo -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7")
sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)

check=$(curl -s http://$ipmodem/api/user/state-login -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
state=$(echo $check|awk -F "<State>" '{print $2}'|awk -F "</State>" '{print $1}')
type=$(echo $check|awk -F "<password_type>" '{print $2}'|awk -F "</password_type>" '{print $1}')
if [ $state = "0" ]; then
  echo "Activated Successfully";
else
  if [ $type = "4" ]; then
    pass1=$(echo -n "$pass"|sha256sum|head -c 64|base64 -w 0)
    pass1=$(echo -n "admin$pass1$token"|sha256sum|head -c 64|base64 -w 0)
    pass1=$(echo -n "$pass1</Password><password_type>4</password_type>")
  else
    pass1=$(echo -n "$pass"|base64 -w 0)
    pass1=$(echo -n "$pass1</Password>")
  fi
  login=$(curl -s -D- -o/dev/null -X POST http://$ipmodem/api/user/login -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "Origin: http://$ipmodem" -H "X-Requested-With: XMLHttpRequest" -H "__RequestVerificationToken: $token" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi" -d '<?xml version="1.0" encoding="UTF-8"?><request><Username>admin</Username><Password>'$pass1'</request>')
  scoki=$(echo "$login"|grep [Ss]et-[Cc]ookie|cut -d':' -f2|cut -b 1-138)
  if [ $scoki ]; then
    echo -e "Login Success"
  else
    echo -e "Login Failed"
    exit
  fi
fi
}

iphunter(){
clear
ipmod
login
clear
 echo -e "---------------------------"
 # Ganti Mode Jaringan 4G Only or Auto
 data=$(curl -s http://$ipmodem/api/webserver/SesTokInfo -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $scoki")
 sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
 token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)
 grs=$(curl -s http://$ipmodem/api/net/net-mode -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 srg=$(echo $grs|awk -F "<NetworkMode>" '{print $2}'|awk -F "</NetworkMode>" '{print $1}')
 echo -n "Check Service : ";service $srg
 case $srg in
  "00")
  data=$(curl -s http://$ipmodem/api/webserver/SesTokInfo -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $scoki")
  sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
  token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)
  forgonly=$(curl -s -X POST http://$ipmodem/api/net/net-mode -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Content-Length: 158" -H "Accept: */*" -H "Origin: http://$ipmodem" -H "X-Requested-With: XMLHttpRequest" -H "__RequestVerificationToken: $token" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi" -d '<?xml version="1.0" encoding="UTF-8"?><response><NetworkMode>03</NetworkMode><NetworkBand>3FFFFFFF</NetworkBand><LTEBand>7FFFFFFFFFFFFFFF</LTEBand></response>')
  forg=$(echo $forgonly|awk -F "<response>" '{print $2}'|awk -F "</response>" '{print $1}')
  echo "Set 4G Only : $forg"
  sleep 1
  grs=$(curl -s http://$ipmodem/api/net/net-mode -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
  srg=$(echo $grs|awk -F "<NetworkMode>" '{print $2}'|awk -F "</NetworkMode>" '{print $1}')
  echo -n "Service : ";service $srg
  ;;
  "03")
  data=$(curl -s http://$ipmodem/api/webserver/SesTokInfo -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $scoki")
  sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
  token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)
  auto=$(curl -s -X POST http://$ipmodem/api/net/net-mode -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Content-Length: 158" -H "Accept: */*" -H "Origin: http://$ipmodem" -H "X-Requested-With: XMLHttpRequest" -H "__RequestVerificationToken: $token" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi" -d '<?xml version="1.0" encoding="UTF-8"?><response><NetworkMode>00</NetworkMode><NetworkBand>3FFFFFFF</NetworkBand><LTEBand>7FFFFFFFFFFFFFFF</LTEBand></response>')
  uto=$(echo $auto|awk -F "<response>" '{print $2}'|awk -F "</response>" '{print $1}')
  echo -e "Set Auto : $uto"
  sleep 1
  res=$(curl -s http://$ipmodem/api/net/net-mode -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
  ser=$(echo $res|awk -F "<NetworkMode>" '{print $2}'|awk -F "</NetworkMode>" '{print $1}')
  echo -n "Service : ";service $ser
  ;;
 esac
 sleep 1
 echo -e "---------------------------"
 oper=$(curl -s http://$ipmodem/api/net/current-plmn -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 operator=$(echo $oper|awk -F "<FullName>" '{print $2}'|awk -F "</FullName>" '{print $1}')
 echo -ne "Operator : $operator"
 par=$(curl -s http://$ipmodem/config/deviceinformation/add_param.xml -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 band=$(echo $par|awk -F "<band>" '{print $2}'|awk -F "</band>" '{print $1}')
 echo -e " | B$band"
 ip=$(curl -s http://$ipmodem/api/device/information -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 ipp=$(echo $ip|awk -F "<WanIPAddress>" '{print $2}'|awk -F "</WanIPAddress>" '{print $1}')
 tp=$(echo $ip|awk -F "<DeviceName>" '{print $2}'|awk -F "</DeviceName>" '{print $1}')
 echo -e "Device : $tp"
 echo -e "Wan IP : $ipp"
 echo -e "---------------------------"
}

myip(){
clear
ipmod
login
clear
 oper=$(curl -s http://$ipmodem/api/net/current-plmn -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 operator=$(echo $oper|awk -F "<FullName>" '{print $2}'|awk -F "</FullName>" '{print $1}')
 par=$(curl -s http://$ipmodem/config/deviceinformation/add_param.xml -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 band=$(echo $par|awk -F "<band>" '{print $2}'|awk -F "</band>" '{print $1}')
 ip=$(curl -s http://$ipmodem/api/device/information -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 ipp=$(echo $ip|awk -F "<WanIPAddress>" '{print $2}'|awk -F "</WanIPAddress>" '{print $1}')
 tp=$(echo $ip|awk -F "<DeviceName>" '{print $2}'|awk -F "</DeviceName>" '{print $1}')
 echo "$ipp"
}

case $3 in
 "iphunter")
 iphunter;exit
 ;;
 "myip")
 myip;exit
 ;;
esac
echo -e "\e[38;3m modem iphunter\e[0m \e[34;1m(IP Hunter)\e[0m"
echo -e "\e[38;3m modem myip\e[0m \e[34;1m(Show IP Wan)\e[0m"