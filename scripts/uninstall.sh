#!/bin/bash
set -euo pipefail

prefix="${HOME}/.local/bin"
apps_dir="${HOME}/Applications"
dry_run=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/uninstall.sh [--prefix <dir>] [--apps-dir <dir>] [--dry-run]

Options:
  --prefix <dir>   Remove binaries from this directory. Default: ~/.local/bin
  --apps-dir <dir> Remove helper app bundle from this directory. Default: ~/Applications
  --dry-run        Print planned actions without changing the filesystem
  --help           Show this help text
EOF
}

run() {
  if [[ "$dry_run" -eq 1 ]]; then
    printf '[dry-run] %q' "$1"
    shift
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  else
    "$@"
  fi
}

trash_path() {
  local target="$1"
  local trash_dir="${HOME}/.Trash"
  local destination="${trash_dir}/$(basename "$target").$(date +%Y%m%d_%H%M%S)"
  run mkdir -p "$trash_dir"
  run mv "$target" "$destination"
  echo "moved to trash: $destination"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      shift
      [[ $# -gt 0 ]] || { usage >&2; exit 2; }
      prefix="$1"
      ;;
    --apps-dir)
      shift
      [[ $# -gt 0 ]] || { usage >&2; exit 2; }
      apps_dir="$1"
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

target_path="${prefix}/camera-capture"
if [[ -e "$target_path" ]]; then
  trash_path "$target_path"
else
  echo "skipped missing: $target_path"
fi

build_info_path="${prefix}/camera-capture.build-info"
if [[ -e "$build_info_path" ]]; then
  trash_path "$build_info_path"
else
  echo "skipped missing: $build_info_path"
fi

app_target_path="${apps_dir}/Camera Capture Helper.app"
if [[ -e "$app_target_path" ]]; then
  trash_path "$app_target_path"
else
  echo "skipped missing: $app_target_path"
fi
