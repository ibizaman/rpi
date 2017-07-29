#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

tmp_dir=$(cd_tmpdir)
cd "$tmp_dir" || exit 1

device=$(require_device "$1")
if [ -z "$device" ]; then
    exit 1
fi

mount_device "$tmp_dir" "$device"
echo Mounted in "$tmp_dir"
