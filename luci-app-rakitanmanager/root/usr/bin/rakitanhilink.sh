#!/bin/bash
#IP Hunter by ais sia
#Upload by Aryo Brokolly
clear
human_print(){
while read B dummy; do
  [ $B -lt 1024 ] && echo ${B} B && break
  KB=$(((B+512)/1024))
  [ $KB -lt 1024 ] && echo ${KB} KB && break
  MB=$(((KB+512)/1024))
  [ $MB -lt 1024 ] && echo ${MB} MB && break
  GB=$(((MB+512)/1024))
  [ $GB -lt 1024 ] && echo ${GB} GB && break
  echo $(((GB+512)/1024)) terabytes
done
}
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
network() {
case $1 in
  "0")
  echo -e 'No service'
  ;;
  "1")
  echo -e 'GSM (2G)'
  ;;
  "2")
  echo -e 'GPRS (2G)'
  ;;
  "3")
  echo -e 'EDGE (2G)'
  ;;
  "21")
  echo -e 'IS95A'
  ;;
  "22")
  echo -e 'IS95B'
  ;;
  "23")
  echo -e 'CDMA 1X'
  ;;
  "24")
  echo -e 'EVDO rev.0'
  ;;
  "25")
  echo -e 'EVDO rev.A'
  ;;
  "26")
  echo -e 'EVDO rev.B'
  ;;
  "27")
  echo -e 'HYBRID CDMA 1X'
  ;;
  "28")
  echo -e 'HYBRID EVDO rev.0'
  ;;
  "29")
  echo -e 'HYBRID EVDO rev.A'
  ;;
  "30")
  echo -e 'HYBRID EVDO rev.B'
  ;;
  "31")
  echo -e 'eHRPD rel.0'
  ;;
  "32")
  echo -e 'eHRPD rel.A'
  ;;
  "33")
  echo -e 'eHRPD rel.B'
  ;;
  "34")
  echo -e 'HYBRID eHRPD rel.0'
  ;;
  "35")
  echo -e 'HYBRID eHRPD rel.A'
  ;;
  "36")
  echo -e 'HYBRID eHRPD rel.B'
  ;;
  "41")
  echo -e 'UMTS (3G)'
  ;;
  "42")
  echo -e 'HSDPA (3G)'
  ;;
  "43")
  echo -e 'HSUPA (3G)'
  ;;
  "44")
  echo -e 'HSPA (3G)'
  ;;
  "45")
  echo -e 'HSPA+ (3.5G)'
  ;;
  "46")
  echo -e 'DC-HSPA+ (3.5G)'
  ;;
  "61")
  echo -e 'TD-SCDMA (3G)'
  ;;
  "62")
  echo -e 'TD-HSDPA (3G)'
  ;;
  "63")
  echo -e 'TD-HSUPA (3G)'
  ;;
  "64")
  echo -e 'TD-HSPA (3G)'
  ;;
  "65")
  echo -e 'TD-HSPA+ (3.5G)'
  ;;
  "81")
  echo -e '802.16E'
  ;;
  "101")
  echo -e 'LTE (4G)'
  ;;
  "1011")
  echo -e 'LTE CA (4G+)'
  ;;
  "111")
  echo -e 'NR (5G)'
  ;;
