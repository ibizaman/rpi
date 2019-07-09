#!/bin/bash

function arguments() {
    :
}

# TODO: do not hardcode base/timusic

function install_remote() {
    pacman --noconfirm --needed -Sy \
           mpd \
           || exit 1

    # Access to music files in /srv/music
    usermod -aG music mpd

    cat <<EOF > /etc/mpd.conf
# See: /usr/share/doc/mpd/mpdconf.example

pid_file "/run/mpd/mpd.pid"
playlist_directory "/var/lib/mpd/playlists"
state_file "/var/lib/mpd/mpdstate"
sticker_file "/var/lib/mpd/sticker"

music_directory "/srv/music"

zeroconf_enabled "yes"
zeroconf_name "mpd@arsenic"

max_connections "5"

port "6600"

database {
    plugin "simple"
    path "/var/lib/mpd/db"
    cache_directory "/var/lib/mpd/cache"
}

audio_output {
    type          "pulse"
    name          "base"
    server        "timusic"
}
EOF

    # test mpd with:
    # mpd --no-daemon --stderr --verbose

    systemctl restart mpd || journalctl --unit mpd
    systemctl enable mpd

    # Only needed for mpd_client.sh, not mpd_client_pulse.sh
    if ! grep --quiet "/srv/music" /etc/exports; then
        echo "/srv/music 192.168.1.0/24(rw,sync,insecure,no_subtree_check)" >> /etc/exports

        systemctl restart nfs-server

        exportfs -arv
    fi
}

function install_local() {
    :
}
