# PRD - camera-capture

This is a living document. Update it in place as scope, decisions, and progress evolve.

## 1. Project Idea
Build a public macOS camera tool that supports both real camera capture and deterministic simulated capture, so contributors can develop and verify the product even when physical hardware or Camera permissions are unavailable.

## 2. Product Goals
- Provide a simple Swift CLI for real and simulated capture workflows on macOS.
- Make simulation a first-class public feature so local development and pre-push verification do not depend on real camera hardware.
- Keep the repository safe to publish by enforcing strict privacy hygiene in code, docs, fixtures, and examples.
- Treat testing and TDD as core product constraints rather than optional quality improvements.

## 3. Non-Goals (Current Scope)
- No cloud services, remote capture features, or networked camera control in v1.
- No commitment to full automation of the real macOS TCC Camera consent dialog.
- No storage of real personal photos, private logs, or environment-identifying artifacts in git.
- No multi-platform support beyond macOS in the current scope.

## 4. Project Operations
- Last updated: 2026-03-27
- Task management system: `Taiga / pb-main-kanban`
- Canonical planning document: root `PRD.md`.
- Atomic execution tracking and current task state belong in the task management system, not in this document.
- Repo-local `AGENTS.md` defines the project-specific task-management lookup and filing rules.
- Chronological repository change history belongs in root `CHANGELOG.md` when the repo tracks one.
- This PRD records durable product context and settled decisions, not operational task metadata.

## 5. Current Capabilities
- The CLI supports `capture`, `preview`, `list-devices`, `request-access`, and `list-presets`.
- Default captures without `--output` are written to the user's `~/Pictures/Camera Capture/` directory so installed builds do not depend on the current working directory or repo layout.
- The simulated backend can create deterministic JPEG outputs and inject failure modes such as timeout and write failure.
- The real backend is packaged as a helper app bundle so camera permission is attributed to `Camera Capture Helper.app` instead of the terminal host.
- The repository includes an automated Swift test suite plus a privacy scan script to reduce accidental public-data leakage.
- The repo-local skill documents how to invoke the CLI from Codex-oriented workflows.

## 6. Durable Decisions
- Keep simulation as a public product feature, not hidden test plumbing.
- Enforce strict TDD for every behavior change.
- Prefer simulation-backed automated verification before real-hardware smoke testing.
- Treat privacy leakage as a release blocker for this public repository.
- Keep root `INDEX.md` as the canonical repository structure map and root `CHANGELOG.md` as the chronological history file.
- Keep the CLI as the primary public interface while packaging real camera access through a visible macOS helper app in `~/Applications`.
