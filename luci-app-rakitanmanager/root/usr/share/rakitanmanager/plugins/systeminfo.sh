#!/bin/sh

. /usr/share/libubox/jshn.sh



human_readable() { # <Number of bytes>
	if [ $1 -gt 0 ]; then
		printf "$(awk -v n=$1 'BEGIN{for(i=split("B KB MB GB TB PB",suffix);s<1;i--)s=n/(2**(10*i));printf (int(s)==s)?"%.0f%s":"%.1f%s",s,suffix[i+2]}' 2>/dev/null)"
	else
		printf "0B"
	fi
}

device_rx_tx() { # <Device>
	local RXTX=$(awk -v Device=$1 '$1==Device ":"{printf "%.0f\t%.0f",$2,$10}' /proc/net/dev 2>/dev/null)
	[ "$RXTX" != "" ] && printf "\nRx/Tx: $RXTXColor$(human_readable $(echo "$RXTX" | cut -f 1))$NormalColor/$RXTXColor$(human_readable $(echo "$RXTX" | cut -f 2))$NormalColor"
}

uptime_str() { # <Time in Seconds>
	local Uptime=$1
	if [ $Uptime -gt 0 ]; then
		local Days=$(expr $Uptime / 60 / 60 / 24)
		local Hours=$(expr $Uptime / 60 / 60 % 24)
		local Minutes=$(expr $Uptime / 60 % 60)
		local Seconds=$(expr $Uptime % 60)
		if [ $Days -gt 0 ]; then
			Days=$(printf "%dd " $Days)
		else
			Days=""
		fi 2>/dev/null
		printf "$Days%02d:%02d:%02d" $Hours $Minutes $Seconds
	fi
}

print_line() { # <String to Print>, [[<String to Print>] ...]
	local Line="$@"
	if [ "$HTML" == "1" ]; then
		printf "$Line\n" 2>/dev/null
	else
		printf "\r$Line\n" 2>/dev/null
	fi
}

suhu_xc() {
    local suhumhz=$(/usr/bin/cpustat 2>/dev/null)
    local temp=$(echo $suhumhz | awk '{print $4}' | cut -d '.' -f1) # Mengambil bagian bilangan bulat
    if [[ $temp -lt 40 ]]; then
        printf "Speed / Temp $suhumhz (❄️  Temperature: Cool)"
    elif [[ $temp -lt 55 ]]; then
        printf "Speed / Temp $suhumhz (🌡️  Temperature: Normal)"
    else
        printf "Speed / Temp $suhumhz (🔥  Temperature: Hot)"
    fi
}

catatan() {
	printf "Mod: XppaiWRT x PHPTeleBotWrt"
}

print_machine() {
	local Machine=""
	local HostName=$(uci -q get system.@system[0].hostname)
	local KernelInfo=$(uname -a)
	if [ -e /tmp/sysinfo/model ]; then
		Machine=$(cat /tmp/sysinfo/model 2>/dev/null)
	elif [ -e /proc/cpuinfo ]; then
		Machine=$(awk 'BEGIN{FS="[ \t]+:[ \t]";OFS=""}/machine/{Machine=$2}/Hardware/{Hardware=$2}END{print Machine,(Machine!="" && Hardware!="")?" ":"",Hardware}' /proc/cpuinfo 2>/dev/null)
	fi
	print_line "Hostname: $HostName\nMachine: $Machine\nKernel: $KernelInfo"
}

print_times() {
	local SysUptime=$(cut -d. -f1 /proc/uptime)
	local Uptime=$(uptime_str $SysUptime)
	local Now=$(date +'%Y-%m-%d %H:%M:%S')
	print_line 	"Uptime: $ValueColor$Uptime$NormalColor,"\
				"Now: $ValueColor$Now$NormalColor"
}

print_loadavg() {
	print_line "
System load:"\
				"$ValueColor"$(cat /proc/loadavg | cut -d " " -f 1 2>/dev/null)"$NormalColor,"\
				"$ValueColor"$(cat /proc/loadavg | cut -d " " -f 2 2>/dev/null)"$NormalColor,"\
				"$ValueColor"$(cat /proc/loadavg | cut -d " " -f 3 2>/dev/null)"$NormalColor"
}

