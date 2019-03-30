#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1


# Script Arguments

if ! ls ~/.password-store >/dev/null 2>&1; then
    echo "Could not access ~/.password-store/, please open the pass tomb."
    exit 1
fi

contains() {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]]
}

usage() {
    echo "$0 DEVICE RPI_MODEL HOST USER NETWORK_PROFILE"
}

## DEVICE
device="$1"
available_devices=$(get_available_devices)
if [ -z "$device" ] || ! contains "$available_devices" "$device"; then
    usage
    echo "DEVICE must be one of:"
    echo "$available_devices"
    exit 1
fi
device=/dev/"$device"
device_boot="$(device "$device" 1)"
device_root="$(device "$device" 2)"
shift

## MODEL
model="$1"
available_models=$(echo -e "rpi\nrpi2\nrpi3")
if [ -z "$model" ] || ! contains "$available_models" "$model"; then
    usage
    echo "MODEL must be one of:"
    echo "$available_models"
    exit 1
fi
shift

if [ "$model" = "rpi" ]; then
    filename='ArchLinuxARM-rpi-latest.tar.gz'
elif [ "$model" = "rpi2" ]; then
    filename='ArchLinuxARM-rpi-2-latest.tar.gz'
elif [ "$model" = "rpi3" ]; then
    filename='ArchLinuxARM-rpi-2-latest.tar.gz'  # yes, 2 not 3
else
    echo "Unsupported model $model"
    exit 1
fi

## HOST
host="$1"
available_hosts="$(ls ~/.password-store/server-passwords)"
if [ -z "$host" ]; then
    usage
    echo "HOST can be one of, or a new one:"
    echo "$available_hosts"
    exit 1
fi
# This is needed at least for letsencrypt.
if ! [[ "$host" =~ ^[0-9a-zA-Z.-]+$ ]]; then
    echo "HOST can only contain numbers, letters and - and . characters."
    exit 1
fi
shift

## USER
user="$1"
available_users="$(ls ~/.password-store/server-passwords/"$host" 2>/dev/null | cut -d '.' -f 1)"
if [ -z "$user" ]; then
    usage
    echo "INSTALL_USER can be one of, or a new one:"
    echo "$available_users" | grep -v root
    exit 1
fi
shift

## NETWORK_PROFILE
if ! on_linux; then
    echo "Creating network profile only support on linux OS"
else
    network_profile="$1"
    available_network_profiles=$(find /etc/netctl -maxdepth 1 -type f -printf '%f\n' | sort)
    if [ -z "$network_profile" ] || ! contains "$available_network_profiles" "$network_profile"; then
        usage
        echo "NETWORK_PROFILE must be one of:"
        echo "$available_network_profiles"
        exit 1
    fi
    shift
fi

# Fetching or creating user passwords for host stored in pass
if ! contains "$available_users" "root"; then
    echo "Generating new root password for $host"
    root_password="$(pass generate "server-passwords/$host/root" | tail -n1 | xargs -0 echo -n)"
else
    root_password="$(pass "server-passwords/$host/root" | xargs -0 echo -n)"
fi

if ! contains "$available_users" "$user"; then
    echo "Generating new user password for $host"
    user_password="$(pass generate "server-passwords/$host/$user" | tail -n1 | xargs -0 echo -n)"
else
    user_password="$(pass "server-passwords/$host/$user" | xargs -0 echo -n)"
fi

# Fetching or creating user ssh keys for host with passphrase stored in pass
private_key="$HOME/.ssh/$host-$user"
public_key="$private_key.pub"

if ! [ -f "$public_key"  ]; then
    if [ -f "$private_key"  ]; then
        echo "A private key exists but no public key, aborting."; exit 1
    fi

    pass generate "sshkey-passphrase/$host-$user" >/dev/null
    user_ssh_passphrase="$(pass show "sshkey-passphrase/$host-$user" | xargs -0 echo -n)"

    if [ -z "$user_ssh_passphrase" ]; then
        echo "Failed to create passphrase, aborting."; exit 1
    fi

    ssh-keygen -t rsa -b 4096 -f "$private_key" -N "$user_ssh_passphrase" </dev/null || exit 1
fi

user_ssh_pubkey="$(xargs -0 echo -n < "$public_key")"

[ -z "$root_password" ] && echo "Empty root password" && exit 1
[ -z "$user_password" ] && echo "Empty user password" && exit 1
[ -z "$user_ssh_pubkey" ] && echo "Empty ssh passphrase" && exit 1


# Downloading Arch if needed
echo "Checking if we need to download the latest ArchLinuxARM iso"
curl --silent --location --output "new-md5-$model" "http://os.archlinuxarm.org/os/$filename.md5"
current_md5="$(md5sum "$filename")"

