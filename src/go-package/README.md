
# Go Package (go-package)

Installs a Go command globally from a package path using 'go install'. Ensures the GOBIN (default /go/bin) is user-accessible.

## Example Usage

```json
"features": {
    "ghcr.io/supergeoff/features/go-package:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| package | Specify the Go package path for the package to install (e.g., 'golang.org/x/tools/cmd/goimports'). | string | - |
| version | Select the version of the Go package to install (e.g., 'latest', 'v1.2.3') | string | latest |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/supergeoff/features/blob/main/src/go-package/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
