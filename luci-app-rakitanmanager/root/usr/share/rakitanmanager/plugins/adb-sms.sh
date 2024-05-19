#!/bin/sh
#Replace with IP or device ID, support multiple android adb device id, writing sample: 'id0001 id0002'
log_file="/var/log/rakitanmanager.log"
exec 1>>"$log_file" 2>&1

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

if ! command -v adb &> /dev/null; then
    echo "ADB tidak ditemukan. Pastikan Android Debug Bridge (ADB) telah diinstal."
    exit 1
fi

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
