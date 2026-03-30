#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/camera-capture-install-test-XXXXXX")"
home_dir="${tmp_root}/home"
prefix="${home_dir}/.local/bin"
apps_dir="${home_dir}/Applications"
mkdir -p "$home_dir"

cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

cd "$repo_root"
HOME="$home_dir" ./scripts/install.sh --prefix "$prefix" --apps-dir "$apps_dir" >/dev/null

helper_exec="${apps_dir}/Camera Capture Helper.app/Contents/MacOS/camera-capture-helper"
cat > "$helper_exec" <<'EOF'
#!/bin/bash
set -euo pipefail
request_file=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --request-file)
      shift
      request_file="$1"
      ;;
  esac
  shift || true
done
python3 - "$request_file" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    request = json.load(f)
response = {
    "success": True,
    "permissionState": "granted" if request["action"] == "request-access" else None,
    "outputPath": request.get("capture", {}).get("outputPath") if request["action"] == "capture" else None,
    "message": "2026.03.27-app-bundle-v1",
}
with open(request["responseFile"], "w", encoding="utf-8") as f:
    json.dump(response, f)
PY
EOF
chmod +x "$helper_exec"

build_version="$(./scripts/current_build_version.sh)"
printf '%s' "$build_version" > "${apps_dir}/Camera Capture Helper.app/Contents/Resources/BuildInfo.txt"
printf '%s' "$build_version" > "${prefix}/camera-capture.build-info"

result="$(HOME="$home_dir" PATH="$prefix:$PATH" CAMERA_CAPTURE_HELPER_APP="${apps_dir}/Camera Capture Helper.app" camera-capture request-access)"
[[ "$result" == "granted" ]] || {
  echo "expected granted from installed CLI, got: $result" >&2
  exit 1
}

cmp -s "${prefix}/camera-capture.build-info" "${apps_dir}/Camera Capture Helper.app/Contents/Resources/BuildInfo.txt"
