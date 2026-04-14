# MuxAgent Monorepo - Agent Guidelines

## Repository Layout

- `cli/` owns the Go CLI, updater, app-server, and bundled workflow configs.
- `mobile/` owns the Flutter mobile app.
- `desktop/` owns the desktop shell.
- `relay/` owns the relay service.
- Root files and workflows should stay surface-neutral unless they are explicitly CLI compatibility shims.

## Change Scope

- Keep monorepo migration changes structural.
- Do not mix repo-layout work with unrelated product features.
- When a surface has not been imported yet, avoid inventing placeholder code for it.

## Verification

- For CLI changes after the move, run checks from `cli/`.
- For mobile changes, run checks from `mobile/`.
- For desktop changes, run checks from `desktop/`.
- For relay changes, run checks from `relay/`.
- Keep release and installer compatibility explicit; do not assume old repo-path defaults still work after a rename.
