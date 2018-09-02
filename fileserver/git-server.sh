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

    git_storage_path="$1"
    if [ -z "$git_storage_path" ]; then
        echo "$help_args GIT_STORAGE_PATH"
        echo "GIT_STORAGE_PATH cannot be empty"
        exit 1
    fi
    shift
}


function install_remote() {
    pacman -Syu --noconfirm --needed \
        git \
        || exit 1

    mkdir -p $git_storage_path || exit 1
    chown alarm:alarm $git_storage_path
}

function install_local() {
    :
}
