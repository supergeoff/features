#!/usr/bin/env bash
set -e

PACKAGE_NAME="${PACKAGE:-""}"
PACKAGE_VERSION="${VERSION:-"latest"}"

# --- Sanity checks ---
if [ -z "$PACKAGE_NAME" ]; then
    echo "The 'package' option for the Go Package Installer feature is empty. Please specify a Go package to install."
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    echo -e "Error: This script must be run as root, ensure the feature is run by root."
    exit 1
fi

check_packages() {
    # This is part of devcontainers-extra script library
    # source: https://github.com/devcontainers-extra/features/tree/v1.1.8/script-library
    if ! dpkg -s "$@" >/dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            echo "Running apt-get update..."
            apt-get update -y
        fi
        apt-get -y install --no-install-recommends "$@"
    fi
}

install_via_go_install() {

    local package_arg="$1"
    local version_arg="$2"

    # Ensure Go is installed (the 'dependsOn' in JSON should guarantee this)
    if ! type go >/dev/null 2>&1; then
        echo -e "Error: Go (go command) not found in PATH"
        exit 1
    fi

    # --- Determine effective user for permissioning ---
    # Initialize a local USERNAME variable for processing within this function.
    # It sources from the USERNAME env var (potentially from feature options if the feature defined a 'username' option),
    # then _REMOTE_USER (common in dev container environments), then defaults to "automatic".
    local USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

    ACTUAL_USERNAME=""
    if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
        # Try to find a common non-root user
        POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd 2>/dev/null)")
        for CURRENT_USER_CANDIDATE in "${POSSIBLE_USERS[@]}"; do
            if id -u "${CURRENT_USER_CANDIDATE}" >/dev/null 2>&1; then
                ACTUAL_USERNAME=${CURRENT_USER_CANDIDATE}
                break
            fi
        done
        # If no common user found, and script is run as root, operations might default to root context
        # or a specific user context if the base image has one defined.
        # For permissions, if no specific user, root ownership is implicit.
        if [ "${ACTUAL_USERNAME}" = "" ]; then
            ACTUAL_USERNAME="root" # Default to root if no other user is found
        fi
    elif id -u "${USERNAME}" >/dev/null 2>&1; then
        # Specified user exists
        ACTUAL_USERNAME=${USERNAME}
    else
        # Specified user does not exist, default to root
        echo "Warning: Specified USERNAME ('${USERNAME}') not found. Defaulting to 'root' for ownership considerations."
        ACTUAL_USERNAME="root"
    fi
    echo "Effective user for permissions considerations: ${ACTUAL_USERNAME}"

    # --- Pre-installation setup for non-root user (group creation, add user to group) ---
    if [ "${ACTUAL_USERNAME}" != "root" ]; then
        echo "Performing pre-installation setup for user ${ACTUAL_USERNAME}..."

        # Ensure 'golang' group exists
        if ! getent group golang >/dev/null 2>&1; then
            groupadd -r golang
            echo "Created 'golang' group."
        fi

        # Add user to 'golang' group
        if ! groups "${ACTUAL_USERNAME}" | grep -q "\bgolang\b"; then
            usermod -a -G golang "${ACTUAL_USERNAME}" || echo "Warning: Failed to add user ${ACTUAL_USERNAME} to 'golang' group. This might require root privileges or the user to log out and back in."
        fi
    fi

    # --- Installation ---
    # Format the version argument if necessary.
    # go install expects semantic versions to be prefixed with 'v'.
    # If the version is not 'latest' and doesn't start with 'v', prepend 'v'.
    local formatted_version="${version_arg}"
    if [ "${version_arg}" != "latest" ] && [[ ! "${version_arg}" =~ ^v[0-9] ]]; then
        formatted_version="v${version_arg}"
        echo "Formatted version '${version_arg}' to '${formatted_version}' for go install."
    fi

    # Construct the package argument for 'go install'
    # Format: <package_path>@<formatted_version>
    local go_install_arg="${package_arg}@${formatted_version}"
    echo "Configuring environment for Go package installation..."

    # Define TARGET_GOPATH, consistent with the example and common dev container Go setups.
    # The base Go feature (ghcr.io/devcontainers/features/go) usually sets GOPATH=/go.
    # We will ensure our installation respects this and sets permissions appropriately.
    TARGET_GOPATH="${TARGET_GOPATH:-"/go"}" # Default to /go if not overridden by an env var
    TARGET_GOBIN="${TARGET_GOPATH}/bin"     # Binaries will be installed here
    TARGET_GOCACHE="${TARGET_GOPATH}/cache" # Go build cache

    # --- Check if package is already installed ---
    # Determine the expected binary name (usually the last part of the package path)
    local binary_name
    binary_name=$(basename "${package_arg}")
    local expected_binary_path="${TARGET_GOBIN}/${binary_name}"

    echo "Checking if ${package_arg} (binary: ${binary_name}) is already installed in ${TARGET_GOBIN}..."

    if [ -x "${expected_binary_path}" ]; then
        echo "Executable '${binary_name}' for ${package_arg} already found at '${expected_binary_path}'. Skipping installation."
        exit 0
    fi

    # Ensure the target GOPATH, GOBIN, and GOCACHE directories exist.
    # Create them if they don't (though the base Go feature likely creates /go and /go/bin).
    mkdir -p "${TARGET_GOPATH}" "${TARGET_GOBIN}" "${TARGET_GOCACHE}"

    # Set GOPATH, GOBIN, and GOCACHE environment variables for the 'go install' command.
    # This ensures 'go install' uses these paths.
    export GOPATH="${TARGET_GOPATH}"
    export GOBIN="${TARGET_GOBIN}"
    export GOCACHE="${TARGET_GOCACHE}"

    echo "Attempting to install ${go_install_arg}..."
    echo "Command: go install -v \"${go_install_arg}\" (GOPATH=${GOPATH}, GOBIN=${GOBIN}, GOCACHE=${GOCACHE})"
    if go install -v "${go_install_arg}"; then
        echo "Successfully installed ${go_install_arg} to ${TARGET_GOBIN}."

        # --- Permissions ---
        # If a non-root user is the primary user of the container,
        # adjust ownership and permissions on TARGET_GOPATH to make it usable.
        if [ "${ACTUAL_USERNAME}" != "root" ]; then
            echo "Adjusting final ownership and permissions for ${TARGET_GOPATH} for user ${ACTUAL_USERNAME}..."
            # Set ownership and permissions for the entire TARGET_GOPATH
            # This makes the Go workspace (including GOBIN) group-writable by 'golang' group members.
            chown -R "${ACTUAL_USERNAME}:golang" "${TARGET_GOPATH}" # GOBIN and GOCACHE are inside TARGET_GOPATH
            chmod -R g+r+w "${TARGET_GOPATH}"
            # Set setgid bit on directories so new files/dirs inherit the 'golang' group.
            find "${TARGET_GOPATH}" -type d -print0 | xargs -0 -n 1 chmod g+s 2>/dev/null || find "${TARGET_GOPATH}" -type d -exec chmod g+s {} \;
            echo "Permissions updated for ${TARGET_GOPATH}."
        else
            # If running as root or for root user, ensure root ownership and standard permissions.
            # 'go install' usually sets executable bits correctly for binaries.
            chown -R root:root "${TARGET_GOPATH}"
            chmod -R u+rwX,go+rX,go-w "${TARGET_GOPATH}" # Owner full, group/other read/execute
            echo "Permissions set for root ownership on ${TARGET_GOPATH}."
        fi

        echo "Installation of ${package_arg} complete. The binary '${binary_name}' should be available in PATH (via ${TARGET_GOBIN})."
    else
        echo -e "Error: Failed to install Go package ${go_install_arg}."
        exit 1
    fi
}

install_via_go_install "$PACKAGE_NAME" "$PACKAGE_VERSION"
