#!/bin/bash

function arguments() {
    :
}


function install_remote() {
    UMS_VERSION=9.1.0

    pacman -Syu --noconfirm --needed \
        fontconfig \
        mediainfo \
        dcraw \
        jre7-openjdk \
        ffmpeg \
        || exit 1


    pushd /opt/ || exit 1

    #[ -d tsmuxer-2.6.11 ] || curl -L -O https://www.deb-multimedia.org/pool/non-free/t/tsmuxer/tsmuxer_2.6.11.orig.tar.gz || exit 1
    #tar xf tsmuxer_2.6.11.orig.tar.gz

    [ -d ums-${UMS_VERSION} ] || curl -L -O http://downloads.sourceforge.net/project/unimediaserver/Official%20Releases/Linux/UMS-${UMS_VERSION}.tgz || exit 1
    tar xf UMS-${UMS_VERSION}.tgz || exit 1

    #rm /opt/ums-6.8.0/linux/ffmpeg
    #rm /opt/ums-6.8.0/linux/ffmpeg64
    #rm /opt/ums-6.8.0/linux/tsMuxeR
    #rm /opt/ums-6.8.0/linux/tsMuxeR-new
    #ln -s /usr/bin/ffmpeg /opt/ums-6.8.0/linux/ffmpeg
    #ln -s /usr/bin/ffmpeg /opt/ums-6.8.0/linux/ffmpeg64
    #ln -s /opt/tsmuxer-2.6.11/tsMuxeR /opt/ums-6.8.0/linux/tsMuxeR
    #ln -s /opt/tsmuxer-2.6.11/tsMuxeR /opt/ums-6.8.0/linux/tsMuxeR-new

    pushd /opt/ums-${UMS_VERSION}/ || exit 1

    systemctl stop ums

    useradd --home-dir /opt/ums-${UMS_VERSION} --system ums \
	|| usermod --home /opt/ums-${UMS_VERSION} ums \
	|| exit 1

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
WorkingDirectory=/opt/ums-${UMS_VERSION}/
Type=simple
ExecStart=/opt/ums-${UMS_VERSION}/UMS.sh

[Install]
WantedBy=multi-user.target
UMSSERVICE

    systemctl daemon-reload
    systemctl enable ums

    if [ ! -f /opt/ums-${UMS_VERSION}/.config/UMS/UMS.conf ]; then
	mkdir -p /opt/ums-${UMS_VERSION}/.config/UMS
        cp /opt/ums-${UMS_VERSION}/UMS.conf /opt/ums-${UMS_VERSION}/.config/UMS/UMS.conf
    fi

    chown -R ums: /opt/ums-${UMS_VERSION}

    echo add individual folders in '/srv/' to folders and folders_monitored in /opt/ums-${UMS_VERSION}/.config/UMS/UMS.conf
}

function install_local() {
    :
}
