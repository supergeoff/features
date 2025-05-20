#!/usr/bin/env bash

set -e

source ./library_scripts.sh

# nanolayer is a cli utility which keeps container layers as small as possible
# source code: https://github.com/devcontainers-extra/nanolayer
# `ensure_nanolayer` is a bash function that will find any existing nanolayer installations,
# and if missing - will download a temporary copy that automatically get deleted at the end
# of the script
ensure_nanolayer nanolayer_location "v0.5.5"

# Split packages by comma
IFS=',' read -ra PACKAGE_ARRAY <<<"$PACKAGES"

# Iterate through each package
for package in "${PACKAGE_ARRAY[@]}"; do
    echo "Processing package string: ${package}"
    pkg_name=""
    pkg_version="" # Will default to "latest" if not specified, handled by go-package feature

    # Regex to parse Go package strings: path/to/module[@version]
    if [[ $package =~ ^([^@]+)(@(.*))?$ ]]; then
        pkg_name="${BASH_REMATCH[1]}"
        pkg_version="${BASH_REMATCH[3]}" # This will be empty if no @version is present
    else
        echo "Warning: Could not parse package string '${package}'. Using it as package name directly and version 'latest'."
        pkg_name=$package
        # pkg_version remains empty, go-package feature will use its default "latest"
    fi

    echo "Installing Go package: '${pkg_name}' version: '${pkg_version:-latest}'"

    options_array=()
    options_array+=("--option" "package=${pkg_name}")
    if [ -n "${pkg_version}" ]; then
        options_array+=("--option" "version=${pkg_version}")
    fi

    $nanolayer_location \
        install \
        devcontainer-feature \
        "ghcr.io/supergeoff/features/go-package" "${options_array[@]}"
done

echo 'Done!'
