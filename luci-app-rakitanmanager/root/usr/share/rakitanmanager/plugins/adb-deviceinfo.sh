#!/bin/sh
#Replace with IP or device ID, support multiple android adb device id, writing sample: 'id0001 id0002'
if [ -z "$1" ]; then
	ADBID=$(adb devices | grep 'device' | grep -v 'List of' | awk {'print $1'}) # Default device_id if $1 unset
else
	ADBID="$1"
fi

for IPX in ${ADBID}
do
    echo -e "====================="
	echo -e "Device [${IPX}] status"
	echo -e "====================="
	adb -s "$IPX" shell dumpsys battery | grep "level\|powered"
	echo -e "====================="
	echo -e "Signal Info"
	echo -e "====================="
	adb -s "$IPX" shell dumpsys telephony.registry | grep -i 'signalstrength' | sed -e 's/,/\n/g' -e 's/ mMnc=//g' -e 's/mMcc=/\nPLMN=/g' -e 's/mAlphaLong=/\nISP Name (Long)=/g' -e 's/mAlphaShort=/\nISP Name (Short)=/g' 
	echo -e "====================="
done
