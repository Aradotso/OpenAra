#!/usr/bin/env bash
#
# repro-concurrent-cursor-collision.sh
#
# Spins up multiple Claude Code agents driving OpenAra in parallel as
# right-splits inside the *current* cmux workspace.
#
# Recommended flow: press cmd+n in cmux first to create a fresh workspace,
# then run this script there. The splits will land in that fresh workspace
# and your previous workspace stays untouched — cmd+1 takes you back.
#
# (The script refuses to run with more than one pre-existing pane in the
# workspace, to make it harder to clobber an existing layout. Override with
# OPENARA_REPRO_ALLOW_DIRTY=1 if you really want to.)
#
# For a faster, Claude-free verification of the cursor UX, use
# repro-quick.sh instead — it spawns parallel `openara mcp` processes with
# no cmux changes at all.
#
# Overrides:
#   OPENARA_REPRO_CC             binary to launch in each pane (default: claude)
#   OPENARA_REPRO_BOOT_DELAY     seconds to wait for the agent CLI to boot
#                                before pasting prompts (default: 8)
#   OPENARA_REPRO_PROMPTS        '|'-separated prompts (default: three built-in
#                                Safari/TextEdit prompts)
#   OPENARA_REPRO_CC_FLAGS       extra flags passed to the agent CLI
#                                (default: --dangerously-skip-permissions)
#   OPENARA_REPRO_ALLOW_DIRTY    1 to skip the "fresh workspace" precheck

set -euo pipefail

CC_CMD="${OPENARA_REPRO_CC:-claude}"
CC_FLAGS="${OPENARA_REPRO_CC_FLAGS:---dangerously-skip-permissions}"
BOOT_DELAY="${OPENARA_REPRO_BOOT_DELAY:-8}"
ALLOW_DIRTY="${OPENARA_REPRO_ALLOW_DIRTY:-0}"

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

# 1. Refuse to run unless the workspace is fresh (1 pane only). This is
#    the cleanest signal that the user pressed cmd+n first; running in a
#    busy workspace would clutter their existing layout.
pane_count="$(cmux list-panes 2>&1 | grep -c '^[* ] *pane:' || true)"
if [[ "$ALLOW_DIRTY" != "1" && "$pane_count" -gt 1 ]]; then
  echo "error: this workspace already has ${pane_count} panes — press cmd+n in cmux to" >&2
  echo "       create a fresh workspace first, then run this script there." >&2
  echo "       (set OPENARA_REPRO_ALLOW_DIRTY=1 to override.)" >&2
  exit 1
fi

# 2. Create one right-split per prompt in the *current* cmux workspace.
#    new-pane materializes terminals because the current workspace is the
#    one the user is looking at.
echo ">> spawning ${#PROMPTS[@]} right-splits in the current workspace"

surfaces=()
for ((i = 0; i < ${#PROMPTS[@]}; i++)); do
  output="$(cmux new-pane --direction right)"
  surface="$(parse_ref surface "$output")"
  if [[ -z "$surface" ]]; then
    echo "error: could not parse surface ref from: $output" >&2
    exit 1
  fi
  surfaces+=("$surface")
  echo "   pane $((i + 1)): ${surface}"
  sleep 0.3
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

>> repro running. The ${#surfaces[@]} agents are now in this workspace.
   When you want to come back to your other work, switch workspaces in
   the cmux sidebar (or close this workspace when done).

   Verify:
   - Each agent's OpenAra cursor is a different color.
   - Cursors enter from the dock area (bottom-center) and animate up.
   - Even fast AX-only ops show a visible breadcrumb.

   See live mapping: openara sessions
   Tail logs:        tail -f /tmp/openara.log
EOF
