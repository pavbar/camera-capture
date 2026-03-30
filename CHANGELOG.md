# Changelog

## Unreleased
- Bootstrapped `camera-capture` as a public macOS Swift package with CLI, helper executable, simulated backend, tests, root docs, privacy scan script, and a repo-local Codex skill.
- Added install and uninstall scripts with dry-run support, backup-on-overwrite behavior, and README documentation.
- Added helper app bundle assembly, helper-app discovery from `~/Applications`, and deterministic generated brand assets for the helper icon and logo.
- Changed the default capture destination from the current working directory to `~/Pictures/Camera Capture/` so installed/Homebrew-style usage does not depend on repo layout or launch location.
