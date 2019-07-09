#!/bin/bash

function arguments() {
    :
}

function install_remote() {
    pacman --noconfirm --needed -Sy \
           alsa-firmware \
           alsa-lib \
           alsa-plugins \
           alsa-utils \
           pulseaudio \


    # To avoid:
    # Failed to acquire org.pulseaudio.Server:
    # org.freedesktop.DBus.Error.AccessDenied: Connection ":1.1329" is
    # not allowed to own the service "org.pulseaudio.Server" due to
    # security policies in t>

    cat <<EOF > /etc/dbus-1/system.d/pulseaudio-system-wide.conf
<!DOCTYPE busconfig PUBLIC
  "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
  "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <policy user="pulse">
    <allow own="org.pulseaudio.Server"/>
    <allow send_destination="org.freedesktop.Hal" send_interface="org.freedesktop.Hal.Manager"/>
    <allow send_destination="org.freedesktop.Hal" send_interface="org.freedesktop.Hal.Device"/>
  </policy>
  <policy user="root">
    <allow own="org.pulseaudio.Server"/>
  </policy>
  <policy context="default">
    <allow own="org.pulseaudio.Server"/>
  </policy>
</busconfig>
EOF

    cat <<EOF > /usr/lib/systemd/system/pulseaudio.service
[Unit]
Description=PulseAudio Sound Server
#Requires=avahi-daemon.service

[Service]
Type=simple
PIDFile=/var/run/pulse/pid
ExecStart=/usr/bin/pulseaudio \\
            --system \\
            --disallow-module-loading=1 \\
            --disallow-exit=1 \\
            --disable-shm=1 \\
            --fail=1 \\
            --daemonize=no

[Install]
WantedBy=multi-user.target
EOF

    cat <<EOF > /etc/pulse/daemon.conf
exit-idle-time=0

# ffmpeg is a compromise in quality that runs okay on a Raspberry Pi 1. Consider
# using a more accurate (default?) resampling method when we have more processor
# power, e.g. a Raspberry Pi 2.
resample-method = ffmpeg
enable-remixing = no
enable-lfe-remixing = no
default-sample-format = s16le
default-sample-rate = 44100
default-sample-channels = 2
EOF

    cat <<EOF > /etc/pulse/system.pa
#!/usr/bin/pulseaudio -nF

# This startup script is used only if PulseAudio is started in system
# mode.


# ### Automatically load driver modules depending on the hardware available
# .ifexists module-udev-detect.so
# load-module module-udev-detect
# .else
# ### Use the static hardware detection module (for systems that lack udev/hal support)
# load-module module-detect
# .endif

# Automatic detection doesn't seem to work so we're hardcoding instead
# https://partofthething.com/thoughts/multi-room-audio-over-wi-fi-with-pulseaudio-and-raspberry-pis/
load-module module-alsa-sink device="default" tsched=1

### Load several protocols
.ifexists module-esound-protocol-unix.so
load-module module-esound-protocol-unix
.endif
load-module module-native-protocol-unix

### Automatically restore the volume of streams and devices
load-module module-stream-restore
load-module module-device-restore

### Automatically restore the default sink/source when changed by the user
### during runtime
### NOTE: This should be loaded as early as possible so that subsequent modules
### that look up the default sink/source get the right value
load-module module-default-device-restore

### Automatically move streams to the default sink if the sink they are
### connected to dies, similar for sources
load-module module-rescue-streams


### Accept connections from LAN.
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;192.168.1.0/24 auth-anonymous=1


### Make sure we always have a sink around, even if it is a null sink.
load-module module-always-sink

### Automatically suspend sinks/sources that become idle for too long
load-module module-suspend-on-idle

### Enable positioned event sounds
load-module module-position-event-sounds
EOF

    systemctl --user --global disable pulseaudio.socket
    systemctl --user --global disable pulseaudio

    groupadd --system pulse
    useradd -r pulse \
            -d /var/run/pulse \
            -g pulse \
            -G audio \
            -c "PulseAudio" \
            -s /bin/false

    systemctl restart pulseaudio
    systemctl enable pulseaudio
}

function install_local() {
    :
}
