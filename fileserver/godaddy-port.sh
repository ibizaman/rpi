#!/bin/bash

function arguments() {
    if [ -z "$host" ]; then
        help_args="$help_args HOST"
        host="$1"
        available_hosts="$(ls ~/.password-store/server-passwords)"
        if [ -z "$host" ] || ! contains "$available_hosts" "$host"; then
            echo "$help_args DOMAIN"
            echo "HOST must be one of:"
            echo "$available_hosts"
            exit 1
        fi
        shift
    fi

    domain="$1"
    available_domains="$(ls -d ~/.password-store/mailgun.com/mg.* | xargs -n1 basename | cut -d '.' -f 2-)"
    if [ -z "$domain" ] || ! contains "$available_domains" "$domain"; then
        echo "$help_args DOMAIN"
        echo "DOMAIN must be one of:"
        echo "$available_domains"
        exit 1
    fi
    shift

    godaddy_key="$(pass godaddy.com/api_keys/"$host")"
    godaddy_secret="$(pass godaddy.com/api_keys/"$host".secret)"
    [ -z "$godaddy_key" ] && echo "Add one in https://developer.godaddy.com/keys/ for $host" && exit 1
    [ -z "$godaddy_secret" ] && echo "Add one in https://developer.godaddy.com/keys/ for $host" && exit 1
}

function install_remote() {
    pacman --needed --noconfirm -S \
        fcron \
        python \
        python-pip

    pip install --upgrade godaddyip
    useradd --system godaddyip
    cat > /etc/systemd/system/godaddyip.service <<GODADDYIP
[Unit]
Description=Godaddyip service
After=network.target

[Service]
User=godaddyip
Group=godaddyip
ExecStart=/usr/bin/godaddyip run
ExecReload=/bin/kill -s usr1 \$MAINPID

[Install]
WantedBy=default.target
GODADDYIP

    godaddyip configure /etc/godaddyip/godaddyip.yaml key "$godaddy_key"
    godaddyip configure /etc/godaddyip/godaddyip.yaml secret "$godaddy_secret"
    godaddyip configure /etc/godaddyip/godaddyip.yaml arecord "$host"
    godaddyip configure /etc/godaddyip/godaddyip.yaml domain "$domain"

    systemctl daemon-reload
    systemctl restart godaddyip
    systemctl enable godaddyip

    upnpport configure /etc/upnpport/upnpport.yaml add 22
    systemctl reload upnpport
}

function install_local() {
    if ! grep "^Host $host\$" ~/.ssh/config; then
        cat << CONFIG >> ~/.ssh/config

Host $host
    Hostname $host.$domain
    User $user
    IdentityFile ~/.ssh/$host-$user
CONFIG
    fi
}
