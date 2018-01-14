#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1

contains() {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]]
}

device="$1"
available_devices=$(lsblk -rdo NAME | grep mmc)
if [ -z "$device" ] || ! contains "$available_devices" "$device"; then
    echo "$0 DEVICE RPI_MODEL NETWORK_PROFILE"
    echo "DEVICE must be one of:"
    echo "$available_devices"
    exit 1
fi
device=/dev/"$device"
device_boot=${device}p1
device_root=${device}p2
shift

model="$1"
available_models=$(echo -e "rpi\nrpi2")
if [ -z "$model" ] || ! contains "$available_models" "$model"; then
    echo "$0 DEVICE RPI_MODEL NETWORK_PROFILE"
    echo "MODEL must be one of:"
    echo "$available_models"
    exit 1
fi
shift

network_profile="$1"
available_network_profiles=$(find /etc/netctl -maxdepth 1 -type f -printf '%f\n' | sort)
if [ -z "$network_profile" ] || ! contains "$available_network_profiles" "$network_profile"; then
    echo "$0 DEVICE RPI_MODEL NETWORK_PROFILE"
    echo "NETWORK_PROFILE must be one of:"
    echo "$available_network_profiles"
    exit 1
fi
shift

if [ "$model" = "rpi" ]; then
    filename='ArchLinuxARM-rpi-latest.tar.gz'
elif [ "$model" = "rpi2" ]; then
    filename='ArchLinuxARM-rpi-2-latest.tar.gz'
fi


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


# Formatting partitions
echo "Formatting partitions."
echo y | sudo mkfs.vfat "${device}p1" || exit 1
echo y | sudo mkfs.ext4 "${device}p2" || exit 1

if [ $process -ne 0 ]; then
    echo "Waiting for download to finish."
    wait $process || exit 1
fi

mount_device "$tmp_dir" "$device"


# Copying Arch
echo 'Untaring into root.'
sudo sh -c "pv $filename | bsdtar -xpf - -C root" || exit 1
sudo mv root/boot/* boot || exit 1
echo 'sync'
sync || exit 1


# Allow to chroot
sudo cp /usr/bin/qemu-arm-static /usr/bin/qemu-aarch64-static "$tmp_dir/root/usr/bin" || exit 1


# Copy network profile, interface change to wlan0 is done later
sudo sh -c "cp /etc/netctl/$network_profile $tmp_dir/root/etc/netctl/$network_profile" || exit 1

# Install needed packages for Edimax USB WiFi
# https://raspberrypi.stackexchange.com/questions/12946/set-up-edimax-ew-7811un-wifi-dongle
# https://www.raspberrypi.org/forums/viewtopic.php?t=146592&p=971726
# Do not disable WiFi after inactivity period
# https://bbs.archlinux.org/viewtopic.php?pid=1512272#p1512272
sudo arch-chroot "$tmp_dir/root" /bin/bash <<HERE
# Avoid getting the following message on upgrade of linux-raspberrypi
#   WARNING: /boot appears to be a seperate partition but is not mounted.
#            You probably just broke your system. Congratulations.
mount boot
pacman -Syu --noconfirm
sed -i -e 's/Interface=.*$/Interface=wlan0/' "/etc/netctl/$netctl_profile"
netctl enable $netctl_profile 2>/dev/null

pushd /etc/modprobe.d
curl -O https://raw.githubusercontent.com/pvaret/rtl8192cu-fixes/17350bfa80bdc97fec5db0e760d13d8ed8c523bb/8192cu-disable-power-management.conf
popd
HERE
echo 'sync'
sync || exit 1


# Done
umount_device "$tmp_dir" "$device"
