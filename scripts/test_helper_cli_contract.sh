#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/camera-capture-helper-cli-test-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

stdout_path="${tmp_root}/stdout.txt"
stderr_path="${tmp_root}/stderr.txt"
output_path="${tmp_root}/capture.jpg"

cd "$repo_root"

if swift run camera-capture-helper capture --backend simulated --output "$output_path" >"$stdout_path" 2>"$stderr_path"; then
  echo "expected helper to reject --backend simulated" >&2
  exit 1
fi

grep -q 'helper only supports --backend real for capture' "$stderr_path" || {
  echo "expected helper error to mention --backend real only" >&2
  exit 1
}
