#!/bin/sh
#Replace with IP or device ID, support multiple android adb device id, writing sample: "id0001 id0002" quoted with double quotes
if [ -z "$1" ]; then
	echo "ADBID is unset, using default..."
	ADBID=$(adb devices | grep 'device' | grep -v 'List of' | awk {'print $1'}) # Default device_id if $1 unset
else
	ADBID="$1"
fi

for IPX in ${ADBID}
do
	echo "Connecting to ${IPX} device..." 
    echo "Airplane mode is at DISABLED state, will be enabled in 3 secs..."
    if [[ "$(adb -s ${IPX} shell settings get global airplane_mode_on)" == "0" ]]; then
    	adb -s "$IPX" settings put global airplane_mode_on 1 &>/dev/null
    	adb -s "$IPX" am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true &>/dev/null
    fi
    if [[ "$(adb -s ${IPX} shell cmd connectivity airplane-mode)" == "disabled" ]]; then
    	adb -s "$IPX" shell cmd connectivity airplane-mode enable &>/dev/null
    fi
    sleep "3" &>/dev/null

    echo "Disabling airplane mode to get new IP and refreshed network..."
    if [[  "$(adb -s ${IPX} shell settings get global airplane_mode_on)" == "1" ]]; then
    	adb -s "$IPX" settings put global airplane_mode_on 0 &>/dev/null
    	adb -s "$IPX" am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false &>/dev/null
    fi
    if [[ "$(adb -s ${IPX} shell cmd connectivity airplane-mode)" == "enabled" ]]; then
    	adb -s "$IPX" shell cmd connectivity airplane-mode disable &>/dev/null
    fi
    echo "ID [${IPX}] : Network refreshed done...!!"
done
