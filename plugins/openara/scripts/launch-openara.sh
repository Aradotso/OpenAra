#!/usr/bin/env bash

set -euo pipefail

plugin_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "${plugin_root}/../.." && pwd)"

candidate_binaries=(
  "${plugin_root}/OpenAra.app/Contents/MacOS/OpenAra"
  "${repo_root}/dist/OpenAra.app/Contents/MacOS/OpenAra"
)

for app_binary in "${candidate_binaries[@]}"; do
  if [[ -x "${app_binary}" ]]; then
    if [[ "${app_binary}" == "${plugin_root}"/* ]]; then
      cd "${plugin_root}"
    else
      cd "${repo_root}"
    fi
    exec "${app_binary}" mcp
  fi
done

if command -v openara >/dev/null 2>&1; then
  exec openara mcp
fi

echo "openara could not find a runnable macOS app bundle." >&2
echo "Checked:" >&2
for app_binary in "${candidate_binaries[@]}"; do
  echo "  - ${app_binary}" >&2
done
echo "  - openara on PATH" >&2
echo "Run ./scripts/install-codex-plugin.sh from the repo root to build the bundle." >&2
exit 1