print_fs_summary() { # <Mount point> <Label>
	local DeviceInfo=$(df -k $1 2>/dev/null| awk 'BEGIN{Total=0;Free=0} NR>1 && $6=="'$1'"{Total=$2;Free=$4}END{Used=Total-Free;printf"%.0f\t%.0f\t%.1f\t%.0f",Total*1024,Used*1024,(Total>0)?((Used/Total)*100):0,Free*1024}' 2>/dev/null)
	local Total=$(echo "$DeviceInfo" | cut -f 1)
	local Used=$(echo "$DeviceInfo" | cut -f 2)
	local UsedPercent=$(echo "$DeviceInfo" | cut -f 3)
	local Free=$(echo "$DeviceInfo" | cut -f 4)
	[ "$Total" -gt 0 ] && print_line "$2:"\
				"total: $ValueColor$(human_readable $Total)$NormalColor,"\
				"used: $ValueColor$(human_readable $Used)$NormalColor, $ValueColor$UsedPercent$NormalColor%%,"\
				"free: $ValueColor$(human_readable $Free)$NormalColor"
}

print_disk() {
	local Overlay=$(awk '$3=="overlayfs"{print $2}' /proc/mounts 2>/dev/null)
	if [ "$Overlay" != "" ]; then
		print_fs_summary /overlay "Flash"
	fi
	if [ "$Overlay" == "" ] || [ "$Overlay" != "/" ]; then
		print_fs_summary / "RootFS"
	fi
}

print_memory() {
	local Memory=$(awk 'BEGIN{Total=0;Free=0}$1~/^MemTotal:/{Total=$2}$1~/^MemFree:|^Buffers:|^Cached:/{Free+=$2}END{Used=Total-Free;printf"%.0f\t%.0f\t%.1f\t%.0f",Total*1024,Used*1024,(Total>0)?((Used/Total)*100):0,Free*1024}' /proc/meminfo 2>/dev/null)
	local Total=$(echo "$Memory" | cut -f 1)
	local Used=$(echo "$Memory" | cut -f 2)
	local UsedPercent=$(echo "$Memory" | cut -f 3)
	local Free=$(echo "$Memory" | cut -f 4)
	print_line "Memory:"\
				"total: $ValueColor$(human_readable $Total)$NormalColor,"\
				"used: $ValueColor$(human_readable $Used)$NormalColor, $ValueColor$UsedPercent$NormalColor%%,"\
				"free: $ValueColor$(human_readable $Free)$NormalColor"
}

print_swap() {
	local Swap=$(awk 'BEGIN{Total=0;Free=0}$1~/^SwapTotal:/{Total=$2}$1~/^SwapFree:/{Free=$2}END{Used=Total-Free;printf"%.0f\t%.0f\t%.1f\t%.0f",Total*1024,Used*1024,(Total>0)?((Used/Total)*100):0,Free*1024}' /proc/meminfo 2>/dev/null)
	local Total=$(echo "$Swap" | cut -f 1)
	local Used=$(echo "$Swap" | cut -f 2)
	local UsedPercent=$(echo "$Swap" | cut -f 3)
	local Free=$(echo "$Swap" | cut -f 4)
	[ "$Total" -gt 0 ] && print_line "Swap:"\
				"total: $ValueColor$(human_readable $Total)$NormalColor,"\
				"used: $ValueColor$(human_readable $Used)$NormalColor, $ValueColor$UsedPercent$NormalColor%%,"\
				"free: $ValueColor$(human_readable $Free)$NormalColor"
}

