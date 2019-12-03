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
}


function install_remote() {
    pacman -Syu --noconfirm --needed \
           avahi \
           base-devel

    mkdir -p /srv/nfs/backup
    mkdir -p /srv/nfs/pictures

    mount --bind /srv/backup /srv/nfs/backup
    mount --bind /srv/pictures /srv/nfs/pictures

    cat > /etc/nfs.conf <<EOF
EOF

    cat >> /etc/fstab <<EOF
/srv/pictures /srv/nfs/pictures  none  bind  0 0
EOF

    cat > /etc/exports <<EOF
# Use exportfs -arv to reload.

/srv          192.168.1.0/24(rw,sync,insecure,no_subtree_check,crossmnt,fsid=0)
/srv/backup   192.168.1.0/24(rw,sync,insecure,no_subtree_check)
/srv/pictures 192.168.1.0/24(rw,sync,insecure,no_subtree_check)
EOF

    systemctl restart nfs-server

    exportfs -arv


    cat > /etc/systemd/resolved.conf <<EOF
MulticastDNS=no
EOF

    systemctl restart systemd-resolved


    pushd /opt || exit 1
    # rm -rf netatalk
    # curl -LO https://aur.archlinux.org/cgit/aur.git/snapshot/netatalk.tar.gz || exit 1
    # tar -xf netatalk.tar.gz || exit 1
    chown -R timi netatalk
    sudo su - timi || exit 1 <<EOF
cd /opt/netatalk || exit 1
makepkg -si || exit 1
EOF

    cat > /etc/afp.conf <<EOF
[Global]
 mimic model = TimeCapsule6,106
 log level = default:warn
 hosts allow = 192.168.1.0/24

[Homes]
 basedir regex = /home

[Pictures]
 path = /srv/pictures
 ea = none

[Music]
 path = /srv/music
EOF

    systemctl restart netatalk


    cat > /etc/avahi/services/nfs.service <<EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">NFS Pictures Share on %h</name>
  <service>
    <type>_nfs._tcp</type>
    <port>2049</port>
    <txt-record>path=/srv/pictures</txt-record>
  </service>
</service-group>
EOF

    systemctl restart avahi-daemon

    systemctl enable nfs-server
    systemctl enable netatalk
    systemctl enable avahi-daemon
}

function install_local() {
    :
}
