#!/bin/bash

contains() {
    [[ $1 =~ (^|[[:space:]])$2($|[[:space:]]) ]]
}

if ! ls ~/.password-store >/dev/null 2>&1; then
    echo "Stopping swap and opening pass:"
    sudo swapoff -a && pass open || exit 1
fi

host="$1"
available_hosts="$(ls ~/.password-store/server-passwords)"
if [ -z "$host" ] || ! contains "$available_hosts" "$host"; then
    echo "$0 HOST INSTALL_USER FILE [ARG...]"
    echo "HOST must be one of:"
    echo "$available_hosts"
    exit 1
fi
shift

user="$1"
available_users="$(ls ~/.password-store/server-passwords/"$host" | cut -d '.' -f 1 | grep -v root)"
if [ -z "$user" ] || ! contains "$available_users" "$user"; then
    echo "$0 HOST INSTALL_USER FILE [ARG...]"
    echo "INSTALL_USER must be one of:"
    echo "$available_users"
    exit 1
fi
user_password="$(pass server-passwords/"$host"/"$user" | xargs -0 echo -n)"
shift

file="$1"
available_files="$(find . -mindepth 2 -type f -name '*.sh' -printf '%P\n' | sort)"
if [ -z "$file" ] || ! contains "$available_files" "$file"; then
    echo "$0 HOST INSTALL_USER FILE [ARG...]"
    echo "FILE must be one of:"
    echo "$available_files"
    exit 1
fi
shift

source "$file"
arguments "$@"

ssh "$user@$host" 'bash -s' <<EOF
sudo -S bash << SUDO
$user_password
echo

$(typeset -f run)
set -x

run "$@"

SUDO
EOF
