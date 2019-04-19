#!/bin/bash

function arguments() {
    if [ -z "$host" ]; then
        help_args="$help_args HOST"
        host="$1"
        available_hosts="$(ls ~/.password-store/server-passwords)"
        if [ -z "$host" ] || ! contains "$available_hosts" "$host"; then
            echo "$help_args HOST"
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
}

function install_remote() {
    pip3 uninstall --yes pbr

    pacman -Sy --noconfirm --needed \
        certbot \
        haproxy \
        || exit 1

    pip3 install pbr

    mkdir -p /etc/haproxy/plugins/haproxy-acme-validation-plugin-0.1.1
    curl -o /etc/haproxy/plugins/haproxy-acme-validation-plugin-0.1.1/acme-http01-webroot.lua \
         https://raw.githubusercontent.com/janeczku/haproxy-acme-validation-plugin/master/acme-http01-webroot.lua

    sed 's|\["non_chroot_webroot"\] = .*$|["non_chroot_webroot"] = "/var/lib/haproxy"|' \
        -i /etc/haproxy/plugins/haproxy-acme-validation-plugin-0.1.1/acme-http01-webroot.lua

    mkdir -p /etc/systemd/system/haproxy.service.d/
    cat <<SERVICE > /etc/systemd/system/haproxy.service.d/10-env_configs.conf
[Service]
Environment="CONFIG=/etc/haproxy/configs"
SERVICE

    mkdir -p /etc/haproxy/configs
    mkdir -p /var/lib/haproxy
    chown haproxy: /var/lib/haproxy

    cat << HAPROXY > /etc/haproxy/configs/00-global.cfg
global
    # Load the plugin handling Let's Encrypt request
    lua-load /etc/haproxy/plugins/haproxy-acme-validation-plugin-0.1.1/acme-http01-webroot.lua

    # Silence a warning issued by haproxy. Using 2048
    # instead of the default 1024 makes the connection stronger.
    tune.ssl.default-dh-param  2048

    maxconn 20000

    user haproxy
    group haproxy

    log /dev/log local0 info


defaults
    log global
    option httplog

    timeout connect         10s
    timeout client          1m
    timeout server          1m


frontend http-to-https
    mode http
    bind *:80
    redirect scheme https code 301 if !{ ssl_fc }
HAPROXY

    cat << HAPROXY > /etc/haproxy/configs/10-acme-challenge.cfg
frontend acme-challenge
    mode http

    bind *:80

    acl url_acme_http01 path_beg /.well-known/acme-challenge/

    http-request use-service lua.acme-http01 if METH_GET url_acme_http01
HAPROXY

    # Example configuration with https:
    #
    #    frontend  https
    #        # Listen on port 443, the default https port and fetch the
    #        # certificates inside the /etc/ssl/my_cert directory
    #        bind *:443 ssl crt /etc/ssl/my_cert/
    #
    #        default_backend default
    #
    #    backend default
    #        server default 127.0.0.1:8888

    cat << RENEW > /usr/local/bin/haproxy-ssl-renew
#!/bin/bash

# Stop the whole script on first error
set -e

# Path to the letsencrypt-auto tool
LE_TOOL=/usr/bin/certbot

# Directory where the acme client puts the generated certs
LE_OUTPUT=/etc/letsencrypt/live

# Directory where the certificates will be stored for haproxy to find them
DEST_DIR="/etc/ssl/my_cert/"
mkdir -p "\$DEST_DIR"

# Concat the requested domains
DOMAINS=""
for DOM in "\$@"
do
    DOMAINS+=" -d \$DOM"
done

# Create or renew certificate for the domain(s) supplied for this tool
# The parenthesis make the script run in a subshell, this is needed so it doesn't mangle \$@
(\$LE_TOOL certonly --text --agree-tos --renew-by-default --webroot --webroot-path /usr/share/haproxy -m ibizapeanut@gmail.com \$DOMAINS)

# Merge and copy the certificates to the destination directory
for DOM in "\$@"
do
    cat \$LE_OUTPUT/\$DOM/fullchain.pem \$LE_OUTPUT/\$DOM/privkey.pem > \$DEST_DIR/\$DOM.pem
done
RENEW
    chmod a+x /usr/local/bin/haproxy-ssl-renew

    systemctl reload-or-restart haproxy
    systemctl enable haproxy

    part="/usr/local/bin/haproxy-ssl-renew $host.$domain"
    line="@ 2m /usr/local/bin/haproxy-ssl-renew $host.$domain"
    if ! fcrontab -l 2>/dev/null | grep -q "$part"; then
        (fcrontab -l; echo "$line") | fcrontab -
    fi
    set +x

    fcrondyn -x ls | grep "$part" | cut -d ' ' -f 1 | xargs -I . fcrondyn -x "runnow ."

    upnpport configure /etc/upnpport/upnpport.yaml add 80
    upnpport configure /etc/upnpport/upnpport.yaml add 443
    systemctl reload upnpport
}

function install_local() {
    :
}
