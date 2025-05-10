# Features Repository

This repository contains features for Devcontainer development containers. Each feature is designed to be easily integrated into a Devcontainer-based development environment.

## Directory Structure

- **`src/`** : Contains the feature definitions.

- **`test/`** : Contains tests to validate the features.


## Available Features

### Google CLI

- **Description** : Installs the Google CLI and makes it available on the `PATH`.
- **Options** :
  - `version` : Allows you to select or enter a specific version of the Google CLI (default: `latest`).

#### Usage Example

```json
"features": {
    "ghcr.io/supergeoff/features/google-cli:1": {}
}
```

## Tests

Tests for each feature are located in the `test/` directory.

## Development Container Configuration

The `.devcontainer/devcontainer.json` file configures the development environment with the following features:
- **Docker-in-Docker** : Enables access to Docker within the container.
- **Devcontainers CLI** : Installs the Devcontainer CLI.

### VS Code Extensions

The following extensions are automatically installed in the container:
- `ms-azuretools.vscode-docker` : Manage Docker via the user interface.
- `mads-hartmann.bash-ide-vscode` : Auto-completion for Bash scripts.

## Notes

- This repository is compatible with Linux distributions supported by `devcontainers/features/common-utils`.
- For more details on each feature, see the `README.MD` files in their respective directories.