esac
}
ipmod(){
ipmodem=$(route -n|awk '{print $2}'|grep 192.168|head -n1)
echo -e "IP Address Modem Anda ${ipmodem}"
}
login(){
pass=$(echo -e "admin123")
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
info(){
 clear
 ipmod $1
 login
 clear
 echo -e "---------------------------"
 data=$(curl -s http://$ipmodem/api/webserver/SesTokInfo -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $scoki")
 sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
 token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)
 oper=$(curl -s http://$ipmodem/api/net/current-plmn -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 operator=$(echo $oper|awk -F "<FullName>" '{print $2}'|awk -F "</FullName>" '{print $1}')
 echo -e "Operator : $operator"
 ip=$(curl -s http://$ipmodem/api/device/information -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 ipp=$(echo $ip|awk -F "<WanIPAddress>" '{print $2}'|awk -F "</WanIPAddress>" '{print $1}')
 tp=$(echo $ip|awk -F "<DeviceName>" '{print $2}'|awk -F "</DeviceName>" '{print $1}')
 echo -e "Device : $tp"
 echo -e "Wan IP : $ipp"
 dns=$(curl -s http://$ipmodem/api/monitoring/status -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 dns1=$(echo $dns|awk -F "<PrimaryDns>" '{print $2}'|awk -F "</PrimaryDns>" '{print $1}')
 dns2=$(echo $dns|awk -F "<SecondaryDns>" '{print $2}'|awk -F "</SecondaryDns>" '{print $1}')
 net=$(echo $dns|awk -F "<CurrentNetworkTypeEx>" '{print $2}'|awk -F "</CurrentNetworkTypeEx>" '{print $1}')
 echo -e "DNS 1 : $dns1"
 echo -e "DNS 2 : $dns2"
 echo -ne "Network : ";network $net
 td=$(curl -s http://$ipmodem/api/monitoring/traffic-statistics -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 tup=$(echo $td|awk -F "<TotalUpload>" '{print $2}'|awk -F "</TotalUpload>" '{print $1}'|human_print)
 tdd=$(echo $td|awk -F "<TotalDownload>" '{print $2}'|awk -F "</TotalDownload>" '{print $1}'|human_print)
 echo -e "Total Upload : $tup"
 echo -e "Total Download : $tdd"
 echo -e "---------------------------"
 par=$(curl -s http://$ipmodem/config/deviceinformation/add_param.xml -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 band=$(echo $par|awk -F "<band>" '{print $2}'|awk -F "</band>" '{print $1}')
 dlfreq=$(echo $par|awk -F "<freq1>" '{print $2}'|awk -F "</freq1>" '{print $1}')
 upfreq=$(echo $par|awk -F "<freq2>" '{print $2}'|awk -F "</freq2>" '{print $1}')
 echo -e "Band : $band"
 dvi=$(curl -s http://$ipmodem/api/device/signal -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
 pci=$(echo $dvi|awk -F "<pci>" '{print $2}'|awk -F "</pci>" '{print $1}')
 cellid=$(echo $dvi|awk -F "<cell_id>" '{print $2}'|awk -F "</cell_id>" '{print $1}')
 echo -e "PCI : $pci"
 echo -e "Cell ID : $cellid"
 echo -e "DL Frequency : $dlfreq"
 echo -e "UP Frequency : $upfreq"
 echo -e "---------------------------"
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
restart() {
 clear
 ipmod
 login
 clear
 # cookie
 data=$(curl -s http://$ipmodem/api/webserver/SesTokInfo -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $scoki")
 sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
 token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)
 # restart modem
 res=$(curl -s -X POST http://$ipmodem/api/device/control -H "Host: $ipmodem" -H "Connection: keep-alive" -H "Accept: */*" -H "Origin: http://$ipmodem" -H "X-Requested-With: XMLHttpRequest" -H "__RequestVerificationToken: $token" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -H "Referer: http://$ipmodem/html/home.html" -H "Accept-Encoding: gzib, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi" -d '<?xml version="1.0" encoding="UTF-8"?><request><Control>1</Control></request>')
 ress=$(echo $res|awk -F "<response>" '{print $2}'|awk -F "</response>" '{print $1}')
 if [ "$ress" = "OK" ]; then
   echo -e "Rebooting..."
 else
   echo -e "Reboot Error"
 fi
}
lock() {
clear
ipmod
clear
echo -e "---------------------------"
echo -e "Connecting to $ipmodem"
sleep 1
adb kill-server > /dev/null 2>&1
adb connect "$ipmodem" > /dev/null 2>&1
sleep 2
cek=$(adb devices -l|grep $ipmodem:5555|awk -F ":" '{print $1}')
if [ "$cek" = "$ipmodem" ]; then
  echo -e "Device connected!"
  sleep 1
else
  echo -e "Device not connected!"
  sleep 1
  echo -e "Press enter to back in menu..."
  read
  lock
fi
echo -e "---------------------------"
read -p "BAND : " band
read -p "PCI : " pci
read -p "DL Frequency : " dlfreq
echo -e "---------------------------"
bandx=$(printf "%X" $band)
if [ "${#bandx}" = "8" ]; then
  bandx="$bandx"
elif [ "${#bandx}" = "7" ]; then
  bandx="0$bandx"
elif [ "${#bandx}" = "6" ]; then
  bandx="00$bandx"
elif [ "${#bandx}" = "5" ]; then
  bandx="000$bandx"
elif [ "${#bandx}" = "4" ]; then
  bandx="0000$bandx"
elif [ "${#bandx}" = "3" ]; then
  bandx="00000$bandx"
elif [ "${#bandx}" = "2" ]; then
  bandx="000000$bandx"
elif [ "${#bandx}" = "1" ]; then
  bandx="0000000$bandx"
fi
bandx1=$(echo $bandx|cut -b 7-8)
pcix=$(printf "%X" $pci)
if [ "${#pcix}" = "8" ]; then
  pcix="$pcix"
elif [ "${#pcix}" = "7" ]; then
  pcix="0$pcix"
elif [ "${#pcix}" = "6" ]; then
  pcix="00$pcix"
elif [ "${#pcix}" = "5" ]; then
  pcix="000$pcix"
elif [ "${#pcix}" = "4" ]; then
  pcix="0000$pcix"
elif [ "${#pcix}" = "3" ]; then
  pcix="00000$pcix"
elif [ "${#pcix}" = "2" ]; then
  pcix="000000$pcix"
elif [ "${#pcix}" = "1" ]; then
  pcix="0000000$pcix"
fi
pcix1=$(echo $pcix|cut -b 7-8)
pcix2=$(echo $pcix|cut -b 5-6)
dlfreqx=$(printf "%X" $dlfreq)
if [ "${#dlfreqx}" = "8" ]; then
  dlfreqx="$dlfreqx"
elif [ "${#dlfreqx}" = "7" ]; then
  dlfreqx="0$dlfreqx"
elif [ "${#dlfreqx}" = "6" ]; then
  dlfreqx="00$dlfreqx"
elif [ "${#dlfreqx}" = "5" ]; then
  dlfreqx="000$dlfreqx"
elif [ "${#dlfreqx}" = "4" ]; then
  dlfreqx="0000$dlfreqx"
elif [ "${#dlfreqx}" = "3" ]; then
  dlfreqx="00000$dlfreqx"
elif [ "${#dlfreqx}" = "2" ]; then
  dlfreqx="000000$dlfreqx"
elif [ "${#dlfreqx}" = "1" ]; then
  dlfreqx="0000000$dlfreqx"
fi
dlfreqx1=$(echo $dlfreqx|cut -b 7-8)
dlfreqx2=$(echo $dlfreqx|cut -b 5-6)
adb push balong-nvtool / > /dev/null 2>&1
adb shell chmod 777 /balong-nvtool > /dev/null 2>&1
adb shell "/balong-nvtool -m 53810:03:00:00:00:$bandx1:01:$bandx1:01:$pcix1:$pcix2:$dlfreqx1:$dlfreqx2:00:00:00:00 > /dev/null 2>&1"
echo -e "Finish Locking Cell ID..."
sleep 1
echo -e "Rebooting..."
screen -dmS res adb shell "atc AT^RESET > /dev/null 2>&1"
sleep 2
kill $(screen -list|grep res|awk -F '[.]' '{print $1}') > /dev/null 2>&1
adb kill-server > /dev/null 2>&1
echo -e "Closing..."
echo -e "---------------------------"
}
unlock() {
clear
ipmod
clear
echo -e "---------------------------"
echo -e "Connecting to $ipmodem"
sleep 2
adb kill-server > /dev/null 2>&1
adb connect "$ipmodem" > /dev/null 2>&1
sleep 2
cek=$(adb devices -l|grep $ipmodem:5555|awk -F ":" '{print $1}')
if [ "$cek" = "$ipmodem" ]; then
  echo -e "Device connected!"
  sleep 2
else
  echo -e "Device not connected!"
  sleep 2
  echo -e "Press enter to back in menu..."
  read
  unlock
fi
echo -e "---------------------------"
adb push balong-nvtool / > /dev/null 2>&1
adb shell chmod 777 /balong-nvtool > /dev/null 2>&1
adb shell "/balong-nvtool -m 53810:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00:00 > /dev/null 2>&1"
echo -e "Finish Unlocking Cell ID..."
sleep 2
echo -e "Rebooting..."
screen -dmS res adb shell "atc AT^RESET > /dev/null 2>&1"
sleep 2
kill $(screen -list|grep res|awk -F '[.]' '{print $1}') > /dev/null 2>&1
adb kill-server > /dev/null 2>&1
echo -e "Closing..."
echo -e "---------------------------"
}
if [ $(opkg list-installed|grep adb|awk 'NR==1'|awk '{print $1}') != "adb" ]; then
  opkg update && opkg install adb
  clear
fi
if [ -f $(opkg list-installed|grep screen|awk '{print $1}') ]; then
  opkg update && opkg install screen
  clear
fi
case $1 in
 "info")
 info $2;exit
 ;;
 "iphunter")
 iphunter;exit
 ;;
 "reboot")
 restart;exit
 ;;
 "lock")
 lock;exit
 ;;
 "unlock")
 unlock;exit
 ;;
esac
echo -e "\e[38;3m modem iphunter\e[0m \e[34;1m(IP Hunter)\e[0m"
echo -e "\e[38;3m modem info\e[0m \e[34;1m(Device Information)\e[0m"
echo -e "\e[38;3m modem reboot\e[0m \e[34;1m(Restart Modem)\e[0m"
echo -e "\e[38;3m modem lock\e[0m \e[34;1m(Lock Cell ID)\e[0m"
echo -e "\e[38;3m modem unlock\e[0m \e[34;1m(Unlock Cell ID)\e[0m"