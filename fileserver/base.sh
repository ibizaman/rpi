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

    systemctl start fcron
    systemctl enable fcron
}
