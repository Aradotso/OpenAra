#!/usr/bin/env bash
#
# repro-concurrent-cursor-collision.sh
#
# Reproduces the bug where multiple agents driving OpenAra concurrently all
# show the same orange cursor (and step on each other when they target the
# same app). Spawns three terminal panes inside the current cmux workspace,
# launches Claude Code in each, and pastes a different OpenAra-driven prompt
# into each so they all kick off roughly simultaneously.
#
# What to watch for:
#   - All three OpenAra cursors are identical orange instead of different
#     colors per agent.
#   - Two agents both targeting Safari fight for window focus / address bar.
#
# Run this from inside a cmux pane:
#   ./scripts/repro-concurrent-cursor-collision.sh
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

if [[ -z "${CMUX_WORKSPACE_ID:-}" ]]; then
  echo "error: CMUX_WORKSPACE_ID unset — run this from inside a cmux pane" >&2
  exit 1
fi

if ! command -v "${CC_CMD%% *}" >/dev/null 2>&1; then
  echo "error: agent CLI '${CC_CMD}' not on PATH (override with OPENARA_REPRO_CC)" >&2
  exit 1
fi

echo ">> spawning ${#PROMPTS[@]} cmux panes for OpenAra concurrency repro"

surfaces=()
for ((i = 0; i < ${#PROMPTS[@]}; i++)); do
  # `cmux new-pane` prints `OK surface:<N> pane:<N> workspace:<N>` on success.
  output="$(cmux new-pane --type terminal --direction right)"
  surface="$(printf '%s\n' "$output" | awk '{for (i=1;i<=NF;i++) if ($i ~ /^surface:/) print $i}' | head -1)"
  if [[ -z "$surface" ]]; then
    echo "error: could not parse surface ref from: $output" >&2
    exit 1
  fi
  surfaces+=("$surface")
  echo "   pane $((i + 1)): $surface"
  sleep 0.3
done

echo ">> launching ${CC_CMD} in each pane"
for surface in "${surfaces[@]}"; do
  cmux send --surface "$surface" "${CC_CMD} ${CC_FLAGS}"
  cmux send-key --surface "$surface" Enter
done

echo ">> waiting ${BOOT_DELAY}s for agents to boot"
sleep "${BOOT_DELAY}"

echo ">> pasting prompts"
for ((i = 0; i < ${#surfaces[@]}; i++)); do
  surface="${surfaces[$i]}"
  prompt="${PROMPTS[$i]}"
  cmux send --surface "$surface" "$prompt"
  sleep 0.4
  cmux send-key --surface "$surface" Enter
  echo "   $surface <- $prompt"
done

cat <<'EOF'

>> repro running. Observe:
   - All three OpenAra cursors render as the same orange glyph.
   - Two agents driving the same app (e.g. Safari) collide on focus.

   When fixed, expect:
   - Each agent shows a distinct cursor color (orange/blue/green/pink/...).
   - Same-app conflicts surface as a clear "another OpenAra session is
     driving <app>" rather than silent focus stealing.
EOF
