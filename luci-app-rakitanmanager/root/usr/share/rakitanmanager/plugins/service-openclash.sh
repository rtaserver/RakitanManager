#!/bin/sh
#xwrt

op_version=$(opkg status luci-app-openclash 2>/dev/null |grep 'Version' | awk '{print$2}')
core_version=$(/etc/openclash/core/clash -v 2>/dev/null |awk -F ' ' '{print $2}' 2>/dev/null)
core_tun_version=$(/etc/openclash/core/clash_tun -v 2>/dev/null |awk -F ' ' '{print $2}' 2>/dev/null)
core_meta_version=$(/etc/openclash/core/clash_meta -v 2>/dev/null |awk -F ' ' '{print $3}' 2>/dev/null)
core_type=$(uci -q get openclash.config.core_version)
cpu_model=$(opkg status libc 2>/dev/null |grep 'Architecture' |awk -F ': ' '{print $2}' 2>/dev/null)
proxy_mode=$(uci -q get openclash.config.proxy_mode)
LOGTIME=$(echo $(date "+%Y-%m-%d %H:%M:%S"))
C_CORE_TYPE=$(uci -q get openclash.config.core_type)
cfg_yaml=$(ls /etc/openclash/config/ | grep -E '.yaml')
banner=$(cat src/plugins/banner)
printf "OpenClash   : $op_version
Core Tun    : $core_tun_version
Core Meta   : $core_meta_version
CPU Model   : $cpu_model
Proxy Mode  : $proxy_mode
Core Type   : $C_CORE_TYPE
Core        : $core_version
Config List :
$cfg_yaml
LogTime     : $LOGTIME"
