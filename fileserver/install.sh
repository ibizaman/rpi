#!/bin/bash

# First run ../format.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/../util.sh"

tmp_dir=$(cd_tmpdir rpi)
cd "$tmp_dir" || exit 1

device=$(require_device "$1")
if [ -z "$device" ]; then
    echo "No device found, aborting."
    exit 1
fi

umount_device "$tmp_dir" "$device"
mount_device "$tmp_dir" "$device"


# Make github.com known to ssh
ssh_folder="$tmp_dir/root/home/alarm/.ssh"
sudo sh -c "mkdir -p $ssh_folder && grep 192.30.255.113 $HOME/.ssh/known_hosts >> $ssh_folder/known_hosts" || exit 1


# Install conffiles
sudo arch-chroot "$tmp_dir/root" /bin/bash <<HERE
pacman -Syu --noconfirm \
    base-devel \
    cmake \
    fcron \
    git \
    mdadm \
    netctl \
    python \
    python-pip \
    python2 \
    python2-pip \
    sudo \
    tmux \
    vim \
    || exit 1

echo '%wheel ALL = (ALL) ALL' >> /etc/sudoers

chown -R alarm: /home/alarm/.ssh
chmod -R go-rwx /home/alarm/.ssh

systemctl start fcron

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
localectl set-locale LANG=en_US.UTF-8

su - alarm

if git clone https://github.com/ibizaman/conffiles.git .vim; then
    ./.vim/install.sh
fi
HERE

umount_device "$tmp_dir" "$device"
