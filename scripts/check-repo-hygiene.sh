#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

required_files=(
  ".gitignore"
  "CODEOWNERS"
  "CONTRIBUTING.md"
  "LICENSE"
  "README.md"
  "SECURITY.md"
  ".github/workflows/release.yml"
  "scripts/check-action-pinning.sh"
)

failed=0

for path in "${required_files[@]}"; do
  if [[ ! -f "${repo_root}/${path}" ]]; then
    echo "Missing required file: ${path}"
    failed=1
  fi
done

if grep -q $'\r' "${repo_root}/README.md"; then
  echo "README.md contains CRLF line endings"
  failed=1
fi

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi

echo "Repo hygiene check passed"
