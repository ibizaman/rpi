#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1


# Script Arguments

contains() {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]]
}

## DEVICE
device="$1"
available_devices=$(lsblk -rdo NAME | grep mmc)
if [ -z "$device" ] || ! contains "$available_devices" "$device"; then
    echo "$0 DEVICE"
    echo "DEVICE must be one of:"
    echo "$available_devices"
    exit 1
fi
device=/dev/"$device"
shift


# Mount and chroot into

umount_device "$tmp_dir" "$device"
mount_device "$tmp_dir" "$device"
sudo arch-chroot "$tmp_dir"/root /bin/bash
umount_device "$tmp_dir" "$device"
