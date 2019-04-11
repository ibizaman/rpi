#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"


usage="$0 DEVICE FILE [NETWORK_PROFILE]"

device="$(require_device "$1" "$usage")" || exit 1
shift
file="$(require_file "$1" "$usage")" || exit 1
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
