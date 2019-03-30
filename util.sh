function cd_tmpdir() {
    local tmp_dir=/tmp/rpi/"$1"

    mkdir -p "$tmp_dir" || exit 1

    echo "$tmp_dir"
}

function require_device() {
    local device="$1"
    if [ -z "$device" ]; then
        local device=$(lsblk -rdo NAME | grep mmc | fzf --reverse --header='Pick the device' --exit-0)
    fi
    if [ -z "$device" ]; then
        echo ""
    else
        echo "/dev/$device"
    fi
}

function require_model() {
    echo $(echo -e 'rpi\nrpi2' | fzf --reverse --header='Pick the rpi model')
}

function require_network_profile() {
    echo $(find /etc/netctl -maxdepth 1 -type f -printf %f\\n | sort | fzf --reverse --header='Pick the network profile')
}

function device() {
    local device="$1"
    local partition="$2"

    if on_linux; then
        echo "${device}p${partition}"
    elif on_mac; then
        echo "${device}s${partition}"
    else
        echo "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}

function umount_device() {
    local tmp_dir="$1"
    local device="$2"
    local p1=$(device "$device" 1)
    local p2=$(device "$device" 2)

    if on_linux; then
        if mount | grep "$tmp_dir/boot" > /dev/null || mount | grep "$p1" > /dev/null; then
            echo "Unmounting mounted boot."
            sudo umount "$p1" || exit 1
        fi
        if mount | grep "$tmp_dir/root" > /dev/null || mount | grep "$p2" > /dev/null; then
            echo "Unmounting mounted root."
            sudo umount "$p1" || exit 1
        fi
    elif on_mac; then
        diskutil unmountDisk "$device" || exit 1
    else
        echo "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}

function mount_device() {
    local tmp_dir="$1"
    local device="$2"
    local p1=$(device "$device" 1)
    local p2=$(device "$device" 2)

    #sudo fsck.ext4 -y "$p2"
    #sudo fsck.ext4 -y "$p1"

    echo "Mounting root and boot"
    if on_linux; then
        mkdir -p "$tmp_dir/root" "$tmp_dir/boot" || exit 1
        sudo mount -o rw "$p2" "$tmp_dir/root" || exit 1
        sudo mount -o rw "$p1" "$tmp_dir/boot" || exit 1
    elif on_mac; then
        diskutil mountDisk "$device" || exit 1
    else
        echo "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}

function on_linux() {
    [[ "$OSTYPE" = "linux-gnu" ]]
}

function on_mac() {
    [[ "$OSTYPE" = "darwin"* ]]
}

function get_available_devices() {
    if on_linux; then
        lsblk -rdo NAME | grep mmc
    elif on_mac; then
         diskutil list external physical \
             | grep /dev \
             | cut -d" " -f1 \
             | cut -d/ -f3
    else
        echo "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}

function format_ext4() {
    if on_linux; then
        echo y | sudo mkfs.ext4 "$1"
    elif on_mac; then
        echo y | sudo /usr/local/opt/e2fsprogs/sbin/mkfs.ext4 "$1"
    else
        echo "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}


function format_vfat() {
    if on_linux; then
        echo y | sudo mkfs.vfat "$1"
    elif on_mac; then
        sudo newfs_exfat "$1"
    else
        echo "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}
