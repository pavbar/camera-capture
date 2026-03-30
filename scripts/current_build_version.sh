#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rg 'sharedVersion = "([^"]+)"' "${repo_root}/Sources/CameraCaptureCore/Models.swift" -or '$1' | head -n 1
