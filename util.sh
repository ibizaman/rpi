function cd_tmpdir() {
    local tmp_dir=/tmp/rpi/$(basename "$DIR")

    mkdir -p "$tmp_dir" || exit 1

    echo "$tmp_dir"
}

function require_device() {
    local device="$1"
    if [ -z "$device" ]; then
        local device=$(lsblk -rdo NAME | grep mmc | fzf --reverse --header='Pick the device')
    fi
    echo "/dev/$device"
}

function require_model() {
    echo $(echo -e 'rpi\nrpi2' | fzf --reverse --header='Pick the rpi model')
}

function require_network_profile() {
    echo $(find /etc/netctl -maxdepth 1 -type f -printf %f\\n | sort | fzf --reverse --header='Pick the network profile')
}

function umount_device() {
    local tmp_dir="$1"
    local device="$2"

    if mount | grep "$tmp_dir/boot" > /dev/null || mount | grep "${device}p1" > /dev/null; then
        echo "Unmounting mounted boot."
        sudo umount "${device}p1" || exit 1
    fi
    if mount | grep "$tmp_dir/root" > /dev/null || mount | grep "${device}p2" > /dev/null; then
        echo "Unmounting mounted root."
        sudo umount "${device}p2" || exit 1
    fi
}

function mount_device() {
    local tmp_dir="$1"
    local device="$2"

    sudo fsck -y "${device}p2"
    sudo fsck -y "${device}p1"

    mkdir -p "$tmp_dir/root" "$tmp_dir/boot" || exit 1

    echo "Mounting root and boot"
    sudo mount -o rw "${device}p2" "$tmp_dir/root" || exit 1
    sudo mount -o rw "${device}p1" "$tmp_dir/boot" || exit 1
}
