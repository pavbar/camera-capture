# AGENTS.md (repo-scoped)

## Purpose of this repo
- Build a public macOS camera capture tool with a Swift CLI, a real-camera helper, and a first-class simulated backend.
- Keep the repo safe to publish: no personal infrastructure details, private media, or identifying environment traces in git.
- Treat testability as a product feature, not an afterthought.

## Instruction priority (repo-local)
1. The user's explicit instructions in the current chat/session.
2. Repo-local docs (`AGENTS.md`, `README.md`, `PRD.md`, `INDEX.md`, `CHANGELOG.md`, `docs/`).
3. Client/global agent instructions.
4. Tool defaults.

If two instructions conflict, follow the higher priority one and state the conflict briefly.

## Context gathering
- Read `README.md`, `PRD.md`, and `INDEX.md` before changing behavior.
- Prefer `rg`, `swift test`, and targeted source inspection before editing.
- Treat `INDEX.md` as the canonical structure map and update it in the same change when structure changes.

## Repo map
- Canonical structure map: `INDEX.md`.
- Main code lives under `Sources/` and `Tests/`.
- Repo-local skill source lives under `.codex/skills/`; synced copies live under `.github/skills/` and `.opencode/skills/`.
- Scripts live under `scripts/`.

## Common commands
- Setup: `swift build`
- Test: `swift test`
- Full verification: `./scripts/verify.sh`
- Privacy scan: `./scripts/privacy_scan.sh`
- Assemble helper app dry-run: `./scripts/assemble_helper_app.sh --dry-run`
- Generate brand assets dry-run: `./scripts/generate_brand_assets.sh --dry-run`
- Install dry-run: `./scripts/install.sh --dry-run`
- Uninstall dry-run: `./scripts/uninstall.sh --dry-run`
- Build release binaries: `swift build -c release`
- Run CLI: `swift run camera-capture --help`
- Run helper directly: `swift run camera-capture-helper --help`

## TDD policy (mandatory)
- Strict TDD is required for every behavior change.
- Start with a failing automated test, then implement, then refactor.
- A change is not done until positive and negative paths are covered.
- If a real macOS surface cannot be automated cleanly, document the exact gap and the required manual acceptance check in `README.md` or `PRD.md`.
- Never replace automated coverage with “tested manually” unless the surface is truly OS- or hardware-bound.

## Simulation-first verification
- Prefer the simulated backend for fast local verification and pre-push checks.
- Keep simulation deterministic so tests can assert exact outputs and failure modes.
- Real hardware and real Camera permission prompts are smoke-test surfaces, not the main verification path.

## Verification gate (mandatory)
- `./scripts/verify.sh` is the canonical minimum verification set for this repo.
- Run `./scripts/verify.sh` before creating a commit that you intend to keep or share, and again before every push.
- If `./scripts/verify.sh` cannot run cleanly because of an environment limitation, stop and document the exact blocker and the missing verification in your handoff.
- Do not replace `./scripts/verify.sh` with a narrower ad hoc command list when the change touches install flow, packaging, docs/examples, privacy scanning, or other public release surfaces.

## Public repo privacy rules
- Never commit personal IPs, LAN ranges, domains, usernames, aliases, hostnames, machine names, or identifying local infrastructure details.
- Never commit personal photos, screenshots, logs, or metadata-bearing artifacts.
- Examples, presets, fixtures, and documentation must be synthetic or sanitized.
- Use public-safe placeholders such as `example.local`, `192.0.2.10`, `<camera-id>`, and `<output-path>`.
- Never copy real device names, real device IDs, or locally discovered hardware labels into public help text, docs, examples, screenshots, fixtures, or tests. Use placeholders such as `<camera-name>` and `<camera-id>` instead.
- If a privacy leak is fixed, add or update an automated regression check so the same class of leak is caught again.
- Treat privacy leakage as a release blocker. Run `./scripts/privacy_scan.sh` before publishing changes that touch docs, fixtures, logs, or examples.

## Change policy
- Prefer small, reversible changes.
- Fix root causes instead of patching symptoms.
- Update docs in the same change when public behavior or repo structure changes.
- When install flow, invocation examples, default output locations, or helper-app behavior change, update the `camera-capture` skill source at `.codex/skills/camera-capture/SKILL.md` in the same change and keep the synced copies under `.github/skills/` and `.opencode/skills/` identical.
- Keep rules in the narrowest correct scope.
- Install-related scripts must support `--dry-run`, create backups before overwriting, and keep behavior idempotent.
- Helper app packaging is part of the supported release surface. Treat `Info.plist`, bundle layout, and icon generation as public behavior.

## Safety and secrets
- Never add secrets to git.
- Stop and remediate if a secret-like or identifying value appears in code, docs, examples, or test artifacts.
- Avoid untrusted scripts and curl-to-shell flows.

## SCM rules
- Do not rewrite git history unless explicitly requested.
- No `git reset --hard` or force-push unless explicitly requested.
- Use Conventional Commits.

## Task management
- Canonical planning document: root `PRD.md`.
- Canonical chronological history: root `CHANGELOG.md`.
- This repo uses Taiga board `pb-main-kanban` for task tracking.
- Keep durable product context and settled decisions in `PRD.md`, not backlog or active execution state.
- Use Taiga for atomic tasks, blockers, handoff notes, and current execution state.

## Manual notes
<!-- MANUAL:START -->
<!-- MANUAL:END -->
