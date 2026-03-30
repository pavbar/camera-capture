#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${repo_root}/Assets/Brand/derived"
dry_run=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/generate_brand_assets.sh [--output-dir <dir>] [--dry-run]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir)
      shift
      [[ $# -gt 0 ]] || { usage >&2; exit 2; }
      output_dir="$1"
      ;;
    --dry-run)
      dry_run=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$dry_run" -eq 1 ]]; then
  printf '[dry-run] swift %q --output-dir %q\n' "${repo_root}/scripts/generate_brand_assets.swift" "$output_dir"
  exit 0
fi

swift "${repo_root}/scripts/generate_brand_assets.swift" --output-dir "$output_dir"
