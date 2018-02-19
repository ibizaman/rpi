function arguments() {
    :
}


function run() {
    pacman -Syu --noconfirm --needed \
        base-devel \
        cmake \
        fcron \
        git \
        mdadm \
        netctl \
        python \
        python-pip \
        python2 \
        python2-pip \
        tmux \
        vim \
        || exit 1

    cat <<FCRONTAB | fcrontab -
    # * * * * *
    # | | | | |
    # | | | | +---- Day of the Week   (range: 1-7, 1 standing for Monday)
    # | | | +------ Month of the Year (range: 1-12)
    # | | +-------- Day of the Month  (range: 1-31)
    # | +---------- Hour              (range: 0-23)
    # +------------ Minute            (range: 0-59)

    !erroronlymail(true)
FCRONTAB

    systemctl start fcron
    systemctl enable fcron

}