echo "Newest md5:" "$(cat "new-md5-$model")"
echo "Current md5:" "$current_md5"

if [ "$(cat "new-md5-$model")" != "$current_md5" ]; then
    echo "We do, downloading in the background..."
    ( (curl --silent --location --remote-name "http://os.archlinuxarm.org/os/$filename") && echo "Download done." || echo "Failed to download.")&
    process=$!
else
    echo "We don't, continuing"
    process=0
fi

umount_device "$tmp_dir" "$device"


# Partitioning RPI
echo "Partitioning $device"

if on_linux; then
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
elif on_mac; then
    diskutil partitionDisk "$device" 2 MBR \
            ExFAT boot 100M \
            ExFAT root R \
            || exit 1
    umount_device "$tmp_dir" "$device"
else
    echo "OSTYPE $OSTYPE not supported"
    exit 1
fi



# Formatting partitions
echo "Formatting partitions."
# TODO: make ext4 work without paragon
#format_vfat "$device_boot" || exit 1
#format_ext4 "$device_root" || exit 1

if [ $process -ne 0 ]; then
    echo "Waiting for download to finish."
    wait $process || exit 1
fi

mount_device "$tmp_dir" "$device"

if on_linux; then
    device_dir="$tmp_dir"
elif on_mac; then
    device_dir="/Volumes"
fi

# Copying Arch
echo 'Untaring into root.'
sudo sh -c "pv $filename | bsdtar -xpf - -C $device_dir/root" || exit 1
sudo mv "$device_dir/root/boot/*" "$device_dir/boot" || exit 1
echo 'Running sync, can take a few minutes...'
sync || exit 1

set -x

if ! on_linux; then
    echo "Advanced operations only supported on linux"
    exit 0
fi

# Allow to chroot
sudo cp /usr/bin/qemu-arm-static /usr/bin/qemu-aarch64-static "$tmp_dir/root/usr/bin" || exit 1


# Copy network profile, interface change to wlan0 is done later
sudo sh -c "cp /etc/netctl/$network_profile $tmp_dir/root/etc/netctl/$network_profile" || exit 1

sudo arch-chroot "$tmp_dir/root" /bin/bash <<HERE
set -x
# Avoid getting the following message on upgrade of linux-raspberrypi
#   WARNING: /boot appears to be a seperate partition but is not mounted.
#            You probably just broke your system. Congratulations.
mount boot


#################
# Update system #
#################

pacman -Syu --noconfirm || exit 1


##########################
# Enable Network Profile #
##########################

sed -i -e 's/Interface=.*$/Interface=wlan0/' "/etc/netctl/$network_profile"
netctl enable $network_profile 2>/dev/null

pushd /etc/modprobe.d
curl -O https://raw.githubusercontent.com/pvaret/rtl8192cu-fixes/17350bfa80bdc97fec5db0e760d13d8ed8c523bb/8192cu-disable-power-management.conf
popd


###################
# Generate locale #
###################

sed -i 's/#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf


##################
# Store hostname #
##################

echo "$host" > /etc/hostname
grep -q -F "127.0.0.1	$host.localdomain	$host" /etc/hosts || echo -e "127.0.0.1\t$host.localdomain\t$host" >> /etc/hosts


#################
# Root password #
#################

passwd <<PASSWD
${root_password}
${root_password}
PASSWD


#####################################
# Sshd without password connections #
#####################################

pacman --noconfirm --needed -S openssh
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl enable sshd


###########################
# Add user to wheel group #
###########################

useradd -m ${USER}
usermod -aG wheel ${USER}
passwd ${user} <<PASSWD
${user_password}
${user_password}
PASSWD


##############################
# Add wheel group to sudoers #
##############################

pacman --noconfirm --needed -S sudo
sed -i 's/# \(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers


#######################
# Allow remote access #
#######################

su ${user} << USER
set -x

mkdir -p ~/.ssh
chmod 700 ~/.ssh
grep -q -F "${user_ssh_pubkey}" ~/.ssh/authorized_keys || echo ${user_ssh_pubkey} >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

USER


###############################################
# Install needed packages for Edimax USB WiFi #
###############################################
# https://raspberrypi.stackexchange.com/questions/12946/set-up-edimax-ew-7811un-wifi-dongle
# https://www.raspberrypi.org/forums/viewtopic.php?t=146592&p=971726
# Do not disable WiFi after inactivity period
# https://bbs.archlinux.org/viewtopic.php?pid=1512272#p1512272

pacman --noconfirm --needed -S dkms-8192cu

HERE

echo 'Running sync, this time should be quick...'
sync || exit 1


# Done
umount_device "$tmp_dir" "$device"
