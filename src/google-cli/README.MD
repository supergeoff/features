# Google CLI

Installs the Google CLI.

## Example Usage

```json
"features": {
    "ghcr.io/supergeoff/features/google-cli:1": {}
}
```

## Options

| Options Id | Description                           | Type   | Default Value |
|------------|---------------------------------------|--------|--------------|
| version    | Select or enter a Google CLI version. | string | latest       |

## Customizations

### VS Code Extensions

- `googlecloudtools.cloudcode`

### VS Code Settings

```json
"github.copilot.chat.codeGeneration.instructions": [
    {
        "text": "This dev container includes the Google CLI and available on the `PATH`"
    }
]
```

## OS Support

Compatible with any Linux distribution supported by `devcontainers/features/common-utils`.

## Notes

- This feature installs the Google CLI and ensures it is available on the `PATH` for use in your development container.
- For more details, see the [documentation](https://github.com/supergeoff/features/tree/main/src/google-cli).

---

> **Note:** This file was auto-generated from the `devcontainer-feature.json`. Add additional notes to a `NOTES.md` if needed.