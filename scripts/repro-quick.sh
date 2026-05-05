#!/usr/bin/env bash
#
# repro-quick.sh — fastest visual verification of the multi-agent cursor UX.
#
# Spawns N concurrent `openara mcp` processes by piping JSON-RPC frames into
# their stdin (no Claude, no cmux tricks). Each one is a real OpenAra MCP
# server that registers in the cursor registry, picks a distinct color,
# animates the cursor through real tool calls, then exits and releases its
# color claim.
#
# This is the right test for verifying:
#   * Distinct cursor colors per concurrent OpenAra process (registry)
#   * Dock-area entry animation
#   * Cursor visible even on fast AX-only ops (signalToolCallStart)
#   * `openara sessions` live mapping
#
# It deliberately does NOT spin up Claude Code or split your cmux window.
# Run from anywhere; the cursors render on whatever main display you have.
#
# Usage:
#   ./scripts/repro-quick.sh                      # 3 parallel agents
#   ./scripts/repro-quick.sh -n 4                 # spawn 4
#   ./scripts/repro-quick.sh --apps Safari,TextEdit,Finder,Mail
#   ./scripts/repro-quick.sh --duration 12        # keep agents alive 12s

set -euo pipefail

n=3
apps_csv="Safari,TextEdit,Finder"
duration_secs=10
openara_bin="${OPENARA_REPRO_QUICK_OPENARA:-openara}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) n="$2"; shift 2 ;;
    --apps) apps_csv="$2"; shift 2 ;;
    --duration) duration_secs="$2"; shift 2 ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

if ! command -v "${openara_bin%% *}" >/dev/null 2>&1; then
  echo "error: ${openara_bin} not on PATH" >&2
  exit 1
fi

IFS=',' read -r -a apps <<<"${apps_csv}"

drive_one() {
  local app="$1"
  local client="$2"
  local hold_secs="$3"
  {
    printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"%s","version":"1"}}}\n' "$client"
    printf '{"jsonrpc":"2.0","method":"notifications/initialized"}\n'
    local tick=0
    while (( tick < hold_secs )); do
      printf '{"jsonrpc":"2.0","id":%d,"method":"tools/call","params":{"name":"get_app_state","arguments":{"app":"%s"}}}\n' "$((tick + 2))" "$app"
      sleep 1.5
      tick=$((tick + 2))
    done
  } | "${openara_bin}" mcp >/dev/null 2>&1
}

echo ">> spawning ${n} concurrent openara mcp processes (~${duration_secs}s each)"

pids=()
for ((i = 0; i < n; i++)); do
  app="${apps[$((i % ${#apps[@]}))]}"
  client="repro-quick-$((i + 1))"
  drive_one "$app" "$client" "$duration_secs" &
  pids+=("$!")
  echo "   agent $((i + 1)): pid=$! client=${client} → ${app}"
  sleep 0.2
done

# Wait briefly so all processes finish handshakes before snapshotting.
sleep 1.5
echo ""
echo "----- live state -----"
"${openara_bin}" sessions || true
echo ""
echo "Tail logs:        tail -f /tmp/openara.log"
echo "Live mapping:     ${openara_bin} sessions"
echo "Waiting for ${#pids[@]} agents to finish..."

wait "${pids[@]}" 2>/dev/null || true

echo ""
echo "----- after exit -----"
"${openara_bin}" sessions || true
