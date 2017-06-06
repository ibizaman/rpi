#!/bin/sh

# Needs:
#   pacaur -S \
#       curl \
#       fdisk \
#       pv \
#       arch-install-scripts \
#       binfmt-support \
#       qemu-user-static \
#
# See https://wiki.archlinux.org/index.php/Raspberry_Pi#QEMU_chroot

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/util.sh"

tmp_dir=$(cd_tmpdir)
cd "$tmp_dir"

device=$(require_device "$1")


# Downloading Arch if needed
echo "Checking if we need to download the latest ArchLinuxARM iso"
curl --silent --location --output new-md5 'http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz.md5' || exit 1

if [ ! -f current-md5 ] || [ "$(cat current-md5)" != "$(cat new-md5)" ] || [ "$(cat current-md5)" != "$(md5sum ArchLinuxARM-rpi-latest.tar.gz)" ]; then
    echo "We do, downloading in the background..."
    ((curl --silent --location --remote-name 'http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-latest.tar.gz') && mv new-md5 current-md5 && echo "Download done." || echo "Failed to download.")&
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
sudo sh -c 'pv ArchLinuxARM-rpi-latest.tar.gz | bsdtar -xpf - -C root' || exit 1
sync || exit 1
sudo mv root/boot/* boot || exit 1


# Allow to chroot
sudo cp /usr/bin/qemu-arm-static /usr/bin/qemu-aarch64-static "$tmp_dir/root/usr/bin" || exit 1


# Copy network profile
netctl_profile=$(find /etc/netctl -maxdepth 1 -type f -printf %f\\n | sort | fzf)
sudo sh -c "cp /etc/netctl/$netctl_profile $tmp_dir/root/etc/netctl/$netctl_profile" || exit 1

sudo arch-chroot "$tmp_dir/root" /bin/bash <<HERE
netctl enable $netctl_profile
HERE


# Done
umount_device "$tmp_dir" "$device"
