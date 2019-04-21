#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# shellcheck source=./util.sh disable=SC1091
source "$DIR/util.sh"

usage="$0 HOST INSTALL_USER FILE"

IFS=$'\n' read -rd '' -a env_before <<<"$(compgen -v)"

host="$(require_host "$1" "$usage")" || exit 1
ssh_host="$host"
shift
user="$(require_user "$1" "$host" "$usage")" || exit 1
ssh_user="$user"
shift
file="$(require_file "$1" "$usage")" || exit 1
shift
user_password="$(pass server-passwords/"$host"/"$user" | xargs -0 echo -n)" || exit 1
ssh_password="$user_password"

source "$file"

arguments "$@"
IFS=$'\n' read -rd '' -a env_after <<<"$(compgen -v)"

env_added=()
for i in "${env_after[@]}"; do
    skip=
    for j in "${env_before[@]}"; do
        [[ $i == $j ]] && { skip=1; break; }
    done
    if [[ $i == "env_before" ]]; then
        skip=1
    fi
    [[ -n $skip ]] || env_added+=("$i")
done

ssh "$ssh_user@$ssh_host" sudo -S bash << SUDO
$ssh_password
echo

eval $(declare -p "${env_added[@]}")
$(typeset -f install_remote)

set -x
install_remote
set +x

SUDO

set -x
install_local
set +x
