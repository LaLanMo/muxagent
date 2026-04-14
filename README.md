# MuxAgent

MuxAgent is becoming a single repository for the product's CLI, mobile app,
desktop shell, and relay service.

Current layout on this branch:

- `cli/` - Go CLI, app-server, and updater
- `mobile/` - reserved for the Flutter mobile app
- `desktop/` - reserved for the desktop shell
- `relay/` - reserved for the relay service

## Install The CLI

```bash
curl -fsSL https://raw.githubusercontent.com/LaLanMo/muxagent/main/install.sh | sh
```

The CLI binary remains `muxagent`.

## Surface Docs

- CLI: [cli/README.md](cli/README.md)

## Status

This branch is the monorepo migration base. Additional surfaces will be merged
into the reserved top-level directories in follow-up steps.
