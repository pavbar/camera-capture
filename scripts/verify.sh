#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

run_step() {
  local label="$1"
  shift

  echo "==> ${label}"
  "$@"
}

run_step "swift test" swift test
run_step "privacy scan" ./scripts/privacy_scan.sh
run_step "privacy scan regression" ./scripts/test_privacy_scan.sh
run_step "helper app assemble dry-run" ./scripts/assemble_helper_app.sh --dry-run
run_step "brand assets dry-run" ./scripts/generate_brand_assets.sh --dry-run
run_step "install dry-run" ./scripts/install.sh --dry-run
run_step "uninstall dry-run" ./scripts/uninstall.sh --dry-run
run_step "install layout regression" ./scripts/test_install_layout.sh
