#!/bin/bash
# A UNIX / Linux shell script to resize partitions in HD-SD cards.
# Tested in Kali-Linux and Raspbian.
# -------------------------------------------------------------------------
# Copyright (c) 2014 David Trigo <david.trigo@gmail.com>
# This script is licensed under GNU GPL version 3.0 or above
# -------------------------------------------------------------------------
# Last updated on : Jan-2014 - Script created.
# -------------------------------------------------------------------------



if ! [ -h /dev/root ]; then
	echo "/dev/root does not exist or is not a symlink. Don't know how to expand"
	return 0
fi

ROOT_PART=$(readlink /dev/root)
PART_NUM=${ROOT_PART#mmcblk0p}
if [ "$PART_NUM" = "$ROOT_PART" ]; then
	echo "/dev/root is not an SD card. Don't know how to expand" 
	return 0
fi

LAST_PART_NUM=$(parted /dev/mmcblk0 -ms unit s p | tail -n 1 | cut -f 1 -d:)

if [ "$LAST_PART_NUM" != "$PART_NUM" ]; then
	echo "/dev/root is not the last partition. Don't know how to expand" 
	return 0
fi

# Get the starting offset of the root partition
PART_START=$(parted /dev/mmcblk0 -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d:)
[ "$PART_START" ] || return 1
# Return value will likely be error for fdisk as it fails to reload the
# partition table because the root fs is mounted
fdisk /dev/mmcblk0 <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF


# now set up an init.d script
cat <<\EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "$1" in
start)
log_daemon_msg "Starting resize2fs_once" &&
resize2fs /dev/root &&
rm /etc/init.d/resize2fs_once &&
update-rc.d resize2fs_once remove &&
log_end_msg $?
;;
*)
echo "Usage: $0 start" >&2
exit 3
;;
esac
EOF

chmod +x /etc/init.d/resize2fs_once

update-rc.d resize2fs_once defaults

echo "Root partition has been resized."
echo "The filesystem will be enlarged upon the next reboot." 
