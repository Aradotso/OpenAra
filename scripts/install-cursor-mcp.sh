#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_helper="${script_dir}/install-config-helper.mjs"
cursor_config_path="${CURSOR_CONFIG_PATH:-${HOME}/.cursor/mcp.json}"
server_name="openara"
command_name="openara"

usage() {
  cat <<'EOF'
Usage: ./scripts/install-cursor-mcp.sh

Install the openara stdio MCP entry into ~/.cursor/mcp.json (Cursor's global
MCP server config). The script is idempotent: if the same MCP server entry
already exists, the file is left unchanged.

Override the target with CURSOR_CONFIG_PATH=/path/to/mcp.json (e.g. point at
<project>/.cursor/mcp.json for project-scoped install).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

node "${config_helper}" cursor-mcp "${cursor_config_path}" "${server_name}" "${command_name}"
