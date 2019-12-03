#!/bin/bash

function arguments() {
    usage="$usage USER"
    user="$(require_user "$1" "$host" "$usage")" || exit 1
    shift
}


function install_remote() {
    pacman -Sy || exit 1

    pacman --noconfirm --needed -S \
           expac \
           gmock \
           gtest \
           jq \
           meson \
        || exit 1

    cd /opt || exit 1
    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/pod2man.tar.gz || exit 1
    tar -xzf pod2man.tar.gz || exit 1
    chown -R "$user": pod2man || exit 1
    cd pod2man || exit 1
    sudo -u "$user" -S bash <<EOF
    makepkg || exit 1
EOF
    pacman -U --noconfirm --needed pod2man-* || exit 1

    # auracle-git is a dependency
    cd /opt || exit 1
    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/auracle-git.tar.gz || exit 1
    tar -xzf auracle-git.tar.gz || exit 1
    chown -R "$user": auracle-git || exit 1
    cd auracle-git || exit 1
    sudo -u "$user" -S bash <<EOF
    pwd
    ls
    makepkg || exit 1
EOF
    pacman -U --noconfirm --needed auracle-git-* || exit 1

    cd /opt || exit 1
    curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/pacaur.tar.gz || exit 1
    tar -xzf pacaur.tar.gz || exit 1
    chown -R "$user": pacaur || exit 1
    cd pacaur || exit 1
    sudo -u "$user" -S bash <<EOF
    makepkg || exit 1
EOF
    pacman -U --noconfirm --needed pacaur-* || exit 1
}


function install_local() {
    :
}
