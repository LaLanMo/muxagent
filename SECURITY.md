# Security Policy

Report security issues privately through the existing MuxAgent security contact
process.

Surface-specific notes live with each component:

- CLI: [cli/SECURITY.md](cli/SECURITY.md)
- Mobile: Firebase config files are placeholders in git and must be replaced with project-specific credentials outside public history.
- Relay: local runtime config stays under `relay/config/` and should not be packaged into public release artifacts.
