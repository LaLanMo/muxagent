# Contributing

MuxAgent is a multi-surface monorepo.

Surface-specific contributor docs:

- CLI: [cli/CONTRIBUTING.md](cli/CONTRIBUTING.md)
- Mobile: [mobile/README.md](mobile/README.md)
- Desktop: [desktop/README.md](desktop/README.md)
- Relay: [relay/README.md](relay/README.md)

Repo-wide expectations:

- Keep changes scoped to the surface you are touching unless the task is explicitly cross-cutting.
- Use namespaced release tags such as `cli/v1.2.3` and `relay/v0.1.0`.
- Keep root workflows and docs surface-neutral unless they are intentional compatibility shims for the CLI.
