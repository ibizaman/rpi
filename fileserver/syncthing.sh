#!/bin/bash

function arguments() {
    apikey="$(get_or_create_pass "syncthing/$host/api_key")"
    [ -z "$apikey" ] && "Could not find nor generate $apikey_key secret" && exit 1

    webuser=syncthing
    webaddress=0.0.0.0:8384
    webpassword="$(get_or_create_pass "syncthing/$host/web_password")"
    [ -z "$webpassword" ] && "Could not find nor generate $webpassword secret" && exit 1
    webpassword_bcrypt="$(printf "%s\n" "$webpassword" "$webpassword" | bcrypt-cli hash -c 10 | tail -n1)"

    introducer="$(ls ~/.password-store/syncthing/introducer/ | sed -e 's/\.gpg$//')"
    introducer_id="$(pass syncthing/introducer/$introducer)"
    [ -z "$introducer_id" ] && "Could not find introducer id under syncthing/introducer/" && exit 1
}


function install_remote() {
    pacman -Syu --noconfirm --needed \
        syncthing \
        || exit 1

    useradd --create-home --home-dir /var/lib/syncthing syncthing

    # TODO: we could move all sed lines out of the heredoc
    su - syncthing <<SYNCTHING
set -x
if ! [ -d .config/syncthing ]; then
    syncthing -generate=.config/syncthing
fi

sed -i -e "s/^\( *<address>\).*:8384\(<\/address> *\)$/\1$webaddress\2/" .config/syncthing/config.xml

sed -i -e "s/^\( *<apikey>\).*\(<\/apikey> *\)$/\1$apikey\2/" .config/syncthing/config.xml

if ! grep -q "<user>" .config/syncthing/config.xml; then
    sed -i -e \$'s/\(\(^.*\)<\/gui>\)/\\\\2    <user>$webuser<\/user>\\\n\\\\1/' .config/syncthing/config.xml
else
    sed -i -e "s/^\( *<user>\).*\(<\/user> *\)$/\1$webuser\2/" .config/syncthing/config.xml
fi

if ! grep -q "<password>" .config/syncthing/config.xml; then
    sed -i -e \$'s/\(\(^.*\)<\/gui>\)/\\\\2    <password>$webpassword_bcrypt<\/password>\\\n\\\\1/' .config/syncthing/config.xml
else
    sed -i -e "s/^\( *<password>\).*\(<\/password> *\)$/\1$webpassword_bcrypt\2/" .config/syncthing/config.xml
fi
SYNCTHING

    cat <<HAPROXY > /etc/haproxy/configs/40-syncthing.cfg
frontend syncthing
    mode http

    bind *:443 ssl crt /etc/ssl/my_cert/
    http-request add-header X-Forwarded-Proto https

    acl acl_syncthing path_beg /syncthing
    use_backend syncthing if acl_syncthing

backend syncthing
    mode http

    option forwardfor

    http-request replace-path ^([^\ :]*)\ /syncthing/?(.*)     \1\ /\2

    server syncthing1 127.0.0.1:8384
HAPROXY

    systemctl daemon-reload
    systemctl restart syncthing@syncthing
    systemctl enable syncthing@syncthing

    upnpport configure /etc/upnpport/upnpport.yaml add 8384
    systemctl reload upnpport
}


function install_local() {
    pip3 install --upgrade pip || exit 1
    pip3 install --upgrade syncthingmanager || exit 1


    stman configure --apikey "$apikey" --name "$host" --hostname "$host" --default || exit 1

    if stman --device "$host" folder info default | grep -q -v "not configure"; then
        stman --device "$host" folder remove default
    fi

    if stman --device "$host" device info "$introducer" | grep -q "not configure"; then
        stman --device "$host" device add --name "$introducer" --introducer "$introducer_id"
    fi

    host_id="$(stman --device $host device info $host | grep ID | sed -e 's/^ *ID: *\([A-Z0-9-]*\)$/\1/')" || exit 1
    stman --device "$introducer" device add --name "$host" "$host_id" || exit 1
}
