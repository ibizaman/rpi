#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1

device=$(require_device "$1")
if [ -z "$device" ]; then
    exit 1
fi

umount_device "$tmp_dir" "$device"
mount_device "$tmp_dir" "$device"
sudo arch-chroot "$tmp_dir"/root /bin/bash
umount_device "$tmp_dir" "$device"
