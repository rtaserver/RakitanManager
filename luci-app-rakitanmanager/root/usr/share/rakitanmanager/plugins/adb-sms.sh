#!/bin/sh
#Replace with IP or device ID, support multiple android adb device id, writing sample: 'id0001 id0002'

NAMAMODEM=$1

if [ -z "$2" ]; then
	ADBID=$(adb devices | grep 'device' | grep -v 'List of' | awk {'print $1'}) # Default device_id if $1 unset
else
	ADBID="$2"
fi

for IPX in ${ADBID}
do
	echo -e "====================="
	echo -e "SMS from device: ${NAMAMODEM} ${IPX}"
	echo -e "====================="
	adb -s "$IPX" shell content query --uri content://sms --projection _id,body
	echo -e "====================="
done
