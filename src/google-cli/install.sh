#!/usr/bin/env bash

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

VERSION=${VERSION:-"latest"}

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

export DEBIAN_FRONTEND=noninteractive

check_packages curl ca-certificates tar bash-completion

install() {
    local scriptTarFile=gcloudcli.tar.gz

    # See Linux install docs at https://cloud.google.com/sdk/docs/install
    if [ "${VERSION}" != "latest" ]; then
        local versionStr=-${VERSION}
    fi
    architecture=$(dpkg --print-architecture)
    case "${architecture}" in
        amd64) architectureStr=x86_64 ;;
        i686) architectureStr=x86 ;;
        arm64) architectureStr=aarch64 ;;
        *)
            echo "Google CLI does not support machine architecture '$architecture'. Please use an x86, x86-64 or ARM64 machine."
            exit 1
    esac
    local scriptUrl=https://storage.googleapis.com/cloud-sdk-release/google-cloud-cli${versionStr}-linux-${architectureStr}.tar.gz
    
    curl "${scriptUrl}" -o "${scriptTarFile}"

    tar -xf "${scriptTarFile}"
    mv "google-cloud-sdk" /usr/local/
    /usr/local/google-cloud-sdk/install.sh --command-completion true --path-update true
    
}

echo "(*) Installing Google CLI..."

install

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done!"
