#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"


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

## FILE
file="$1"
available_files="$(find * -mindepth 1 -type f -name '*.sh' | sort)"
if [ -z "$file" ] || ! contains "$available_files" "$file"; then
    echo "$0 HOST INSTALL_USER FILE [ARG...]"
    echo "FILE must be one of:"
    echo "$available_files"
    exit 1
fi
shift

source "$file"
arguments "$@"


tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1

umount_device "$tmp_dir" "$device"
mount_device "$tmp_dir" "$device"

sudo arch-chroot "$tmp_dir"/root <<EOF
$(typeset -f run)

set -x
install_remote
set +x

EOF

set -x
install_local
set +x

umount_device "$tmp_dir" "$device"
