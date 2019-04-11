#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

if ! on_mac; then
    echoerr "This script only works on mac"
    exit 1
fi

function v_halt() {
    local dir="$1"
    (cd "$dir" && vagrant halt) || exit 1
}

function v_up() {
    local dir="$1"
    (cd "$dir" && vagrant up) || exit 1
}

function v_get_id() {
    local dir="$1"
    local machine="$2"
    vboxid="$(cat "$dir"/.vagrant/machines/"$machine"/virtualbox/id 2>/dev/null)"
    if [ -z "$vboxid" ]; then
        v_up "$dir" &>/dev/null || exit 1
        vboxid="$(cat "$dir"/.vagrant/machines/"$machine"/virtualbox/id 2>/dev/null)"
        if [ -z "$vboxid" ]; then
            echoerr "Couldn't find the virtualbox id"
            exit 1
        fi
        v_halt "$dir" &>/dev/null || exit 1
    fi

    echo "$vboxid"
}

function v_has_storage() {
    local vboxid="$1"
    if [ -z "$(VBoxManage showvminfo "$vboxid" | grep -i storage | grep SATA)" ]; then
        return 1
    else
        return 0
    fi
}

function v_remove_storage() {
    local vboxid="$1"
    local tmp_dir="$2"

    VBoxManage storageattach "$vboxid" --storagectl SATA --port 0 --type hdd --medium none
    VBoxManage storagectl "$vboxid" --name SATA --remove
    VBoxManage closemedium "$tmp_dir"/sd-card.vmdk
    rm "$tmp_dir"/sd-card.vmdk
}

tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1

# Script Arguments

usage="$0 DEVICE MODEL HOST USER"

device="$(require_device "$1" "$usage")" || exit 1
model="$(require_model "$2" "$usage")" || exit 1
host="$(require_host "$3" "$usage")" || exit 1
user="$(require_user "$4" "$host" "$usage")" || exit 1

root_password="$(get_or_create_password "$host" root)" || exit 1
user_password="$(get_or_create_password "$host" "$user")" || exit 1

user_ssh_pubkey="$(get_or_create_ssh_key "$host" "$user")" || exit 1


echogreen "Halting Vagrant"
v_halt "$DIR" || exit 1

echogreen "Finding VM id"
vboxid="$(v_get_id "$DIR" rpi)"
echogreen "Done: $vboxid"

echogreen "VM has SATA attached?"
if v_has_storage "$vboxid"; then
    echogreen "Yes, removing SATA disk"
    v_remove_storage "$vboxid" "$tmp_dir"
    echogreen "Disk removed"
else
    echogreen "No, continuing"
fi


"$DIR"/format-mac.sh "${device#/dev/}" "$model" "$host" || exit 1


echogreen "Creating SATA disk"
umount_device "$tmp_dir" "$device"

sleep 5

sudo VBoxManage internalcommands \
        createrawvmdk \
        -filename "$tmp_dir"/sd-card.vmdk \
        -rawdisk "$device"

# Needs both otherwise you get VERR_ACCESS_DENIED
echo "Sudo to chmod device:"
sudo chmod 666 "$tmp_dir"/sd-card.vmdk || exit 1
sudo chmod 666 "$device" || exit 1
echogreen "Done"

echogreen "Attaching SATA disk"
umount_device "$tmp_dir" "$device"
VBoxManage storagectl "$vboxid" --name SATA --add sata --controller IntelAhci --portcount 1 || exit 1
sleep 3
umount_device "$tmp_dir" "$device"
VBoxManage storageattach "$vboxid" --storagectl SATA --port 0 --type hdd --medium "$tmp_dir"/sd-card.vmdk || exit 1
echogreen "Done"

v_up "$DIR"

pushd "$DIR" >/dev/null || exit 1

echogreen "Copying files to VM"
vagrant scp /tmp/rpi :/tmp/rpi
vagrant ssh -- mkdir -p "~/.password-store/server-passwords/"
vagrant scp ~/.password-store/server-passwords/ :~/.password-store/server-passwords/

echogreen "Finding device"
all_devices="$(vagrant ssh -- lsblk -o LABEL,FSTYPE,NAME --list --noheadings)"
boot=$(echo "$all_devices" | grep BOOT | grep vfat | awk '{print $3}')
root=$(echo "$all_devices" | grep ROOT | grep ext4 | awk '{print $3}')
device_boot=${boot%?}
device_root=${root%?}
if [ "$device_boot" = "$device_root" ]; then
    echogreen "Found $device_root"
    device="$device_root"
else
    echoerr "Could not agree on device: $device_boot or $device_root"
fi


echogreen "SSHING into VM"
vagrant ssh -- -t <<EOF
$(typeset -f echogreen)

export RPI_PASSWORD_ROOT="$root_password"
export RPI_PASSWORD_USER="$user_password"
export RPI_SSH_KEY="$user_ssh_pubkey"

echogreen "Installing base-devel"
sudo pacman -Syu --noconfirm --needed base-devel

cd /vagrant || exit 1

echogreen "Make install-archlinux"
make install-archlinux || exit 1

echogreen "Launching linux formatting"
./format-archchroot.sh $device $host $user
EOF

v_halt "$DIR"
v_remove_storage "$vboxid" "$tmp_dir"
