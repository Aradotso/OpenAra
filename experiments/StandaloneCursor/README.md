# Standalone Cursor

A standalone cursor demo whose goal is to port `scripts/cursor-motion-re/official_cursor_motion.py`'s
reverse-engineered geometry + timing into a runnable Swift app — not to keep stacking tuning knobs.

## Scope

- Reuses the Python script's confirmed geometry and timing kernel:
  - 2 base candidates + 3 × 3 × 2 arched candidates
  - `sample(progress)` and `measure(...)`
  - `prefer in-bounds, then lowest score`
  - The raw spring timeline (`response=1.4`, `dampingFraction=0.9`, `dt=1/240`)
- Deliberately does **not** introduce any wall-clock duration mapping that hasn't been recovered.
- Deliberately does **not** reuse `CursorMotion`'s more experimental visual-dynamics / knob structure.

## Running

```bash
swift run StandaloneCursor
```

## Interactions

- Drag the `START` / `END` handles to recompute all 20 candidate paths in real time.
- The right panel lists every candidate with score, length, turn, and in-bounds state.
- By default it follows the Python script's selection strategy; you can also lock onto a specific candidate.
- `Replay` plays back the currently-selected path on the raw spring timeline.

## When to use it

- To check what the Python reconstruction looks like once translated to Swift.
- To quickly validate candidate pool, scores, and endpoint-lock / close-enough timing — not to tune visual feel.
- For side-by-side with `CursorMotion`, separating "binary lift fidelity" from "experimental demo."
