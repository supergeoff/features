#!/usr/bin/env bash

set -e

source ./library_scripts.sh

# nanolayer is a cli utility which keeps container layers as small as possible
# source code: https://github.com/devcontainers-extra/nanolayer
# `ensure_nanolayer` is a bash function that will find any existing nanolayer installations,
# and if missing - will download a temporary copy that automatically get deleted at the end
# of the script
ensure_nanolayer nanolayer_location "v0.5.5"

# Example nanolayer installation via devcontainer-feature
echo "Installing Playwright"
$nanolayer_location \
    install \
    devcontainer-feature \
    "ghcr.io/devcontainers-extra/features/npm-package" \
    --option package='playwright' --option version="$VERSION"

# --- Install Playwright browser system dependencies ---
$nanolayer_location \
    install \
    devcontainer-feature \
    "ghcr.io/devcontainers-extra/features/apt-get-packages" \
    --option packages='libnss3,libnspr4,libdbus-1-3,libatk1.0-0,libatk-bridge2.0-0,libcups2,libxkbcommon0,libatspi2.0-0,libxcomposite1,libxdamage1,libxfixes3,libxrandr2,libgbm1,libasound2'

echo 'Done!'