# Features Repository

This repository contains features for Devcontainer development containers. Each feature is designed to be easily integrated into a Devcontainer-based development environment.

## Directory Structure

- **`src/`** : Contains the feature definitions.

- **`test/`** : Contains tests to validate the features.

## Development Container Configuration

The `.devcontainer/devcontainer.json` file configures the development environment with the following features:

- **devcontainers-extra/features/prebuilt-devcontainer** : Enables access to Docker within the container & Devcontainer CLI.

### VS Code Extensions

The following extensions are automatically installed in the container:

- `mads-hartmann.bash-ide-vscode` : Auto-completion for Bash scripts.

## Notes

- This repository is compatible with Linux distributions supported by `devcontainers/features/common-utils`.
- For more details on each feature, see the `README.MD` files in their respective directories.
