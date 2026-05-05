#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  cat <<'EOF' >&2
Usage:
  ./scripts/run-isolated-codex-exec.sh <computer-use|openara|all> [codex exec args...]

Examples:
  ./scripts/run-isolated-codex-exec.sh computer-use --skip-git-repo-check -C /tmp 'use computer-use to list the top three running apps'
  ./scripts/run-isolated-codex-exec.sh openara --skip-git-repo-check -C /tmp --json 'use openara to list the top three running apps'
  ./scripts/run-isolated-codex-exec.sh all --skip-git-repo-check -C /tmp 'reply with one word: ok'
EOF
  exit 1
fi

mode="$1"
shift

declare -a overrides=()

case "${mode}" in
  computer-use)
    overrides=(-c 'plugins."openara@openara-local".enabled=false')
    ;;
  openara)
    overrides=(-c 'plugins."computer-use@openai-bundled".enabled=false')
    ;;
  all)
    ;;
  *)
    echo "Unsupported mode: ${mode}" >&2
    echo "Expected one of: computer-use, openara, all" >&2
    exit 1
    ;;
esac

exec codex exec "${overrides[@]}" "$@"
