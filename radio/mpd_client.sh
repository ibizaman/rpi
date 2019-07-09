#!/bin/bash

function arguments() {
    :
}

function install_remote() {
    pacman --noconfirm --needed -Sy \
           mpd \
           || exit 1

    # https://www.musicpd.org/doc/html/user.html#satellite-setup

    cat <<EOF > /etc/mpd.conf
# See: /usr/share/doc/mpd/mpdconf.example

pid_file "/run/mpd/mpd.pid"
playlist_directory "/var/lib/mpd/playlists"
state_file "/var/lib/mpd/mpdstate"
sticker_file "/var/lib/mpd/sticker"

music_directory "nfs://arsenic/srv/music"

zeroconf_enabled "yes"
zeroconf_name "mpd@timusic"

max_connections "5"

port "6600"

database {
    plugin "proxy"
    host "arsenic"
    port "6600"
}

audio_output {
    type "alsa"
    name "ALSA sound card"
}
EOF

    # test mpd with:
    # mpd --no-daemon --stderr --verbose

    systemctl restart mpd
    systemctl enable mpd
}

function install_local() {
    :
}
