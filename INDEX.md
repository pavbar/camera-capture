# Repository Index

## Purpose
This file is the canonical source for repository structure and navigation.
Update it in the same change when key directories or entrypoints change.

## Top-level map
- `.codex/` - repo-local Codex resources, including the source skill definition.
- `.github/` - synced repo-local skills for GitHub surfaces.
- `.opencode/` - synced repo-local skills for OpenCode surfaces.
- `Assets/` - brand source art and generated helper-app icon outputs.
- `Sources/` - Swift sources for the core library, CLI, and helper executable.
- `Tests/` - automated test suite.
- `scripts/` - contributor and verification scripts.
- `tmp/` - generated captures and disposable local artifacts.

## Key entrypoints
- `README.md` - public overview and quick start.
- `AGENTS.md` - repo-scoped engineering and privacy rules.
- `PRD.md` - living product and decision document.
- `CHANGELOG.md` - chronological history.
- `LICENSE` - Apache License 2.0 for the repository.
- `Package.swift` - SwiftPM entrypoint.
- `Sources/camera-capture/main.swift` - CLI entrypoint.
- `Sources/camera-capture-helper/main.swift` - real-camera helper entrypoint.
- `Assets/Brand/` - helper app icon source art and generated brand assets.
- `scripts/assemble_helper_app.sh` - assembles `Camera Capture Helper.app` from the built helper executable.
- `scripts/generate_brand_assets.sh` - generates deterministic icon assets and brand outputs.
- `scripts/privacy_scan.sh` - public-repo privacy verification script.
- `scripts/test_helper_cli_contract.sh` - regression test for helper CLI argument constraints.
- `scripts/test_privacy_scan.sh` - regression test for the privacy scanner and local overlay loading.
- `scripts/verify.sh` - canonical pre-commit and pre-push verification entrypoint.
- `scripts/test_verify.sh` - regression test for the verification wrapper ordering and fail-fast behavior.
- `scripts/install.sh` - install both executables with backup and dry-run support.
- `scripts/uninstall.sh` - remove installed executables with dry-run support.

## Navigation notes
- Keep this file factual and concise.
- `INDEX.md` is the canonical structure index.
- `README.md` and `AGENTS.md` should stay shorter than this file and link back here.
