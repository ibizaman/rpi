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

    pushd /opt

    if ! [ -d mFPN-organizer ]; then
        git clone https://github.com/ibizaman/mFPN-organizer.git
    else
        (cd mFPN-organizer; git pull)
    fi

    if ! [ -d mFPN-organizer-venv ]; then
        python -m venv mFPN-organizer-venv
    fi

    ./mFPN-organizer-venv/bin/pip install \
        docopt \
        PyYAML \
        requests

    mkdir -p /etc/mFPN-organizer/network
    chmod 700 -R /etc/mFPN-organizer

    cat <<- MYIP > /etc/mFPN-organizer/network/myip.conf
ip:
    upnpc: true
    ipify: true

godaddy:
    enable:  true
    name:    $host
    key:     $godaddy_key
    secret:  $godaddy_secret
    domain:  $domain

/* vim: set ts=8 sw=4 tw=0 noet syn=yaml :*/
MYIP

    part="/opt/mFPN-organizer/network/myip.py"
    line="@ 5  /opt/mFPN-organizer-venv/bin/python $part -c /etc/mFPN-organizer/network/myip.conf"
    if ! fcrontab -l 2>/dev/null | grep -q "$part"; then
        (fcrontab -l; echo "$line") | fcrontab -
    fi

    upnpport configure /etc/upnpport/upnpport.yaml add 22
    systemctl reload upnpport

    popd
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
