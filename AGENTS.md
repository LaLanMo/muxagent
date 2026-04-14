# MuxAgent Monorepo - Agent Guidelines

## Repository Layout

- `cli/` owns the Go CLI, updater, app-server, and bundled workflow configs.
- `mobile/`, `desktop/`, and `relay/` are reserved for the remaining product surfaces as they are merged in.
- Root files and workflows should stay surface-neutral unless they are explicitly CLI compatibility shims.

## Change Scope

- Keep monorepo migration changes structural.
- Do not mix repo-layout work with unrelated product features.
- When a surface has not been imported yet, avoid inventing placeholder code for it.

## Verification

- For CLI changes after the move, run checks from `cli/`.
- Keep release and installer compatibility explicit; do not assume old repo-path defaults still work after a rename.
