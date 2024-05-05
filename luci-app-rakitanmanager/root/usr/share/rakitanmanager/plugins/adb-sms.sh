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
	echo -e "SMS from device: ${IPX}"
	echo -e "====================="
	adb -s "$IPX" shell content query --uri content://sms --projection _id,body
	echo -e "====================="
done
