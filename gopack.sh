#!/bin/bash

TARGET_GOPATH="${TARGET_GOPATH:-"/go"}"
USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

set -e

if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} >/dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} >/dev/null 2>&1; then
    USERNAME=root
fi

echo "Installing Go Packages"

echo ${PACKAGES}

mkdir -p /tmp/gotools /usr/local/etc/vscode-dev-containers ${TARGET_GOPATH}/bin
cd /tmp/gotools
export GOPATH=/tmp/gotools
export GOCACHE=/tmp/gotools/cache

IFS=',' read -ra SPLITTED <<<"$PACKAGES"

umask 002
if ! cat /etc/group | grep -e "^golang:" >/dev/null 2>&1; then
    groupadd -r golang
fi
usermod -a -G golang "${USERNAME}"

(echo "${SPLITTED[@]}" | xargs -n 1 go install -v) 2>&1 | tee -a /usr/local/etc/vscode-dev-containers/go.log

# Move Go tools into path and clean up
if [ -d /tmp/gotools/bin ]; then
    mv /tmp/gotools/bin/* ${TARGET_GOPATH}/bin/
    rm -rf /tmp/gotools
fi

chown -R "${USERNAME}:golang" "${TARGET_GOPATH}"
chmod -R g+r+w "${TARGET_GOPATH}"
find "${TARGET_GOPATH}" -type d -print0 | xargs -n 1 -0 chmod g+s

echo "Done!"
