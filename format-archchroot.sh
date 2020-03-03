#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

if ! on_linux; then
    echoerr "This script only works on linux"
    exit 1
fi

tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1


usage="$0 DEVICE HOST USER [NETWORK_PROFILE]"

device="$(require_device_sdcard "$1" "$usage")" || exit 1
host="$(require_host "$2" "$usage")" || exit 1
user="$(require_user "$3" "$host" "$usage")" || exit 1

network_profile="$(require_network_profile "$4" "$usage")"

root_password="$(get_or_create_password "$host" root "$RPI_PASSWORD_ROOT")" || exit 1
user_password="$(get_or_create_password "$host" "$user" "$RPI_PASSWORD_USER")" || exit 1
user_ssh_pubkey="$(get_or_create_ssh_key "$RPI_HOSTNAME" "$host" "$user" "$RPI_SSH_KEY")" || exit 1

umount_device "$tmp_dir" "$device"
mount_device "$tmp_dir" "$device"

echoyellow "Copying files to allow to chroot."
sudo cp /usr/bin/qemu-arm-static /usr/bin/qemu-aarch64-static "$tmp_dir/root/usr/bin" || exit 1

if [ -n "$network_profile" ]; then
    # Copy network profile, interface change to wlan0 is done later
    sudo sh -c "cp /etc/netctl/$network_profile $tmp_dir/root/etc/netctl/$network_profile" || exit 1
fi

echoyellow "Chrooting into $tmp_dir/root"
sudo arch-chroot "$tmp_dir/root" /bin/bash <<HERE
$(typeset -f echoyellow)

# Avoid getting the following message on upgrade of linux-raspberrypi
#   WARNING: /boot appears to be a seperate partition but is not mounted.
#            You probably just broke your system. Congratulations.
echoyellow "Mounting boot"
mount boot || exit 1


#########################
echoyellow "Update system"
#########################

pacman-key --init || exit 1
pacman-key --populate archlinuxarm || exit 1
pacman -Sy --noconfirm --needed archlinuxarm-keyring || exit 1
pacman -Syu --noconfirm || exit 1


##################################
echoyellow "Enable Network Profile"
##################################

if [ ! -z "$network_profile" ]; then
    sed -i -e 's/Interface=.*$/Interface=wlan0/' "/etc/netctl/$network_profile"
    netctl enable $network_profile 2>/dev/null

    pushd /etc/modprobe.d
    curl -O https://raw.githubusercontent.com/pvaret/rtl8192cu-fixes/17350bfa80bdc97fec5db0e760d13d8ed8c523bb/8192cu-disable-power-management.conf
    popd
fi


###########################
echoyellow "Generate locale"
###########################

sed -i 's/#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf


##########################
echoyellow "Store hostname"
##########################

echo "$host" > /etc/hostname
grep -q -F "127.0.0.1	$host.localdomain	$host" /etc/hosts || echo -e "127.0.0.1\t$host.localdomain\t$host" >> /etc/hosts


#########################
echoyellow "Root password"
#########################

passwd <<PASSWD
${root_password}
${root_password}
PASSWD


#############################################
echoyellow "Sshd without password connections"
#############################################

pacman --noconfirm --needed -S openssh
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl enable sshd


###################################
echoyellow "Add user to wheel group"
###################################

useradd -m ${USER}
usermod -aG wheel ${USER}
passwd ${user} <<PASSWD
${user_password}
${user_password}
PASSWD


######################################
echoyellow "Add wheel group to sudoers"
######################################

pacman --noconfirm --needed -S sudo
sed -i 's/# \(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers


###############################
echoyellow "Allow remote access"
###############################

su ${user} << USER
set -x

mkdir -p ~/.ssh
chmod 700 ~/.ssh
grep -q -F "${user_ssh_pubkey}" ~/.ssh/authorized_keys || echo ${user_ssh_pubkey} >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

USER


#######################################################
echoyellow "Install needed packages for Edimax USB WiFi"
#######################################################
# https://raspberrypi.stackexchange.com/questions/12946/set-up-edimax-ew-7811un-wifi-dongle
# https://www.raspberrypi.org/forums/viewtopic.php?t=146592&p=971726
# Do not disable WiFi after inactivity period
# https://bbs.archlinux.org/viewtopic.php?pid=1512272#p1512272

pacman --noconfirm --needed -S dkms-8192cu

HERE
echoyellow "No more chrooting"

echoyellow "Running sync, this time should be quick..."
sync || exit 1

umount_device "$tmp_dir" "$device"