print_wan() {
	local Zone
	local Device
	for Zone in $(uci -q show firewall | grep .masq= | cut -f2 -d.); do
		if [ "$(uci -q get firewall.$Zone.masq)" == "1" ]; then
			for Device in $(uci -q get firewall.$Zone.network); do
				local Status="$(ubus call network.interface.$Device status 2>/dev/null)"
				if [ "$Status" != "" ]; then
					local State=""
					local Iface=""
					local Uptime=""
					local IP4=""
					local IP6=""
					local Subnet4=""
					local Subnet6=""
					local Gateway4=""
					local Gateway6=""
					local DNS=""
					local Protocol=""
					json_load "${Status:-{}}"
					json_get_var State up
					json_get_var Uptime uptime
					json_get_var Iface l3_device
					json_get_var Protocol proto
					if json_get_type Status ipv4_address && [ "$Status" = array ]; then
						json_select ipv4_address
						json_get_type Status 1
						if [ "$Status" = object ]; then
							json_select 1
							json_get_var IP4 address
							json_get_var Subnet4 mask
							[ "$IP4" != "" ] && [ "$Subnet4" != "" ] && IP4="$IP4/$Subnet4"
						fi
					fi
					json_select
					if json_get_type Status ipv6_address && [ "$Status" = array ]; then
						json_select ipv6_address
						json_get_type Status 1
						if [ "$Status" = object ]; then
							json_select 1
							json_get_var IP6 address
							json_get_var Subnet6 mask
							[ "$IP6" != "" ] && [ "$Subnet6" != "" ] && IP6="$IP6/$Subnet6"
						fi
					fi
					json_select
					if json_get_type Status route && [ "$Status" = array ]; then
						json_select route
						local Index="1"
						while json_get_type Status $Index && [ "$Status" = object ]; do
							json_select "$((Index++))"
							json_get_var Status target
							case "$Status" in
								0.0.0.0)
									json_get_var Gateway4 nexthop;;
								::)
									json_get_var Gateway6 nexthop;;
							esac
							json_select ".."
						done
					fi
					json_select
					if json_get_type Status dns_server && [ "$Status" = array ]; then
						json_select dns_server
						local Index="1"
						while json_get_type Status $Index && [ "$Status" = string ]; do
							json_get_var Status "$((Index++))"
							DNS="${DNS:+$DNS }$Status"
						done
					fi
					if [ "$State" == "1" ]; then
						[ "$IP4" != "" ] && print_line 	"WAN: $AddrColor$IP4$NormalColor($Iface),"\
														"\nGateway: $AddrColor${Gateway4:-n/a}$NormalColor"
						[ "$IP6" != "" ] && print_line	"WAN: $AddrColor$IP6$NormalColor($Iface),"\
														"\nGateway: $AddrColor${Gateway6:-n/a}$NormalColor"
						print_line	"Proto: $ValueColor${Protocol:-n/a}$NormalColor,"\
									"Uptime: $ValueColor$(uptime_str $Uptime)$NormalColor$(device_rx_tx $Iface)"
						[ "$DNS" != "" ] && print_line "DNS: $AddrColor$DNS$NormalColor"
					fi
				fi
			done
		fi
	done
}

print_lan() {
	local Zone
	local Device
	for Zone in $(uci -q show firewall | grep []]=zone | cut -f2 -d. | cut -f1 -d=); do
		if [ "$(uci -q get firewall.$Zone.masq)" != "1" ]; then
			for Device in $(uci -q get firewall.$Zone.network); do
				local Status="$(ubus call network.interface.$Device status 2>/dev/null)"
				if [ "$Status" != "" ]; then
					local State=""
					local Iface=""
					local IP4=""
					local IP6=""
					local Subnet4=""
					local Subnet6=""
					json_load "${Status:-{}}"
					json_get_var State up
					json_get_var Iface device
					if json_get_type Status ipv4_address && [ "$Status" = array ]; then
						json_select ipv4_address
						json_get_type Status 1
						if [ "$Status" = object ]; then
							json_select 1
							json_get_var IP4 address
							json_get_var Subnet4 mask
							[ "$IP4" != "" ] && [ "$Subnet4" != "" ] && IP4="$IP4/$Subnet4"
						fi
					fi
					json_select
					if json_get_type Status ipv6_address && [ "$Status" = array ]; then
						json_select ipv6_address
						json_get_type Status 1
						if [ "$Status" = object ]; then
							json_select 1
							json_get_var IP6 address
							json_get_var Subnet6 mask
							[ "$IP6" != "" ] && [ "$Subnet6" != "" ] && IP6="$IP6/$Subnet6"
						fi
					fi
					local DHCPConfig=$(uci -q show dhcp | grep .interface=$Device | cut -d. -f2)
					if [ "$DHCPConfig" != "" ] && [ "$(uci -q get dhcp.$DHCPConfig.ignore)" != "1" ]; then
						local DHCPStart=$(uci -q get dhcp.$DHCPConfig.start)
						local DHCPLimit=$(uci -q get dhcp.$DHCPConfig.limit)
						[ "$DHCPStart" != "" ] && [ "$DHCPLimit" != "" ] && DHCP="$(echo $IP4 | cut -d. -f1-3).$DHCPStart-$(expr $DHCPStart + $DHCPLimit - 1)"
					fi
					[ "$IP4" != "" ] && print_line "LAN: $AddrColor$IP4$NormalColor($Iface), DHCP: $AddrColor${DHCP:-n/a}$NormalColor"
					[ "$IP6" != "" ] && print_line "LAN: $AddrColor$IP6$NormalColor($Iface)"
				fi
			done
		fi
	done
}

