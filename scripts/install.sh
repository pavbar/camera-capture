#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prefix="${HOME}/.local/bin"
apps_dir="${HOME}/Applications"
config="release"
dry_run=0

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install.sh [--prefix <dir>] [--apps-dir <dir>] [--config debug|release] [--dry-run]

Options:
  --prefix <dir>   Install binaries into this directory. Default: ~/.local/bin
  --apps-dir <dir> Install helper app bundle into this directory. Default: ~/Applications
  --config <name>  Swift build configuration. Default: release
  --dry-run        Print planned actions without changing the filesystem
  --help           Show this help text
EOF
}

log() {
  printf '%s\n' "$*"
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

backup_if_exists() {
  local target="$1"
  if [[ -e "$target" ]]; then
    local backup="${target}.bak.$(date +%Y%m%d_%H%M%S)"
    if [[ -d "$target" ]]; then
      run mv "$target" "$backup"
    else
      run cp "$target" "$backup"
    fi
    log "backup: $backup"
  fi
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
    --config)
      shift
      [[ $# -gt 0 ]] || { usage >&2; exit 2; }
      config="$1"
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

if [[ "$config" != "debug" && "$config" != "release" ]]; then
  echo "invalid --config value: $config" >&2
  exit 2
fi

cd "$repo_root"

run mkdir -p "$prefix"
run mkdir -p "$apps_dir"
run swift build -c "$config" --product camera-capture
run "${repo_root}/scripts/assemble_helper_app.sh" --config "$config" --output-dir "${repo_root}/.build/${config}" $([[ "$dry_run" -eq 1 ]] && echo --dry-run)
app_bundle_source="${repo_root}/.build/${config}/Camera Capture Helper.app"

source_dir="${repo_root}/.build/${config}"
binary="camera-capture"
source_path="${source_dir}/${binary}"
target_path="${prefix}/${binary}"
build_version="$("${repo_root}/scripts/current_build_version.sh")"
build_info_target="${prefix}/camera-capture.build-info"

if [[ ! -x "$source_path" && "$dry_run" -eq 0 ]]; then
  echo "missing built binary: $source_path" >&2
  exit 1
fi

backup_if_exists "$target_path"
run cp "$source_path" "$target_path"
log "installed: $target_path"
if [[ "$dry_run" -eq 1 ]]; then
  echo "[dry-run] write build info ${build_version} to ${build_info_target}"
else
  printf '%s' "$build_version" > "$build_info_target"
fi
log "installed: $build_info_target"

app_target_path="${apps_dir}/Camera Capture Helper.app"
if [[ -e "$app_target_path" ]]; then
  backup_if_exists "$app_target_path"
fi
run cp -R "$app_bundle_source" "$app_target_path"
log "installed: $app_target_path"

case ":${PATH}:" in
  *":${prefix}:"*) ;;
  *)
    log "PATH note: ${prefix} is not currently on PATH"
    ;;
esac

log "helper note: camera-capture will look for Camera Capture Helper.app in ${apps_dir} unless CAMERA_CAPTURE_HELPER_APP or CAMERA_CAPTURE_HELPER_PATH is set."
