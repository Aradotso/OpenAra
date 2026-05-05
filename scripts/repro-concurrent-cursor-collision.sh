#!/usr/bin/env bash
#
# repro-concurrent-cursor-collision.sh
#
# Spins up multiple Claude Code agents driving OpenAra in parallel, each
# inside a fresh cmux *window* (separate macOS window) — so the test does
# NOT add splits or tabs to the cmux window you're already working in.
# The new window is what cmux materializes terminals for, and you can
# minimize it or close it when done.
#
# For a faster, Claude-free verification of the cursor UX (distinct colors,
# dock-entry animation, breadcrumb on every tool call), use repro-quick.sh
# instead — it spawns parallel `openara call` processes without any cmux
# layout changes at all.
#
# Run from anywhere with cmux on PATH:
#   ./scripts/repro-concurrent-cursor-collision.sh
#
# When it returns, switch to the new cmux window (cmd+` cycles windows) to
# watch the agents work. `openara sessions` shows the live color mapping.
#
# Overrides:
#   OPENARA_REPRO_CC             binary to launch in each pane (default: claude)
#   OPENARA_REPRO_BOOT_DELAY     seconds to wait for the agent CLI to boot
#                                before pasting prompts (default: 8)
#   OPENARA_REPRO_PROMPTS        '|'-separated prompts (default: three built-in
#                                Safari/TextEdit prompts)
#   OPENARA_REPRO_CC_FLAGS       extra flags passed to the agent CLI
#                                (default: --dangerously-skip-permissions)

set -euo pipefail

CC_CMD="${OPENARA_REPRO_CC:-claude}"
CC_FLAGS="${OPENARA_REPRO_CC_FLAGS:---dangerously-skip-permissions}"
BOOT_DELAY="${OPENARA_REPRO_BOOT_DELAY:-8}"

DEFAULT_PROMPTS=(
  "use openara to open the Wikipedia article about cats in Safari"
  "use openara to open Safari and play the YouTube Rick Roll video"
  "use openara to open TextEdit and write a short notes document about cats"
)

if [[ -n "${OPENARA_REPRO_PROMPTS:-}" ]]; then
  IFS='|' read -r -a PROMPTS <<<"${OPENARA_REPRO_PROMPTS}"
else
  PROMPTS=("${DEFAULT_PROMPTS[@]}")
fi

if ! command -v cmux >/dev/null 2>&1; then
  echo "error: cmux CLI not on PATH — run this inside a cmux session" >&2
  exit 1
fi

if ! command -v "${CC_CMD%% *}" >/dev/null 2>&1; then
  echo "error: agent CLI '${CC_CMD}' not on PATH (override with OPENARA_REPRO_CC)" >&2
  exit 1
fi

parse_ref() {
  local prefix="$1"
  local line="$2"
  printf '%s\n' "$line" \
    | awk -v p="^${prefix}:" '{for (i=1;i<=NF;i++) if ($i ~ p) print $i}' \
    | head -1
}

# 1. Spawn a fresh cmux window. cmux only materializes terminals in the
#    focused window; using a new window keeps your current window untouched
#    while still letting the agents run in real ttys.
output="$(cmux new-window 2>&1 | head -1)"
window_uuid="$(printf '%s\n' "$output" | awk '{print $NF}')"
if [[ -z "$window_uuid" ]]; then
  echo "error: could not parse window uuid from: $output" >&2
  exit 1
fi
echo ">> created cmux window ${window_uuid:0:8}…"
sleep 0.5

# 2. Add one pane per prompt to the new window. The first prompt reuses
#    the window's default pane; subsequent prompts are right-splits inside
#    the new window so all panes are visible side-by-side.
surfaces=()
existing_pane_surface="$(cmux list-pane-surfaces --window "$window_uuid" 2>&1 | awk '{for(i=1;i<=NF;i++) if($i~/^surface:/) print $i}' | head -1 || true)"
if [[ -n "$existing_pane_surface" ]]; then
  surfaces+=("$existing_pane_surface")
fi

needed=$(( ${#PROMPTS[@]} - ${#surfaces[@]} ))
for ((i = 0; i < needed; i++)); do
  output="$(cmux new-pane --window "$window_uuid" --direction right)"
  surface="$(parse_ref surface "$output")"
  if [[ -z "$surface" ]]; then
    echo "error: could not parse surface ref from: $output" >&2
    exit 1
  fi
  surfaces+=("$surface")
  sleep 0.3
done

for ((i = 0; i < ${#surfaces[@]}; i++)); do
  echo "   pane $((i + 1)): ${surfaces[$i]}"
done

# 3. Launch the agent CLI in each tab.
echo ">> launching ${CC_CMD} in each tab"
for surface in "${surfaces[@]}"; do
  cmux send --surface "$surface" "${CC_CMD} ${CC_FLAGS}" >/dev/null
  cmux send-key --surface "$surface" Enter >/dev/null
done

echo ">> waiting ${BOOT_DELAY}s for agents to boot"
sleep "${BOOT_DELAY}"

# 4. Paste prompts and submit.
echo ">> pasting prompts"
for ((i = 0; i < ${#surfaces[@]}; i++)); do
  surface="${surfaces[$i]}"
  prompt="${PROMPTS[$i]}"
  cmux send --surface "$surface" "$prompt" >/dev/null
  sleep 0.4
  cmux send-key --surface "$surface" Enter >/dev/null
  echo "   ${surface} <- ${prompt}"
done

cat <<EOF

>> repro running in cmux window ${window_uuid:0:8}…
   This window is undisturbed. cmd+\` to cycle to the new window when
   you want to watch the agents work; close that window when done.

   Verify:
   - Each agent's OpenAra cursor is a different color.
   - Cursors enter from the dock area (bottom-center) and animate up.
   - Even fast AX-only ops show a visible breadcrumb.

   See live mapping: openara sessions
   Tail logs:        tail -f /tmp/openara.log
EOF
