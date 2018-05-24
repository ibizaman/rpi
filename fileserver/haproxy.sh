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
}

function install_remote() {
    pacman -Syu --noconfirm --needed \
        certbot \
        fcron \
        haproxy \
        || exit 1

    mkdir -p /etc/haproxy/plugins/haproxy-acme-validation-plugin-0.1.1
    curl -o /etc/haproxy/plugins/haproxy-acme-validation-plugin-0.1.1/acme-http01-webroot.lua \
         https://raw.githubusercontent.com/janeczku/haproxy-acme-validation-plugin/master/acme-http01-webroot.lua

    if [ -f /etc/haproxy/haproxy.cfg ]; then
        cat << HAPROXY > /etc/haproxy/haproxy.cfg
global
    # Load the plugin handling Let's Encrypt request
    lua-load /etc/haproxy/plugins/haproxy-acme-validation-plugin-0.1.1/acme-http01-webroot.lua

    # Silence a warning issued by haproxy. Using 2048
    # instead of the default 1024 makes the connection stronger.
    tune.ssl.default-dh-param  2048

frontend  http
    # Listen on the port 80 for incoming requests, without restriction on
    # incoming ips
    bind *:80

    # Matches all requests where the path is /.well-known/acme-challenge/
    # This match can be referred to using the name url_acme_http01 for the rest
    # of the configuration
    acl url_acme_http01  path_beg       /.well-known/acme-challenge/

    # All GET requests matching the acl above are handled by the plugin
    http-request use-service lua.acme-http01 if METH_GET url_acme_http01

frontend  https
    # Listen on port 443, the default https port and fetch the
    # certificates inside the /etc/ssl/my_cert directory
    bind *:443 ssl crt /etc/ssl/my_cert/
HAPROXY
    fi

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

    systemctl restart haproxy
    systemctl enable haproxy

    part="/usr/local/bin/haproxy-ssl-renew $host.$domain"
    line="10 4 1 */3 * /usr/local/bin/haproxy-ssl-renew $host.$domain"
    if ! fcrontab -l 2>/dev/null | grep -q "$part"; then
        (fcrontab -l; echo "$line") | fcrontab -
    fi
    set +x

    fcrondyn -x ls | grep "$part" | cut -d ' ' -f 1 | xargs -I . fcrondyn -x "runnow ."

    pip install --upgrade haproxysubdomains
}

function install_local() {
    :
}
