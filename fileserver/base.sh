#!/bin/bash

function arguments() {
    usage="$usage THIS_HOST SSH_HOST SSH_USER SSH_PASSWORD"
    this_host="$(require_host "$1" "$usage")" || exit 1
    shift
    ssh_host="$(require_host "$1" "$usage")" || exit 1
    shift
    ssh_user="$(require_user "$1" "$ssh_host" "$usage")" || exit 1
    shift
    ssh_password="$1"
    shift

    root_password="$(pass server-passwords/"$host/root@$host" | xargs -0 echo -n)"
    user_password="$(pass server-passwords/"$host/$user@$host" | xargs -0 echo -n)"

    user_ssh_pubkey="$(get_or_create_ssh_key "$this_host" "$host" "$user")" || exit 1
}


function install_remote() {
    echo "Update system"

    pacman-key --init || exit 1
    pacman-key --populate archlinuxarm || exit 1
    pacman -Sy --noconfirm --needed archlinuxarm-keyring || exit 1
    pacman -Syu --noconfirm --needed \
        base-devel \
        cmake \
        fcron \
        git \
        mdadm \
        miniupnpc \
        netctl \
        python \
        python-pip \
        python2 \
        python2-pip \
        tmux \
        vim \
        || exit 1


    echo "Install systemd-timesyncd"

    systemctl start systemd-timesyncd
    systemctl enable systemd-timesyncd
    timedatectl set-ntp true


    echo "Generate locale"

    sed -i 's/#\(en_US.UTF-8\)/\1/' /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf


    echo "Store hostname"

    echo "$host" > /etc/hostname
    grep -q -F "127.0.0.1	$host.localdomain	$host" /etc/hosts || echo -e "127.0.0.1\t$host.localdomain\t$host" >> /etc/hosts


    echo "Root password"

    passwd <<PASSWD
${root_password}
${root_password}
PASSWD


    echo "Sshd without password connections"

    pacman --noconfirm --needed -S openssh
    systemctl enable sshd


    echo "Add user to wheel group"

    useradd -m "$user"
    usermod -aG wheel "$user"
    passwd "$user" <<PASSWD
${user_password}
${user_password}
PASSWD


    echo "Add wheel group to sudoers"

    pacman --noconfirm --needed -S sudo
    sed -i 's/# \(%wheel ALL=(ALL) ALL\)/\1/' /etc/sudoers


    echo "Allow remote access"

    su "$user" << USER
set -x

mkdir -p ~/.ssh
chmod 700 ~/.ssh
grep -q -F "${user_ssh_pubkey}" ~/.ssh/authorized_keys || echo ${user_ssh_pubkey} >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

USER


    echo "Install fcron"

    cat | fcrontab - <<-FCRONTAB
# * * * * *
# | | | | |
# | | | | +---- Day of the Week   (range: 1-7, 1 standing for Monday)
# | | | +------ Month of the Year (range: 1-12)
# | | +-------- Day of the Month  (range: 1-31)
# | +---------- Hour              (range: 0-23)
# +------------ Minute            (range: 0-59)

!erroronlymail(true)
FCRONTAB

    systemctl daemon-reload
    systemctl restart fcron
    systemctl enable fcron


    echo "Install upnpport"

    pip install --upgrade upnpport
    useradd --system upnpport
    cat > /etc/systemd/system/upnpport.service <<UPNPPORT
[Unit]
Description=UPnPPort service
After=network.target

[Service]
User=upnpport
Group=upnpport
ExecStart=/usr/bin/upnpport run
ExecReload=/bin/kill -s usr1 \$MAINPID

[Install]
WantedBy=default.target
UPNPPORT

    [ -d /etc/upnpport ] || mkdir /etc/upnpport
    [ -f /etc/upnpport/upnpport.yaml ] || touch /etc/upnpport/upnpport.yaml

    systemctl daemon-reload
    systemctl restart upnpport
    systemctl enable upnpport

}


function install_local() {
    echo "Now try to log in without password, on success, run on the server:"
    echo "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config"
    :
}
