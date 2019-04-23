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

    smtp_hostname="$(pass mailgun.com/mg."$domain"/smtp_hostname)"
    smtp_login="$(pass mailgun.com/mg."$domain"/smtp_login)"
    smtp_password="$(pass mailgun.com/mg."$domain"/password)"
    [ -z "$smtp_hostname" ] && echo "Missing smtp_hostname for $domain" && exit 1
    [ -z "$smtp_login" ] && echo "Missing smtp_login for $domain" && exit 1
    [ -z "$smtp_password" ] && echo "Missing smtp_password for $domain" && exit 1
}

function install_remote() {
    [ -z "$smtp_hostname" ] && echo "Missing smtp_hostname for $domain" && exit 1
    pacman --needed --noconfirm -S \
        git \
        msmtp \
        msmtp-mta \
        || exit 1

    touch /etc/msmtprc
    chmod 644 /etc/msmtprc

    cat << MSMTPRC > /etc/msmtprc
defaults
tls on
tls_trust_file  /etc/ssl/certs/ca-certificates.crt
logfile         /var/log/msmtp.log
aliases         /etc/aliases

account         mailgun
host            $smtp_hostname
port            587
auth            on
user            $smtp_login
password        $smtp_password
from            $host@$domain

account default : mailgun
MSMTPRC

    cat << MAILRC > /etc/mail.rc
set sendmail=/usr/bin/msmtp
MAILRC

    cat << ALIASES > /etc/aliases
default: ibizapeanut@gmail.com
ALIASES

    touch /var/log/msmtp.log
    chmod 666 /var/log/msmtp.log

    echo "hello there username." | msmtp -a default ibizapeanut@gmail.com
}

function install_local() {
    :
}
