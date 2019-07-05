#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

if ! on_mac; then
    echoerr "This script only works on mac"
    exit 1
fi

tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1

# Script Arguments

usage="$0 DEVICE MODEL"

device="$(require_device_sdcard "$1" "$usage")" || exit 1
device_root="$(get_device_root "$device")"

model="$(require_model "$2" "$usage")" || exit 1
filename="$(get_arch_filename "$model")"


download_archlinux_arm "$model" "$filename"
process="$?"

umount_device "$tmp_dir" "$device"


echoblue "Partitioning $device"
diskutil partitionDisk "$device" 2 MBR \
        "MS-DOS FAT32" BOOT 100M \
        "MS-DOS FAT32" ROOT R \
        || exit 1
umount_device "$tmp_dir" "$device"

echoblue "Formating root as ext4"
format_ext4 "$device_root" ROOT || exit 1

wait_for_download "$process"

sleep 3
umount_device "$tmp_dir" "$device"
mount_device "$tmp_dir" "$device"

untar_and_copy_arch "$filename" "$tmp_dir"

umount_device "$tmp_dir" "$device"