print_wlan() {
	local Iface
	for Iface in $(uci -q show wireless | grep device=radio | cut -f2 -d.); do
		local Device=$(uci -q get wireless.$Iface.device)
		local SSID=$(uci -q get wireless.$Iface.ssid)
		local IfaceDisabled=$(uci -q get wireless.$Iface.disabled)
		local DeviceDisabled=$(uci -q get wireless.$Device.disabled)
		if [ -n "$SSID" ] && [ "$IfaceDisabled" != "1" ] && [ "$DeviceDisabled" != "1" ]; then
			local Mode=$(uci -q -P /var/state get wireless.$Iface.mode)
			local Channel=$(uci -q get wireless.$Device.channel)
			local RadioIface=$(uci -q -P /var/state get wireless.$Iface.ifname)
			local Connection="Down"
			if [ -n "$RadioIface" ]; then
				if [ "$Mode" == "ap" ]; then
					Connection="$(iw dev $RadioIface station dump | grep Station | wc -l 2>/dev/null)"
				else
					Connection="$(iw dev $RadioIface link | awk 'BEGIN{FS=": ";Signal="";Bitrate=""} $1~/signal/ {Signal=$2} $1~/tx bitrate/ {Bitrate=$2}END{print Signal" "Bitrate}' 2>/dev/null)"
				fi
			fi
			if [ "$Mode" == "ap" ]; then
				print_line	"WLAN: $ValueColor$SSID$NormalColor($Mode),"\
							"ch: $ValueColor${Channel:-n/a}$NormalColor,"\
							"conn: $ValueColor$Connection$NormalColor$(device_rx_tx $RadioIface)"
			else
				print_line	"WLAN: $ValueColor$SSID$NormalColor($Mode),"\
							"ch: $ValueColor${Channel:-n/a}$NormalColor"
				print_line	"conn: $ValueColor$Connection$NormalColor$(device_rx_tx $RadioIface)"
			fi
		fi
	done
}

print_vpn() {
	local VPN
	for VPN in $(uci -q show openvpn | grep .ca= | cut -f2 -d.); do
		local Device=$(uci -q get openvpn.$VPN.dev)
		local Enabled=$(uci -q get openvpn.$VPN.enabled)
		if [ "$Enabled" == "1" ] || [ "$Enabled" == "" ]; then
			local Mode=$(uci -q get openvpn.$VPN.mode)
			local Connection="n/a"
			if [ "$Mode" == "server" ]; then
				Mode="$ValueColor$VPN$NormalColor(svr):$(uci -q get openvpn.$VPN.port)"
				Status=$(uci -q get openvpn.$VPN.status)
				Connection=$(awk 'BEGIN{FS=",";c=0;l=0}{if($1=="Common Name")l=1;else if($1=="ROUTING TABLE")exit;else if (l==1) c=c+1}END{print c}' $Status 2>/dev/null)
			else
				Mode="$ValueColor$VPN$NormalColor(cli)"
				Connection="Down"
				ifconfig $Device &>/dev/null && Connection="Up"
			fi
			print_line	"VPN: $Mode,"\
						"conn: $ValueColor$Connection$NormalColor$(device_rx_tx $Device)"
		fi
	done
}



print_machine
print_times
suhu_xc
print_loadavg
print_disk
print_memory
echo -e "\n\n"
print_swap
print_wan
print_lan
print_wlan
print_vpn
echo -e "\n\n"
catatan

exit 0
# Done.
