#!/bin/bash

cmd=$(basename $0)

function cd_tmpdir() {
    local tmp_dir=/tmp/rpi/"$1"

    mkdir -p "$tmp_dir" || exit 1

    echo "$tmp_dir"
}

function contains() {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]]
}

function echoyellow() {
    printf "\e[33m$cmd: %s\e[0m\n" "$*"
}

function echogreen() {
    printf "\e[32m$cmd: %s\e[0m\n" "$*"
}

function echoblue() {
    printf "\e[34m$cmd: %s\e[0m\n" "$*"
}

function echoerr() {
    printf "\e[31m$cmd: %s\e[0m\n" "$*" >&2
}

function require_device() {
    local device="$1"
    local usage="$2"
    local available_devices=$(get_available_devices)
    if [ -z "$available_devices" ]; then
        echoerr "$usage"
        echoerr
        echoerr "No compatible device found."
        exit 1
    fi
    if [ -z "$device" ] || ! contains "$available_devices" "$device"; then
        echoerr "$usage"
        echoerr
        echoerr "DEVICE must be one of:"
        echoerr "$available_devices"
        exit 1
    fi

    echo "/dev/$device"
}

function get_available_devices() {
    if on_linux; then
        lsblk -rdo NAME
    elif on_mac; then
         diskutil list external physical \
             | grep /dev \
             | cut -d" " -f1 \
             | cut -d/ -f3
    else
        echoerr "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}

function get_device_boot() {
    device "$device" 1
}

function get_device_root() {
    device "$device" 2
}

function device() {
    local device="$1"
    local partition="$2"

    if on_linux; then
        echo "${device}${partition}"
    elif on_mac; then
        echo "${device}s${partition}"
    else
        echoerr "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}

function require_model() {
    local model="$1"
    local usage="$2"
    local available_models=$(echo -e "rpi\nrpi2\nrpi3")
    if [ -z "$model" ] || ! contains "$available_models" "$model"; then
        echoerr "$usage"
        echoerr
        echoerr "MODEL must be one of:"
        echoerr "$available_models"
        exit 1
    fi

    echo "$model"
}

function get_arch_filename() {
    local model="$1"

    if [ "$model" = "rpi" ]; then
        echo 'ArchLinuxARM-rpi-latest.tar.gz'
    elif [ "$model" = "rpi2" ]; then
        echo 'ArchLinuxARM-rpi-2-latest.tar.gz'
    elif [ "$model" = "rpi3" ]; then
        echo 'ArchLinuxARM-rpi-3-latest.tar.gz'
    else
        echoerr "Unsupported model $model"
        exit 1
    fi
}

function require_host() {
    local host="$1"
    local usage="$2"
    local available_hosts="$(ls ~/.password-store/server-passwords)"
    if [ -z "$host" ]; then
        echoerr "$usage"
        echoerr
        echoerr "HOST can be one of, or a new one:"
        echoerr "$available_hosts"
        echoerr
        echoerr "hosts are found under ~/.password-store/server-passwords/"
        exit 1
    fi
    # This is needed at least for letsencrypt.
    if ! [[ "$host" =~ ^[0-9a-zA-Z.-]+$ ]]; then
        echoerr "HOST can only contain numbers, letters and - and . characters."
        exit 1
    fi

    echo "$host"
}

function require_user() {
    local user="$1"
    local host="$2"
    local usage="$3"
    if [ -z "$user" ]; then
        echoerr "$usage"
        echoerr
        echoerr "INSTALL_USER can be one of, or a new one:"
        echoerr "$(get_users $host)" | grep -v root
        echoerr
        echoerr "users are found under ~/.password-store/server-passwords/$host/"
        exit 1
    fi

    echo "$user"
}

function get_users() {
    local host="$1"
    ls ~/.password-store/server-passwords/"$host" 2>/dev/null \
        | cut -d '.' -f 1
}

function require_network_profile() {
    local network_profile="$1"
    local usage="$2"
    local available_network_profiles=$(find /etc/netctl -maxdepth 1 -type f -printf '%f\n' | sort)
    if [ -z "$network_profile" ] || ! contains "$available_network_profiles" "$network_profile"; then
        echoerr "$usage"
        echoerr
        echoerr "NETWORK_PROFILE must be one of:"
        echoerr "$available_network_profiles"
        echoerr
        echoerr 'network profiles are found under /etc/netctl/'
        exit 1
    fi

    echo "$network_profile"
}

function require_file() {
    local file="$1"
    local usage="$2"
    local available_files="$(find . -mindepth 2 -type f -name '*.sh' -printf '%P\n' | sort)"
    if [ -z "$file" ] || ! contains "$available_files" "$file"; then
        echoerr "$usage"
        echoerr
        echoerr "FILE must be one of:"
        echoerr "$available_files"
        exit 1
    fi

    echo "$file"
}

function get_or_create_password() {
    local host="$1"
    local user="$2"
    local pw="$3"
    if [ -n "$pw" ]; then
        echo "$pw"
    elif ! contains "$(get_users "$host")" "$user"; then
        echoerr "Generating new password for $user in host $host"
        pass generate "server-passwords/$host/$user" \
            | tail -n1 \
            | xargs -0 echo -n \
            || exit 1
    else
        pass "server-passwords/$host/$user" \
            | xargs -0 echo -n \
            || exit 1
    fi
}

function get_or_create_pass() {
    local path="$1"

    if ! pass ls "$path" &>/dev/null; then
        pass generate "$path" \
            | tail -n1 \
            | xargs -0 echo -n \
            || exit 1
    else
        pass "$path" \
            | xargs -0 echo -n \
            || exit 1
    fi
}

function get_or_create_ssh_key() {
    local host="$1"
    local user="$2"
    local key="$3"
    local private_key="$HOME/.ssh/$host-$user"
    local public_key="$private_key.pub"
    if [ -n "$key" ]; then
        echo "$key"
        exit 0
    else
        pass generate --force "sshkey-passphrase/$host-$user" >/dev/null
        local user_ssh_passphrase="$(pass show "sshkey-passphrase/$host-$user" | xargs -0 echo -n)"

        if [ -z "$user_ssh_passphrase" ]; then
            echoerr "Failed to create passphrase, aborting."
            exit 1
        fi

        rm "$private_key" "$public_key"
        ssh-keygen -t rsa -b 4096 \
                   -f "$private_key" \
                   -N "$user_ssh_passphrase" \
                   </dev/null \
            || exit 1
    fi

    xargs -0 echo -n < "$public_key"
}

function download_archlinux() {
    local model="$1"
    local filename="$2"

    echoerr "Checking if we need to download the latest ArchLinuxARM iso"
    curl --silent --location \
         --output "new-md5-$model" \
         "http://os.archlinuxarm.org/os/$filename.md5"
    local current_md5="$(md5sum "$filename")"

    echoerr "Newest md5:" "$(cat "new-md5-$model")"
    echoerr "Current md5:" "$current_md5"

    if [ "$(cat "new-md5-$model")" != "$current_md5" ]; then
        echoerr "We do, downloading in the background..."
        (
            if curl --silent --location \
                    --remote-name \
                    "http://os.archlinuxarm.org/os/$filename"; then
                echoerr "Download done."
            else
                echoerr "Failed to download."
            fi
        )&
        local process=$!
    else
        echoerr "We don't, continuing"
        local process=0
    fi

    return "$process"
}

function wait_for_download() {
    local process="$1"

    if [ "$process" -ne 0 ]; then
        echoerr "Waiting for download to finish."
        wait "$process"
    fi
}

function untar_and_copy_arch() {
    local filename="$1"
    local device_dir="$2"

    echoerr 'Untaring into root.'
    if [ ! -f "$device_dir/root/root/.bootstrap" ]; then
        sudo sh -c "pv $filename | bsdtar -xpf - -C $device_dir/root" \
             && sudo touch "$device_dir/root/root/.bootstrap"
    fi
    sudo mv "$device_dir"/root/boot/* "$device_dir"/boot
    echoerr 'Running sync, can take a few minutes...'
    sync
}

function umount_device() {
    local tmp_dir="$1"
    local device="$2"
    local p1=$(device "$device" 1)
    local p2=$(device "$device" 2)

    if on_linux; then
        if mount | grep "$tmp_dir/boot" > /dev/null \
                || mount | grep "$p1" > /dev/null; then
            echoerr "Unmounting mounted boot."
            sudo umount "$p1"
        fi
    elif on_mac; then
        diskutil unmountDisk "$device"
    else
        echoerr "OSTYPE $OSTYPE not supported"
        exit 1
    fi

    if mount | grep "$tmp_dir/root" > /dev/null \
            || mount | grep "$p2" > /dev/null; then
        echoerr "Unmounting mounted root."
        sudo umount "$p2"
    fi
}

function mount_device() {
    local tmp_dir="$1"
    local device="$2"
    local p1=$(device "$device" 1)
    local p2=$(device "$device" 2)

    echoerr "Mounting $device root and boot on $tmp_dir"
    mkdir -p "$tmp_dir/root" "$tmp_dir/boot" || exit 1
    if on_linux; then
        sudo fsck.ext4 -y "$p2"
        sudo fsck.ext4 -y "$p1"

        sudo mount -o rw "$p2" "$tmp_dir/root" || exit 1
        sudo mount -o rw "$p1" "$tmp_dir/boot" || exit 1
    elif on_mac; then
        sudo diskutil mount -mountPoint "$tmp_dir/boot" "$p1" || exit 1
        sudo fuse-ext2 "$p2" "$tmp_dir/root" -o rw+ || exit 1
    else
        echoerr "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}

function on_linux() {
    [[ "$OSTYPE" = "linux-gnu" ]]
}

function on_mac() {
    [[ "$OSTYPE" = "darwin"* ]]
}

function format_ext4() {
    if on_linux; then
        echo y | sudo mkfs.ext4 -L "$2" "$1"
    elif on_mac; then
        echo y | sudo /usr/local/opt/e2fsprogs/sbin/mkfs.ext4 -L "$2" "$1"
    else
        echo "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}


function format_vfat() {
    if on_linux; then
        echo y | sudo mkfs.vfat -n "$2" "$1"
    elif on_mac; then
        sudo newfs_exfat -v "$2" "$1"
    else
        echo "OSTYPE $OSTYPE not supported"
        exit 1
    fi
}
