#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

if ! on_linux; then
    echoerr "This script only works on linux"
    exit 1
fi

tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1


usage="$0 DEVICE MODEL HOST USER [NETWORK_PROFILE]"


device="$(require_device "$1" "$usage")" || exit 1
device_boot="$(get_device_boot "$device")"
device_root="$(get_device_root "$device")"

model="$(require_model "$2" "$usage")" || exit 1
filename="$(get_arch_filename "$model")"

host="$(require_host "$3" "$usage")" || exit 1

user="$(require_user "$4" "$host" "$usage")" || exit 1

network_profile="$(require_network_profile "$5" "$usage")"

root_password="$(get_or_create_password "$host" root)" || exit 1
user_password="$(get_or_create_password "$host" "$user" "$RPI_PASSWORD_USER")" || exit 1
user_ssh_pubkey="$(get_or_create_ssh_key "$host" "$user")" || exit 1


download_archlinux "$model" "$filename"
process="$?"


echoblue "Partitioning $device"

umount_device "$tmp_dir" "$device"

sudo fdisk "$device" << STOP || exit 1
p
o
n
p
1

+100M
t
c
n
p
2


p
w
STOP

echoblue "Formatting partitions."
format_vfat "$device_boot" BOOT || exit 1
format_ext4 "$device_root" ROOT || exit 1

wait_for_download "$process"

mount_device "$tmp_dir" "$device"

untar_and_copy_arch "$filename" "$tmp_dir"

export RPI_PASSWORD_ROOT="$root_password"
export RPI_PASSWORD_USER="$user_password"
export RPI_SSH_KEY="$user_ssh_pubkey"
./format-archchroot.sh "$host" "$user" "$network_profile"

# Done
umount_device "$tmp_dir" "$device"
