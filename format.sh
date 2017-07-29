#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

tmp_dir=$(cd_tmpdir)
cd "$tmp_dir" || exit 1

device=$(require_device "$1")
if [ -z "$device" ]; then
    echo "No device found, aborting."
    exit 1
fi
model=$(require_model)
if [ -z "$model" ]; then
    exit 1
fi
netctl_profile=$(require_network_profile)
if [ -z "$netctl_profile" ]; then
    exit 1
fi

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
    ( (curl --silent --location --remote-name "http://os.archlinuxarm.org/os/$filename") && mv new-md5 current-md5 && echo "Download done." || echo "Failed to download.")&
    process=$!
else
    echo "We don't, continuing"
    process=0
fi

umount_device "$tmp_dir" "$device"


# Partitioning RPI
echo "Partitioning $device"
sudo fdisk "$device" << STOP
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


# Copy network profile and change interface to wlan0
sudo sh -c "cp /etc/netctl/$netctl_profile $tmp_dir/root/etc/netctl/$netctl_profile" || exit 1

sudo arch-chroot "$tmp_dir/root" /bin/bash <<HERE
sed -i -e 's/Interface=.*$/Interface=wlan0/' "/etc/netctl/$netctl_profile"
netctl enable $netctl_profile 2>/dev/null
HERE


# Done
umount_device "$tmp_dir" "$device"
