#!/bin/bash

function arguments() {
    :
}


function run() {
    pacman -Syu --noconfirm --needed \
        aria2 \
        git \
        nodejs \
        || exit 1

    cd /opt/

    git clone https://github.com/ziahamza/webui-aria2.git || (cd webui-aria2 && git pull)

    sed -i s/\\\$YOUR_SECRET_TOKEN\\\$/$aria2_secret/ /opt/webui-aria2/configuration.js

    groupadd --system downloader
    useradd --create-home --home-dir /var/lib/aria2 --groups downloader aria2
    su - aria2 <<ARIA2
    touch session.lock
    ARIA2

    mkdir -p /etc/aria2

    cat > /etc/aria2/aria2.conf <<ARIA2CONF
    dir=$aria2_default_download_path
    rpc-secret=$aria2_secret
    ARIA2CONF

    cat > /etc/systemd/system/aria2.service <<ARIA2SERVICE
    [Unit]
    Description=Aria2 Service
    After=network.target

    [Service]
    User=aria2
    Group=aria2
    ExecStart=/usr/bin/aria2c --enable-rpc --rpc-listen-all --rpc-allow-origin-all --save-session /var/lib/aria2/session.lock --input-file /var/lib/aria2/session.lock --conf-path=/etc/aria2/aria2.conf

    [Install]
    WantedBy=default.target
    ARIA2SERVICE

    cat > /etc/systemd/system/aria2web.service <<ARIA2WEBSERVICE
    [Unit]
    Description=Aria2 Web Service
    After=network.target

    [Service]
    User=aria2
    Group=aria2
    WorkingDirectory=/opt/webui-aria2
    ExecStart=/usr/bin/node /opt/webui-aria2/node-server.js

    [Install]
    WantedBy=default.target
    ARIA2WEBSERVICE

    chown -R aria2: /opt/webui-aria2

    systemctl enable aria2
    systemctl enable aria2web

    echo You can find the secret token in /opt/webui-aria2/configuration.js
}
