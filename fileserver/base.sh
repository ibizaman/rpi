#!/bin/bash

function arguments() {
    :
}


function install_remote() {
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
    :
}
