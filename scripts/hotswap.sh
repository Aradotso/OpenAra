#!/usr/bin/env bash
#
# hotswap.sh — fastest local-iteration loop for OpenAra.
#
# Rebuilds just the OpenAra binary (skips iconset, plist, full app bundle
# layout) and drops it into the existing /Applications/OpenAra.app shell so
# TCC keeps the prior Accessibility / Screen Recording grants. ~3s instead of
# ~10s for a full `build-openara-app.sh release`.
#
# Usage:
#   ./scripts/hotswap.sh           # build + install + ad-hoc re-sign
#   ./scripts/hotswap.sh --dry     # only build, do not install
#
# After it runs, any new MCP session (Claude Code, Codex, …) that spawns
# `openara mcp` will pick up the fresh binary. Active sessions keep the old
# binary loaded until they exit.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_app="/Applications/OpenAra.app"
target_binary="${target_app}/Contents/MacOS/OpenAra"
configuration="release"
dry=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry|--build-only) dry=1; shift ;;
    --debug) configuration="debug"; shift ;;
    -h|--help)
      sed -n '2,18p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

cd "${repo_root}"

start_ts=$(date +%s)
swift build -c "${configuration}" --product OpenAra >/dev/null
build_dir="$(swift build -c "${configuration}" --show-bin-path)"
fresh_binary="${build_dir}/OpenAra"

if [[ ! -x "${fresh_binary}" ]]; then
  echo "error: built binary missing at ${fresh_binary}" >&2
  exit 1
fi

if [[ "${dry}" -eq 1 ]]; then
  echo "built ${fresh_binary} ($(stat -f '%z bytes' "${fresh_binary}"))"
  exit 0
fi

if [[ ! -d "${target_app}" ]]; then
  echo "error: ${target_app} missing — run scripts/build-openara-app.sh once first" >&2
  exit 1
fi

cp "${fresh_binary}" "${target_binary}"
codesign --force --sign - "${target_app}" >/dev/null 2>&1 || true

elapsed=$(( $(date +%s) - start_ts ))
echo "swapped ${target_binary} (${configuration}, ${elapsed}s)"
