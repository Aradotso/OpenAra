# Cursor Motion

A standalone software-cursor motion lab. Runs as its own SwiftUI demo so we can
iterate on path geometry, spring timing, and candidate visualization without
churning the production `SoftwareCursorOverlay`.

## Why a separate target

- The production `packages/OpenAraKit/.../SoftwareCursorOverlay.swift` carries
  shipping behavior; it's not a good place for experimental exploration.
- Cursor motion has its own parameter model — better to study it in isolation.
- Likely to be open-sourced separately later; the directory boundary is cleaner now.

## Module map

- `Sources/CursorMotionModel.swift` — heading-driven `direct` / `turn` / `brake` / `orbit` candidate family, official-style `VelocityVerlet` spring progress, and the visual-dynamics state that drives `tip / velocity / angle / fog`.
- `Sources/CursorLabRootView.swift` — the local demo UI, slider tuning panel, candidate-path overlay, and click interaction.
- `Sources/SynthesizedCursorGlyphView.swift` — baseline / procedural cursor renderer, mirroring `scripts/render-synthesized-software-cursor.swift`.

## References

- `docs/references/codex-computer-use-reverse-engineering/software-cursor-overlay.md`
- `docs/references/codex-computer-use-reverse-engineering/software-cursor-motion-model.md`
- `docs/exec-plans/active/20260418-standalone-cursor-lab.md`

## Running

```bash
swift run CursorMotion
```

Currently supports:

- Click anywhere on the canvas to preview the heading-driven candidate family, then auto-select a path and animate the cursor along it.
- Five sliders top-left: `START HANDLE`, `END HANDLE`, `ARC SIZE`, `ARC FLOW`, `SPRING`. No replay/reset buttons or extra metric text — keep eyes on the trajectory and the cursor.
- One toggle top-right: `DEBUG`. (`MAIL` / `CLICK` test toggles were removed; the click pulse always tracks the active move state.)
- Slider tweaks recompute the current session's reference path and keep the cursor parked at its current position, so with `DEBUG` on you still see the full curve after settling — no zero-length collapse.
- `START HANDLE` biases the start-segment guide / reach / normal; `END HANDLE` biases the end-segment guide / reach / normal. They are no longer joint scale.
- `ARC SIZE` controls the trajectory's actual curvature (height + lateral offset of the control points) and the chooser's preference for direct vs. wider arcs. It does not change cursor glyph size.
- `ARC FLOW` shifts the widest arc point earlier or later along the start→end axis. It biases a single cubic's control-point phase rather than scaling the curve.
- `SPRING` controls progress spring response/damping with no extra distance-based duration fudge. `0.5` lands exactly on the official `response=1.4`, `damping=0.9`, `343/240`-second endpoint-lock; left = faster, right = slower.
- The debug overlay shows control points, arc handles, and the chosen candidate id + score. With `DEBUG` off only the cursor is drawn.
- The `DEBUG` toggle's "on" tint reuses the slider accent gradient; "off" uses a light grey so the two states are easy to tell apart.

## Design rules for the lab

- Don't pretend unverified slider semantics are "the official implementation."
  Sliders are tuning knobs for the heading-driven lab, not 1:1 maps to the
  release binary's fields.
- The lab uses canvas bounds (after the inset) for routing and control-point
  clipping, so default samples don't get prematurely clipped.
- The lab's `ARC SIZE` is "arc height + arched family preference," not a
  binary-confirmed mapping to `tableA / tableB / arcExtent`.
- `ARC FLOW` is "phase bias of a single cubic," closer to a reverse-engineered
  `arcAnchorBias`-style geometric bias than to a confirmed binary `flow`
  field.
- `SPRING` is a centered remap around `1.4 / 0.9`. It changes spring
  `response / damping` + endpoint-lock time but does not claim to have
  recovered the release app's internal debug-slider remap helper.
- Keep the path layer, progress layer, and visible-pose layer separate.
- Without a real target window, clearly distinguish `StandaloneCursor`'s raw
  reverse-engineered pool from `CursorMotion`'s heading-driven main line.
- The demo host is replaceable; the motion model and visual dynamics should
  stay reusable.
