#!/bin/bash

function arguments() {
    if [ -z "$host" ]; then
        help_args="$help_args HOST"
        host="$1"
        available_hosts="$(ls ~/.password-store/server-passwords)"
        if [ -z "$host" ] || ! contains "$available_hosts" "$host"; then
            echo "$help_args DOMAIN ARIA2_DEFAULT_DOWNLOAD_PATH"
            echo "HOST must be one of:"
            echo "$available_hosts"
            exit 1
        fi
        shift
    fi

    domain="$1"
    available_domains="$(ls -d ~/.password-store/mailgun.com/mg.* | xargs -n1 basename | cut -d '.' -f 2-)"
    if [ -z "$domain" ] || ! contains "$available_domains" "$domain"; then
        echo "$help_args DOMAIN ARIA2_DEFAULT_DOWNLOAD_PATH"
        echo "DOMAIN must be one of:"
        echo "$available_domains"
        exit 1
    fi
    shift

    aria2_default_download_path="$1"
    if [ -z "$aria2_default_download_path" ]; then
        echo "$help_args DOMAIN ARIA2_DEFAULT_DOWNLOAD_PATH"
        echo "ARIA2_DEFAULT_DOWNLOAD_PATH cannot be empty"
        exit 1
    fi
    shift

    aria2_secret_key="aria2/$host.secret"
    aria2_secret="$(pass $aria2_secret_key)"
    if [ -z "$aria2_secret" ]; then
        aria2_secret="$(pass generate --no-symbols $aria2_secret_key)"
    fi
    [ -z "$aria2_secret" ] && "Could not find nor generate $aria2_secret_key secret" && exit 1
}


function install_remote() {
    pacman -Syu --noconfirm --needed \
        aria2 \
        git \
        nodejs \
        || exit 1

    cd /opt/ || exit 1

    if ! grep aria2 /etc/iproute2/rt_tables; then
        echo -e "\n10 aria2" >> /etc/iproute2/rt_tables
    fi

    git clone https://github.com/ziahamza/webui-aria2.git || (cd webui-aria2 && git pull)
    sed -i "s|// token: '\$YOUR_SECRET_TOKEN\$'|  token: '$aria2_secret'|" /opt/webui-aria2/src/js/services/configuration.js

    groupadd --system downloader
    useradd --create-home --home-dir /var/lib/aria2 --groups downloader aria2
    su - aria2 <<ARIA2
touch session.lock
ARIA2

    mkdir -p /etc/aria2

    mkdir -p "$aria2_default_download_path"
    chown aria2:aria2 "$aria2_default_download_path"

    cat > /etc/aria2/aria2.conf <<ARIA2CONF
dir=$aria2_default_download_path
rpc-secret=$aria2_secret
ARIA2CONF

    cat > /etc/systemd/system/aria2.service <<ARIA2SERVICE
[Unit]
Description=Aria2 Service
After=openvpn-client@privateinternetaccess.service

[Service]
User=aria2
Group=aria2
ExecStart=/usr/bin/aria2c \\
              --enable-rpc \\
              --rpc-allow-origin-all \\
              --async-dns=false  \\
              --interface=tun0 \\
              --bt-lpd-interface wlan0 \\
              --save-session /var/lib/aria2/session.lock \\
              --input-file /var/lib/aria2/session.lock \\
              --conf-path=/etc/aria2/aria2.conf \\
              --continue

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

    cat << ARIA2ROUTEUP > /etc/openvpn/client/privateinternetaccess/conf_up/aria2_up.sh
#! /bin/bash

set -x

# add the vpn device as default route for this routing table
ip route add default via \$route_vpn_gateway dev \$dev table aria2

# add rules that all traffic going to the gateway as well as
# all traffic comming from my local VPN is routed through the
# VPN's gateway
ip rule add from \$ifconfig_local/32 table aria2
ip rule add to \$route_vpn_gateway/32 table aria2

# and flush the cache to make sure that the changes were commited
ip route flush cache

iptables -A OUTPUT -o wlan0 -m owner --uid-owner \$(id -u aria2) -j DROP
iptables -A OUTPUT -o eth0 -m owner --uid-owner \$(id -u aria2) -j DROP
exit 0
ARIA2ROUTEUP
    chmod a+x /etc/openvpn/client/privateinternetaccess/conf_up/aria2_up.sh

    cat << ARIA2ROUTEDOWN > /etc/openvpn/client/privateinternetaccess/conf_down/aria2_down.sh
#! /bin/bash

set -x

# add the vpn device as default route for this routing table
ip route del default via \$route_vpn_gateway dev \$dev table aria2

# add rules that all traffic going to the gateway as well as
# all traffic comming from my local VPN is routed through the
# VPN's gateway
ip rule del from \$ifconfig_local/32 table aria2
ip rule del to \$route_vpn_gateway/32 table aria2

# and flush the cache to make sure that the changes were commited
ip route flush cache

iptables -D OUTPUT -o wlan0 -m owner --uid-owner \$(id -u aria2) -j DROP
iptables -D OUTPUT -o eth0 -m owner --uid-owner \$(id -u aria2) -j DROP
exit 0
ARIA2ROUTEDOWN
    chmod a+x /etc/openvpn/client/privateinternetaccess/conf_down/aria2_down.sh

    systemctl restart openvpn-client@privateinternetaccess

#    cat > /etc/systemd/system/elm-torrent.service <<ELMTORRENT
#[Unit]
#Description=Elm Torrent
#After=network.target
#
#[Service]
#User=elm-torrent
#Group=elm-torrent
#WorkingDirectory=/opt/elm-torrent
#ExecStart=/usr/bin/node /opt/elm-torrent/node-server.js
#
#[Install]
#WantedBy=default.target
#ELMTORRENT

#    chown -R elm-torrent: /opt/elm-torrent
#    useradd --home-dir /opt/elm-torrent elm-torrent

    pip install --upgrade jsondispatch
    useradd --system jsondispatch

    cat > /etc/jsondispatch/jsondispatch.yaml <<YAML
cors:
  domain: '*'

commands:
  aria2:
    url: http://127.0.0.1:6800/jsonrpc
    rpc_secret: $aria2_secret

triggers:
  download_movie_uri:
    - command: aria2
      method: addUri
      arguments:
        url: \$url
        dir: /srv/movies

  download_serie_uri:
    - command: aria2
      method: addUri
      arguments:
        url: \$url
        dir: /srv/series
YAML

    cat > /etc/systemd/system/jsondispatch.service <<JSONDISPATCH
[Unit]
Description=jsondispatch service
After=network.target

[Service]
User=jsondispatch
Group=jsondispatch
ExecStart=/usr/bin/jsondispatch

[Install]
WantedBy=default.target
JSONDISPATCH

    systemctl daemon-reload
    systemctl restart aria2
    systemctl restart aria2web
    systemctl restart jsondispatch
    systemctl enable aria2
    systemctl enable aria2web
    systemctl enable jsondispatch

    # aria2web
    haproxysubdomains add /etc/haproxy/haproxy.cfg https "$domain" aria2 8888
    systemctl reload haproxy

    # jsondispatch
    upnpport configure /etc/upnpport/upnpport.yaml add 8850
    systemctl reload upnpport

    echo You can find the secret token in /opt/webui-aria2/src/js/services/configuration.js
}

function install_local() {
    :
}
