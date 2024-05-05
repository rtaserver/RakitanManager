#!/bin/sh
#Replace with IP or device ID, support multiple android adb device id, writing sample: "id0001 id0002" quoted with double quotes
if [ -z "$1" ]; then
	echo -e "ADBID is unset, using default..."
	ADBID=$(adb devices | grep 'device' | grep -v 'List of' | awk {'print $1'}) # Default device_id if $1 unset
else
	ADBID="$1"
fi

#Delay reenabling network, default is 3
if [ -z "$2" ]; then
	echo -e "DELAY is unset, using default..."
	DS="3"
else
	DS="$2"
fi

#Ping checker, default is 8.8.8.8
if [ -z "$3" ]; then
	echo -e "PINGCHECKER is unset, using default..."
	PINGCK="8.8.8.8"
else
	PINGCK="$3"
fi

#Ping checker count, default is 10
if [ -z "$4" ]; then
	echo -e "PINGCOUNT is unset, using default..."
	PINGCT="10"
else
	PINGCT="$4"
fi

for IPX in ${ADBID}
do
    #Ping checker system
	echo -e "Checking connection from device [${IPX}] to [${PINGCK}] with ping count [${PINGCT}] times...."
	logger "helminetlog:: Checking connection from device [${IPX}] to [${PINGCK}] with ping count [${PINGCT}] times...."
	httping -c ${PINGCT} ${PINGCK} > /tmp/anuping
	if grep -q "100.00% failed" /tmp/anuping; then
		echo -e "Network unavailable, restarting phone modem...."
		logger "helminetlog:: Network unavailable, restarting phone modem...."
	else
        #Force refresh network?
        if [ "$5" == "force" ]; then
        	echo -e "Network is available but Force refresh is set, restarting phone modem..."
        	logger "helminetlog:: Network is available but Force refresh is set, restarting phone modem..."
        else
        	echo -e "Network is available but Force refresh is unset, leaving phone modem like default..."
        	logger "helminetlog:: Network is available but Force refresh is unset, leaving phone modem like default..."
	        exit 0
        fi
	fi
	
    #Ping checker system
	echo -e "Connecting to ${IPX} device..." 
    echo -e "Airplane mode is at DISABLED state, will be enabled in ${DS} secs..."
    if [[ "$(adb -s ${IPX} shell settings get global airplane_mode_on)" == "0" ]]; then
    	adb -s "$IPX" settings put global airplane_mode_on 1 &>/dev/null
    	adb -s "$IPX" am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true &>/dev/null
    fi
    if [[ "$(adb -s ${IPX} shell cmd connectivity airplane-mode)" == "disabled" ]]; then
    	adb -s "$IPX" shell cmd connectivity airplane-mode enable &>/dev/null
    fi
    sleep "${DS}" &>/dev/null

    echo "Disabling airplane mode to get new IP and refreshed network..."
    if [[  "$(adb -s ${IPX} shell settings get global airplane_mode_on)" == "1" ]]; then
    	adb -s "$IPX" settings put global airplane_mode_on 0 &>/dev/null
    	adb -s "$IPX" am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false &>/dev/null
    fi
    if [[ "$(adb -s ${IPX} shell cmd connectivity airplane-mode)" == "enabled" ]]; then
    	adb -s "$IPX" shell cmd connectivity airplane-mode disable &>/dev/null
    fi
	echo "ID [${IPX}] : Network refreshed done...!!"
    logger "helminetlog:: ID [${IPX}] : Network refreshed done...!!"
done
