#!/bin/bash

function arguments() {
    :
}

function install_remote() {
	pacman --noconfirm -Syu || exit 1
    pacman --noconfirm --needed -Sy \
           xf86-video-fbturbo \
           xorg-xinput \
           xorg-server \
           xorg-xclock \
           xorg-xinit \
		   || exit 1

    #############
    # Autologin #
    #############

    mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin autologin -s %I 115200,38400,9600 vt102
EOF

    id autologin &>/dev/null || useradd -m autologin

    ########################
    # Launch X on same TTY #
    ########################
    # https://wiki.archlinux.org/index.php/Xinit#xserverrc


su autologin << XSERVERRC
cat <<"EOF" > ~/.xserverrc
#!/bin/sh

exec /usr/bin/Xorg -nolisten tcp "\$@" vt\$XDG_VTNR
EOF
XSERVERRC


su autologin << XINITRC
cat << "EOF" > ~/.xinitrc
#!/bin/sh

userresources=\$HOME/.Xresources
usermodmap=\$HOME/.Xmodmap
sysresources=/etc/X11/xinit/.Xresources
sysmodmap=/etc/X11/xinit/.Xmodmap

# merge in defaults and keymaps

if [ -f \$sysresources ]; then
    xrdb -merge \$sysresources
fi

if [ -f \$sysmodmap ]; then
    xmodmap \$sysmodmap
fi

if [ -f "\$userresources" ]; then
    xrdb -merge "\$userresources"
fi

if [ -f "\$usermodmap" ]; then
    xmodmap "\$usermodmap"
fi

# start some nice programs

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "\$f" ] && . "\$f"
    done
    unset f
fi

xset -dpms

xset s on
xset s noblank

exec /usr/local/bin/autologin-app
EOF
XINITRC

    if [ ! -f /usr/local/bin/autologin-app ]; then
        ln -s /usr/bin/xclock /usr/local/bin/autologin-app
    fi


    #######################
    # Run startx on login #
    #######################

su autologin << BASH_PROFILE
cat <<"EOF" >> ~/.bash_profile
if [ -z "\$DISPLAY" ] && [ -n "\$XDG_VTNR" ] && [ "\$XDG_VTNR" -eq 1 ]; then
    exec startx
fi
EOF
BASH_PROFILE

}

function install_local() {
    :
}
