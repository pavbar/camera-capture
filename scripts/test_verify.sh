#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/camera-capture-verify-test-XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

test_repo="${tmp_root}/repo"
fake_bin="${tmp_root}/bin"
log_file="${tmp_root}/verify.log"
mkdir -p "${test_repo}/scripts" "$fake_bin"

cp "${repo_root}/scripts/verify.sh" "${test_repo}/scripts/verify.sh"
chmod +x "${test_repo}/scripts/verify.sh"

cat > "${fake_bin}/swift" <<EOF
#!/bin/bash
set -euo pipefail
printf 'swift %s\n' "\$*" >> "${log_file}"
EOF
chmod +x "${fake_bin}/swift"

for script_name in \
  privacy_scan.sh \
  test_privacy_scan.sh \
  assemble_helper_app.sh \
  generate_brand_assets.sh \
  install.sh \
  uninstall.sh \
  test_install_layout.sh
do
  cat > "${test_repo}/scripts/${script_name}" <<EOF
#!/bin/bash
set -euo pipefail
printf '%s %s\n' "${script_name}" "\$*" >> "${log_file}"
EOF
  chmod +x "${test_repo}/scripts/${script_name}"
done

PATH="${fake_bin}:$PATH" "${test_repo}/scripts/verify.sh" >/tmp/verify.stdout 2>/tmp/verify.stderr

cat > "${tmp_root}/expected.log" <<'EOF'
swift test
privacy_scan.sh 
test_privacy_scan.sh 
assemble_helper_app.sh --dry-run
generate_brand_assets.sh --dry-run
install.sh --dry-run
uninstall.sh --dry-run
test_install_layout.sh 
EOF

cmp -s "${log_file}" "${tmp_root}/expected.log" || {
  echo "verify.sh did not run the expected commands in order" >&2
  diff -u "${tmp_root}/expected.log" "${log_file}" >&2 || true
  exit 1
}

cat > "${test_repo}/scripts/install.sh" <<EOF
#!/bin/bash
set -euo pipefail
printf '%s %s\n' "install.sh" "\$*" >> "${log_file}"
exit 9
EOF
chmod +x "${test_repo}/scripts/install.sh"
: > "${log_file}"

if PATH="${fake_bin}:$PATH" "${test_repo}/scripts/verify.sh" >/tmp/verify-fail.stdout 2>/tmp/verify-fail.stderr; then
  echo "expected verify.sh to fail when a verification step fails" >&2
  exit 1
fi

grep -q '^install.sh --dry-run$' "${log_file}" || {
  echo "expected failing command to be logged" >&2
  exit 1
}

if grep -q '^uninstall.sh --dry-run$' "${log_file}"; then
  echo "verify.sh should stop after the first failing command" >&2
  exit 1
fi
