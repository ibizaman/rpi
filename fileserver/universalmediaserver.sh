#!/bin/bash

function arguments() {
    :
}


function run() {
    pacman -Syu --noconfirm --needed \
        fontconfig \
        mediainfo \
        dcraw \
        jre7-openjdk \
        ffmpeg \
        || exit 1


    cd /opt/

    #[ -d tsmuxer-2.6.11 ] || curl -L -O https://www.deb-multimedia.org/pool/non-free/t/tsmuxer/tsmuxer_2.6.11.orig.tar.gz || exit 1
    #tar xf tsmuxer_2.6.11.orig.tar.gz

    [ -d ums-6.8.0 ] || curl -L -O http://downloads.sourceforge.net/project/unimediaserver/Official%20Releases/Linux/UMS-6.8.0.tgz || exit 1
    tar xf UMS-6.8.0.tgz

    rm /opt/ums-6.8.0/linux/ffmpeg
    rm /opt/ums-6.8.0/linux/ffmpeg64
    #rm /opt/ums-6.8.0/linux/tsMuxeR
    #rm /opt/ums-6.8.0/linux/tsMuxeR-new
    ln -s /usr/bin/ffmpeg /opt/ums-6.8.0/linux/ffmpeg
    ln -s /usr/bin/ffmpeg /opt/ums-6.8.0/linux/ffmpeg64
    #ln -s /opt/tsmuxer-2.6.11/tsMuxeR /opt/ums-6.8.0/linux/tsMuxeR
    #ln -s /opt/tsmuxer-2.6.11/tsMuxeR /opt/ums-6.8.0/linux/tsMuxeR-new

    cp /opt/ums-6.8.0/

    useradd --home-dir /opt/ums-6.8.0 --system ums

    chown -R ums: /opt/ums-6.8.0

    # From https://aur.archlinux.org/cgit/aur.git/tree/ums.service?h=ums
    cat > /etc/systemd/system/ums.service <<UMSSERVICE
    [Unit]
    Description=Universal Media Server
    Wants=network.target
    After=syslog.target network-online.target rpcbind.service

    [Service]
    #Environment="UMS_MAX_MEMORY=1280M"
    User=ums
    Group=ums
    WorkingDirectory=/opt/ums-6.8.0/
    Type=simple
    ExecStart=/opt/ums-6.8.0/UMS.sh

    [Install]
    WantedBy=multi-user.target
    UMSSERVICE

    systemctl enable ums

    echo add '/srv/*' to folders and folders_monitored in /opt/ums-6.8.0/UMS.conf
}
