# MuxAgent

MuxAgent is the monorepo for the product's CLI, mobile app, desktop shell, and
relay service.

## Repository Layout

- `cli/` - Go CLI, app-server, and updater
- `mobile/` - Flutter mobile app
- `desktop/` - desktop shell
- `relay/` - relay service

## Install The CLI

```bash
curl -fsSL https://raw.githubusercontent.com/LaLanMo/muxagent/main/install.sh | sh
```

The CLI binary remains `muxagent`.

## Release Tags

Release tags are namespaced per surface:

- `cli/v1.2.3`
- `mobile/v1.2.3`
- `desktop/v0.1.0`
- `relay/v0.1.0`

Only the CLI release workflow is automated today. The monorepo keeps the
surface-specific namespaces so the products can release independently.

## Surface Docs

- CLI: [cli/README.md](cli/README.md)
- Mobile: [mobile/README.md](mobile/README.md)
- Desktop: [desktop/README.md](desktop/README.md)
- Relay: [relay/README.md](relay/README.md)

## Surface Toolchains

- `cli/`: Go, release tags under `cli/v*`
- `mobile/`: Flutter, placeholder Firebase config committed for open-source distribution
- `desktop/`: Node + pnpm + Tauri
- `relay/`: Go module path `github.com/LaLanMo/muxagent/relay`
