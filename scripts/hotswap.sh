#!/usr/bin/env bash
#
# hotswap.sh — fastest local-iteration loop for OpenAra.
#
# Rebuilds just the OpenAra binary (skips iconset, plist, full app bundle
# layout) and drops it into /Applications/OpenAra.app so TCC keeps the prior
# Accessibility / Screen Recording grants. ~3s instead of ~10s for a full
# `build-openara-app.sh release`.
#
# About ~/.openara/current
#   The npm `openara` launcher prefers `~/.openara/current/dist/OpenAra.app`
#   over `/Applications/OpenAra.app` when the auto-updater has run (always,
#   on a normal install). macOS protects bundles under that path with the
#   `com.apple.provenance` xattr, so we can't safely write into them from
#   a terminal that lacks App Management permission. To make hotswap mean
#   something, this script atomically moves `~/.openara/current` aside for
#   the duration; the launcher then falls back to /Applications/. Restore
#   with `--restore` when you're done iterating, or let the next auto-update
#   tick (default: hourly) re-stage and re-link.
#
# Usage:
#   ./scripts/hotswap.sh              # build + install + ad-hoc re-sign
#   ./scripts/hotswap.sh --debug      # debug build (slower runtime, more logs)
#   ./scripts/hotswap.sh --dry        # only build, do not install
#   ./scripts/hotswap.sh --restore    # restore the parked ~/.openara/current
#                                     # symlink and exit (no rebuild)
#
# After it runs, any new MCP session (Claude Code, Codex, …) that spawns
# `openara mcp` will pick up the fresh binary. Active sessions keep the old
# binary loaded until they exit.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_app="/Applications/OpenAra.app"
target_binary="${target_app}/Contents/MacOS/OpenAra"
home_current="${HOME}/.openara/current"
home_current_parked="${HOME}/.openara/current.parked-by-hotswap"
configuration="release"
dry=0
restore=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry|--build-only) dry=1; shift ;;
    --debug) configuration="debug"; shift ;;
    --restore) restore=1; shift ;;
    -h|--help)
      sed -n '2,32p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ "${restore}" -eq 1 ]]; then
  if [[ -L "${home_current_parked}" ]]; then
    mv "${home_current_parked}" "${home_current}"
    echo "restored ${home_current} -> $(readlink "${home_current}")"
  else
    echo "no parked ${home_current_parked} to restore"
  fi
  exit 0
fi

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

# Park ~/.openara/current so the launcher falls back to /Applications/.
if [[ -L "${home_current}" ]]; then
  if [[ -e "${home_current_parked}" || -L "${home_current_parked}" ]]; then
    rm -f "${home_current_parked}"
  fi
  mv "${home_current}" "${home_current_parked}"
  echo "parked ${home_current} -> ${home_current_parked} (restore with: ${BASH_SOURCE[0]} --restore)"
fi

# Strip provenance + replace, in case /Applications/OpenAra.app inherited it
# (it can happen via Finder copies). Tolerate failure — most installs don't
# have provenance set on this path.
xattr -d com.apple.provenance "${target_binary}" 2>/dev/null || true
rm -f "${target_binary}"
cp "${fresh_binary}" "${target_binary}"
codesign --force --sign - "${target_app}" >/dev/null 2>&1 || true
echo "swapped ${target_binary}"

# Show which copy the npm launcher will actually pick.
launcher="$(command -v openara || true)"
if [[ -n "${launcher}" ]]; then
  resolved="$(node -e "
    const fs = require('fs');
    const path = require('path');
    const home = require('os').homedir();
    const candidates = [
      path.join(home, '.openara', 'current', 'dist', 'OpenAra.app', 'Contents', 'MacOS', 'OpenAra'),
      '/Applications/OpenAra.app/Contents/MacOS/OpenAra',
    ];
    for (const c of candidates) { if (fs.existsSync(c)) { console.log(c); break; } }
  " 2>/dev/null)"
  if [[ -n "${resolved}" ]]; then
    echo "next 'openara mcp' will exec: ${resolved}"
  fi
fi

elapsed=$(( $(date +%s) - start_ts ))
echo "(${configuration}, ${elapsed}s)"
