#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="release"
dry_run=0
output_dir=""

usage() {
  cat <<'EOF'
Usage:
  ./scripts/assemble_helper_app.sh [--config debug|release] [--output-dir <dir>] [--dry-run]

Options:
  --config <name>    Swift build configuration. Default: release
  --output-dir <dir> Directory that will contain "Camera Capture Helper.app"
  --dry-run          Print planned actions without changing the filesystem
  --help             Show this help text
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      shift
      [[ $# -gt 0 ]] || { usage >&2; exit 2; }
      config="$1"
      ;;
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

if [[ "$config" != "debug" && "$config" != "release" ]]; then
  echo "invalid --config value: $config" >&2
  exit 2
fi

if [[ -z "$output_dir" ]]; then
  output_dir="${repo_root}/.build/${config}"
fi

app_root="${output_dir}/Camera Capture Helper.app"
contents_dir="${app_root}/Contents"
macos_dir="${contents_dir}/MacOS"
resources_dir="${contents_dir}/Resources"
binary_source="${repo_root}/.build/${config}/camera-capture-helper"
binary_target="${macos_dir}/camera-capture-helper"
plist_target="${contents_dir}/Info.plist"
icon_target="${resources_dir}/CameraCaptureHelper.icns"
build_info_target="${resources_dir}/BuildInfo.txt"
build_version="$("${repo_root}/scripts/current_build_version.sh")"

cd "$repo_root"

run swift build -c "$config" --product camera-capture-helper
run "${repo_root}/scripts/generate_brand_assets.sh" --output-dir "${repo_root}/Assets/Brand/derived" $([[ "$dry_run" -eq 1 ]] && echo --dry-run)
run mkdir -p "$macos_dir" "$resources_dir"
run cp "$binary_source" "$binary_target"

if [[ "$dry_run" -eq 1 ]]; then
  cat <<EOF
[dry-run] write Info.plist to ${plist_target}
[dry-run] copy ${repo_root}/Assets/Brand/derived/CameraCaptureHelper.icns to ${icon_target}
[dry-run] write build info ${build_version} to ${build_info_target}
EOF
else
  cat > "$plist_target" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Camera Capture Helper</string>
  <key>CFBundleExecutable</key>
  <string>camera-capture-helper</string>
  <key>CFBundleIconFile</key>
  <string>CameraCaptureHelper</string>
  <key>CFBundleIdentifier</key>
  <string>com.pavbar.camera-capture.helper</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Camera Capture Helper</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${build_version}</string>
  <key>CFBundleVersion</key>
  <string>${build_version}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSCameraUsageDescription</key>
  <string>Camera Capture Helper needs camera access to preview and capture images for camera-capture.</string>
</dict>
</plist>
EOF
  cp "${repo_root}/Assets/Brand/derived/CameraCaptureHelper.icns" "$icon_target"
  printf '%s' "$build_version" > "$build_info_target"
fi

printf '%s\n' "${app_root}"
