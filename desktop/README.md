# MuxAgent Desktop

Desktop shell for `muxagent`.

## Common Commands

```bash
pnpm install
pnpm typecheck
pnpm build
pnpm tauri:build
pnpm tauri:build:debug
```

From the monorepo root, use `scripts/dev-desktop.sh` to rebuild the current
`cli/` binary and launch Tauri dev against that local binary.

Within `desktop/`, keep the Tauri scripts surface-local:

- `pnpm tauri:dev` runs desktop development mode.
- `pnpm tauri:build` builds the release desktop binary.
- `pnpm tauri:build:debug` builds the debug desktop binary.

## Notes

- The E2E helper supports both the monorepo layout and the legacy standalone CLI checkout.
- Local app state and generated artifacts are ignored and should not be committed.
- The built desktop app still resolves the muxagent CLI at runtime via `MUXAGENT_CLI_PATH` or the host `PATH`; bundling the CLI as a desktop sidecar is not wired yet.
