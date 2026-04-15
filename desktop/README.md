# MuxAgent Desktop

Desktop shell for `muxagent`.

## Common Commands

```bash
pnpm install
pnpm typecheck
pnpm build
```

From the monorepo root, use `scripts/dev-desktop.sh` to rebuild the current
`cli/` binary and launch Tauri dev against that local binary.

## Notes

- The E2E helper supports both the monorepo layout and the legacy standalone CLI checkout.
- Local app state and generated artifacts are ignored and should not be committed.
