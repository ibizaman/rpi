#!/bin/bash

function arguments() {
    :
}

function install_remote() {
    pacman --noconfirm --needed -Sy \
           base-devel \
           git \

    mount -o remount,rw / || exit 1

    # /boot/config.txt
    if ! grep --quiet hdmi_force_hotplug=1 /boot/config.txt; then
        echo hdmi_force_hotplug=1 >> /boot/config.txt
    fi

    if ! grep --quiet dtparam=i2c_arm=on /boot/config.txt; then
        echo dtparam=i2c_arm=on >> /boot/config.txt
    fi

    if ! grep --quiet enable_uart=1 /boot/config.txt; then
        echo enable_uart=1 >> /boot/config.txt
    fi

    if ! grep --quiet dtparam=audio=on /boot/config.txt; then
        echo dtparam=audio=on >> /boot/config.txt
    fi

    if ! grep --quiet dtoverlay=waveshare35a:rotate=90,swapxy=1 /boot/config.txt; then
        echo dtoverlay=waveshare35a:rotate=90,swapxy=1 >> /boot/config.txt
    fi

    if ! grep --quiet display_rotate=0 /boot/config.txt; then
        echo display_rotate=0 >> /boot/config.txt
    fi

    cd /opt || exit 1
    if [ ! -f xinput_calibrator/.done ]; then
        git clone https://github.com/tias/xinput_calibrator
        pushd xinput_calibrator/ || exit 1
        ./autogen.sh
        make
        make install
        touch .done
        popd || exit 1
    fi
    if [ ! -d LCD-show ]; then
        curl -A "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:59.0) Gecko/20100101 Firefox/59.0" \
             -L \
             -O https://www.waveshare.com/w/upload/0/00/LCD-show-170703.tar.gz
        if ! tar -xf LCD-show-170703.tar.gz; then
            cat LCD-show-170703.tar.gz
            exit 1
        fi
    fi

cat <<CALIBRATION > /usr/share/X11/xorg.conf.d/99-calibration.conf
Section "InputClass"
        Identifier      "calibration"
        MatchProduct    "ADS7846 Touchscreen"
        Option	"TransformationMatrix"	"-1.13 0 1.08 0 1.16 -0.09 0 0 1"
EndSection
CALIBRATION

cat <<FBTURBO > /usr/share/X11/xorg.conf.d/99-fbturbo.conf
Section "Device"
        Identifier      "Allwinner A10/A13 FBDEV"
        Driver          "fbturbo"
        Option          "fbdev" "/dev/fb1"

        Option          "SwapbuffersWait" "true"
EndSection
FBTURBO

    if [ ! -f /boot/cmdline.txt.orig ]; then
        cp /boot/cmdline.txt /boot/cmdline.txt.orig
    fi
cat <<CMDLINE > /boot/cmdline.txt
root=/dev/mmcblk0p2 rw rootwait console=ttyAMA0,115200 console=tty1 selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 kgdboc=ttyAMA0,115200 elevator=deadline fbcon=map:10 fbcon=font:ProFont6x11 logo.nologo
CMDLINE

    cp -f LCD-show/waveshare35a-overlay.dtb /boot/overlays/waveshare35a.dtbo
    cp -f LCD-show/waveshare35a-overlay.dtb /boot/overlays/
    cp -f LCD-show/inittab /etc/
}

function install_local() {
    :
}
