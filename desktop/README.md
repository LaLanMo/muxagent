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

From the monorepo root, use `scripts/stable-desktop.sh` to launch the pinned
local stable desktop artifact under `.muxagent/desktop-stable`.

- `scripts/stable-desktop.sh` launches the current pinned stable artifact.
- `scripts/stable-desktop.sh --refresh-only` rebuilds the pinned stable artifact
  from the current repo snapshot without launching it.
- `scripts/stable-desktop.sh --refresh` rebuilds the pinned stable artifact and
  launches it immediately.
- `stable` currently pins only the desktop/CLI artifacts; before Phase 2 it
  still uses the default `~/.muxagent` state instead of a separate stable
  profile.
- Before launch, `stable` checks the default `~/.muxagent/appserver`; if the
  existing daemon was not started by the current pinned stable CLI, it is
  stopped first and then replaced by the pinned CLI.

Within `desktop/`, keep the Tauri scripts surface-local:

- `pnpm tauri:dev` runs desktop development mode.
- `pnpm tauri:build` builds the release desktop binary.
- `pnpm tauri:build:debug` builds the debug desktop binary.

## Notes

- The E2E helper supports both the monorepo layout and the legacy standalone CLI checkout.
- Local app state and generated artifacts are ignored and should not be committed.
- The built desktop app still resolves the muxagent CLI at runtime via `MUXAGENT_CLI_PATH` or the host `PATH`; bundling the CLI as a desktop sidecar is not wired yet.
- `scripts/stable-desktop.sh` keeps its pinned desktop/CLI artifacts under `.muxagent/desktop-stable` and clears dev-only task profile overrides before launch.
- `scripts/stable-desktop.sh` also preflights the default app-server daemon and restarts it when the existing daemon PID does not belong to the pinned stable CLI path.
- Set `MUXAGENT_STABLE_BUILD_MODE=release` if you want the pinned stable artifact built from a release profile instead of the default debug profile.
