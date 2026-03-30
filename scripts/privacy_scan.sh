#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

regex_patterns=(
  '(?<![0-9])(10\.(?:[0-9]{1,3}\.){2}[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(?:1[6-9]|2[0-9]|3[0-1])\.[0-9]{1,3}\.[0-9]{1,3})(?![0-9])'
  '(?<![A-Za-z0-9-])(?!example\.local\b)[A-Za-z0-9-]+\.(local|lan|home|internal)(?![A-Za-z])'
  '/Users/[A-Za-z0-9._-]+'
  '/home/[A-Za-z0-9._-]+'
  '[A-Za-z0-9._%+-]+@[A-Za-z][A-Za-z0-9.-]*\.[A-Za-z]{2,}'
  '[A-Za-z0-9-]*MacBook(?:-Pro|-Air)?'
  '[A-Za-z0-9-]*ubuntu-server'
)

literal_patterns=()
local_identifiers_file="${HOME}/.config/privacy-scan/local-identifiers.txt"

exclude=(
  '.git'
  '.build'
  'tmp'
  '.swiftpm'
)

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

load_local_patterns() {
  local line trimmed

  if [[ ! -f "$local_identifiers_file" ]]; then
    echo "privacy scan note: optional local identifiers file not found at ${local_identifiers_file}. Recommended for personal-only identifiers, but scan continues without it." >&2
    return 0
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim "${line%$'\r'}")"

    if [[ -z "$trimmed" || "${trimmed:0:1}" == "#" ]]; then
      continue
    fi

    if [[ "$trimmed" == re:* ]]; then
      regex_patterns+=("${trimmed#re:}")
    else
      literal_patterns+=("$trimmed")
    fi
  done < "$local_identifiers_file"
}

cmd=(rg --hidden --line-number --with-filename)
for item in "${exclude[@]}"; do
  cmd+=(--glob "!$item/**")
done
cmd+=(--glob '!scripts/privacy_scan.sh')

load_local_patterns

status=0
for pattern in "${regex_patterns[@]}"; do
  if "${cmd[@]}" -P --regexp "$pattern" .; then
    status=1
  fi
done

if [[ "${#literal_patterns[@]}" -gt 0 ]]; then
  for pattern in "${literal_patterns[@]}"; do
    if "${cmd[@]}" -F --regexp "$pattern" .; then
      status=1
    fi
  done
fi

if [[ "$status" -ne 0 ]]; then
  echo "privacy scan failed: sanitize matches above" >&2
  exit 1
fi

echo "privacy scan passed"
