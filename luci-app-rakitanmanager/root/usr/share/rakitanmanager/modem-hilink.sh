#!/bin/bash
# Copyright 2024 RTA SERVER
# IP Hunter by ais sia
# Upload by Aryo Brokolly

log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

MODEM_IP="$1"
USERNAME="$2"
PASSWORD="$3"

clear

ipmod() {
    log "IP Address Modem Anda ${MODEM_IP}"
}

login() {
    pass="$PASSWORD"
    data=$(curl -s http://$MODEM_IP/api/webserver/SesTokInfo -H "Host: $MODEM_IP" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$MODEM_IP/html/home.html" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7")
    sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
    token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)
    check=$(curl -s http://$MODEM_IP/api/user/state-login -H "Host: $MODEM_IP" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$MODEM_IP/html/home.html" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
    state=$(echo $check | awk -F "<State>" '{print $2}' | awk -F "</State>" '{print $1}')
    type=$(echo $check | awk -F "<password_type>" '{print $2}' | awk -F "</password_type>" '{print $1}')
    if [ "$state" = "0" ]; then
        log "Activated Successfully"
    else
        if [ "$type" = "4" ]; then
            pass1=$(echo -n "$pass" | sha256sum | head -c 64 | base64 -w 0)
            pass1=$(echo -n "admin$pass1$token" | sha256sum | head -c 64 | base64 -w 0)
            pass1=$(echo -n "$pass1</Password><password_type>4</password_type>")
        else
            pass1=$(echo -n "$pass" | base64 -w 0)
            pass1=$(echo -n "$pass1</Password>")
        fi
        login=$(curl -s -D- -o /dev/null -X POST http://$MODEM_IP/api/user/login -H "Host: $MODEM_IP" -H "Connection: keep-alive" -H "Accept: */*" -H "Origin: http://$MODEM_IP" -H "X-Requested-With: XMLHttpRequest" -H "__RequestVerificationToken: $token" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -H "Referer: http://$MODEM_IP/html/home.html" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi" -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><request><Username>admin</Username><Password>$pass1</request>")
        scoki=$(echo "$login" | grep -i "Set-Cookie" | cut -d':' -f2 | cut -b 1-138)
        if [ "$scoki" ]; then
            log "Login Success"
        else
            log "Login Failed"
            exit
        fi
    fi
}

service() {
    case $1 in
        "00") log "Auto" ;;
        "03") log "4G Only" ;;
    esac
}

iphunter() {
    clear
    login
    clear
    data=$(curl -s http://$MODEM_IP/api/webserver/SesTokInfo -H "Host: $MODEM_IP" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$MODEM_IP/html/home.html" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $scoki")
    sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
    token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)
    grs=$(curl -s http://$MODEM_IP/api/net/net-mode -H "Host: $MODEM_IP" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$MODEM_IP/html/home.html" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi")
    srg=$(echo $grs | awk -F "<NetworkMode>" '{print $2}' | awk -F "</NetworkMode>" '{print $1}')
    log "Check Service : "; service $srg

    case $srg in
        "00")
            data=$(curl -s http://$MODEM_IP/api/webserver/SesTokInfo -H "Host: $MODEM_IP" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$MODEM_IP/html/home.html" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $scoki")
            sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
            token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)
            forgonly=$(curl -s -X POST http://$MODEM_IP/api/net/net-mode -H "Host: $MODEM_IP" -H "Connection: keep-alive" -H "Content-Length: 158" -H "Accept: */*" -H "Origin: http://$MODEM_IP" -H "X-Requested-With: XMLHttpRequest" -H "__RequestVerificationToken: $token" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -H "Referer: http://$MODEM_IP/html/home.html" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi" -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><response><NetworkMode>03</NetworkMode><NetworkBand>3FFFFFFF</NetworkBand><LTEBand>7FFFFFFFFFFFFFFF</LTEBand></response>")
            ;;
        "03")
            data=$(curl -s http://$MODEM_IP/api/webserver/SesTokInfo -H "Host: $MODEM_IP" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Referer: http://$MODEM_IP/html/home.html" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $scoki")
            sesi=$(echo "$data" | grep "SessionID=" | cut -b 10-147)
            token=$(echo "$data" | grep "TokInfo" | cut -b 10-41)
            forgonly=$(curl -s -X POST http://$MODEM_IP/api/net/net-mode -H "Host: $MODEM_IP" -H "Connection: keep-alive" -H "Content-Length: 158" -H "Accept: */*" -H "Origin: http://$MODEM_IP" -H "X-Requested-With: XMLHttpRequest" -H "__RequestVerificationToken: $token" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3626.119 Safari/537.36" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" -H "Referer: http://$MODEM_IP/html/home.html" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" -H "Cookie: $sesi" -d "<?xml version=\"1.0\" encoding=\"UTF-8\"?><response><NetworkMode>00</NetworkMode><NetworkBand>3FFFFFFF</NetworkBand><LTEBand>7FFFFFFFFFFFFFFF</LTEBand></response>")
            ;;
    esac

    clear
}

iphunter