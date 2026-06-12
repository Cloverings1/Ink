# Security Policy

Ink is a local-first macOS app. Notes are plain Markdown files on disk, and the app does not run a backend service.

## Reporting a Vulnerability

If you find a vulnerability, please do not post exploit details, private data, or secrets in a public issue.

Use GitHub private vulnerability reporting when it is available for this repository. If it is not available, open a minimal public issue that says a private security report is needed, without including sensitive details.

## Current Security Posture

- Notes are stored locally as `.md` files.
- Clipboard history is stored locally and can be cleared from the menu-bar context menu.
- Local environment files, deployment metadata, generated builds, and assistant context folders are ignored by git.
- Developer builds are currently unsandboxed to support low-friction user-selected note folders. Public distribution should use signed and notarized release artifacts.
