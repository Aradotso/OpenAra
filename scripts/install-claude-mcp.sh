#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_helper="${script_dir}/install-config-helper.mjs"
claude_config_path="${CLAUDE_CONFIG_PATH:-${HOME}/.claude.json}"
claude_desktop_config_path="${CLAUDE_DESKTOP_CONFIG_PATH:-${HOME}/Library/Application Support/Claude/claude_desktop_config.json}"
project_root="$(pwd -P)"
server_name="openara"
command_name="openara"

usage() {
  cat <<'EOF'
Usage: ./scripts/install-claude-mcp.sh

Install the openara stdio MCP entry for both Claude Code and Claude Desktop.
  - Claude Code:    ~/.claude.json (project-scoped under the current directory)
  - Claude Desktop: ~/Library/Application Support/Claude/claude_desktop_config.json
The script is idempotent: if the same MCP server entry already exists in either
file, that file is left unchanged.
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

node "${config_helper}" claude-mcp "${claude_config_path}" "${project_root}" "${server_name}" "${command_name}"
node "${config_helper}" claude-desktop-mcp "${claude_desktop_config_path}" "${server_name}" "${command_name}"
