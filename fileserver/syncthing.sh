function arguments() {
    apikey_key="syncthing/$host/api_key"
    apikey="$(pass $apikey_key)"
    if [ -z "$apikey" ]; then
        apikey="$(pass generate --no-symbols $apikey_key)"
    fi
    [ -z "$apikey" ] && "Could not find nor generate $apikey_key secret" && exit 1

    webuser=syncthing
    webaddress=0.0.0.0:8384
    webpassword_key="syncthing/$host/web_password"
    webpassword="$(pass $webpassword_key)"
    if [ -z "$webpassword" ]; then
        webpassword="$(pass generate --no-symbols $webpassword_key)"
    fi
    [ -z "$webpassword" ] && "Could not find nor generate $webpassword_key secret" && exit 1
    webpassword="$(bcrypt-hash $webpassord -c 10)"

    introducer="$(ls ~/.password-store/syncthing/introducer/ | sed -e 's/\.gpg$//')"
    introducer_id="$(pass syncthing/introducer/$introducer)"
    [ -z "$introducer_id" ] && "Could not find introducer id under syncthing/introducer/" && exit 1
}


function install_remote() {
    pacman -Syu --noconfirm --needed \
        syncthing \
        python \
        || exit 1

    pip3 install --upgrade pip
    pip3 install --upgrade syncthingmanager

    useradd --create-home --home-dir /var/lib/syncthing syncthing

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
    sed -i -e \$'s/\(\(^.*\)<\/gui>\)/\\\\2    <password>$webpassword<\/password>\\\n\\\\1/' .config/syncthing/config.xml
else
    sed -i -e "s/^\( *<password>\).*\(<\/password> *\)$/\1$webpassword\2/" .config/syncthing/config.xml
fi

device_id="\$(cat .config/syncthing/config.xml | grep "$host" | sed -e 's/^.*id="\([^"]*\)".*$/\\1/')"
set +x
echo "Go to $introducer and add this device to it \$device_id."
SYNCTHING

    systemctl daemon-reload
    systemctl restart syncthing@syncthing
    systemctl enable syncthing@syncthing

    sleep 3

    su - syncthing <<SYNCTHING
set -x
stman configure --apikey "$apikey" --name localhost --hostname 127.0.0.1 --default

if stman folder info default | grep -q -v "not configure"; then
    stman folder remove default
fi

if stman device info "$introducer" | grep -q "not configure"; then
    stman device add --name "$introducer" --introducer "$introducer_id"
fi
SYNCTHING
}


function install_local() {
    pip3 install --upgrade pip
    pip3 install --upgrade syncthingmanager
    stman configure --apikey "$apikey" --name "$host" --hostname "$host" --default

    host_id="$(stman --device $host device info $host | grep ID | sed -e 's/^ *ID: *\([A-Z0-9-]*\)$/\1/')"
    stman --device "$introducer" device add --name "$host" "$host_id"
}
