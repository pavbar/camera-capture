#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/camera-capture-privacy-scan-test-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

test_repo="${tmp_root}/repo"
test_home="${tmp_root}/home"
missing_stdout="${tmp_root}/privacy-scan-missing.stdout"
missing_stderr="${tmp_root}/privacy-scan-missing.stderr"
match_stdout="${tmp_root}/privacy-scan.stdout"
match_stderr="${tmp_root}/privacy-scan.stderr"
mkdir -p "${test_repo}/scripts" "${test_home}/.config/privacy-scan"

cp "${repo_root}/scripts/privacy_scan.sh" "${test_repo}/scripts/privacy_scan.sh"
chmod +x "${test_repo}/scripts/privacy_scan.sh"

cat > "${test_repo}/fixture.txt" <<'EOF'
keep this repo publishable
EOF

if ! HOME="${test_home}" "${test_repo}/scripts/privacy_scan.sh" >"${missing_stdout}" 2>"${missing_stderr}"; then
  echo "expected privacy scan to pass without a global local-identifiers.txt file" >&2
  exit 1
fi

grep -q 'privacy scan passed' "${missing_stdout}" || {
  echo "expected success output when the global local-identifiers.txt file is missing" >&2
  exit 1
}

grep -q 'optional local identifiers file not found' "${missing_stderr}" || {
  echo "expected a non-fatal advisory about the missing global local-identifiers.txt file" >&2
  exit 1
}

cat > "${test_home}/.config/privacy-scan/local-identifiers.txt" <<'EOF'
# comments and blank lines should be ignored

publishable
EOF

if HOME="${test_home}" "${test_repo}/scripts/privacy_scan.sh" >"${match_stdout}" 2>"${match_stderr}"; then
  echo "expected privacy scan to fail when global local-identifiers.txt matches repo content" >&2
  exit 1
fi

grep -q 'fixture.txt' "${match_stdout}" || {
  echo "expected scan output to mention the matching file" >&2
  exit 1
}

grep -q 'privacy scan failed' "${match_stderr}" || {
  echo "expected privacy scan failure message on stderr" >&2
  exit 1
}

if grep -q 'optional local identifiers file not found' "${match_stderr}"; then
  echo "did not expect the missing-file advisory once the global local-identifiers.txt file exists" >&2
  exit 1
fi
