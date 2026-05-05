# Architecture

OpenAra is a macOS-only Computer Use MCP server, written in Swift. It exposes
nine desktop-control tools (`list_apps`, `get_app_state`, `click`,
`perform_secondary_action`, `scroll`, `drag`, `type_text`, `press_key`,
`set_value`) over stdio JSON-RPC. Implementations prefer semantic Accessibility
paths before falling back to coordinate-level HID input.

## Directory layout

- `apps/OpenAra/` — main entry point. Owns the CLI verbs (`mcp`, `doctor`, `list-apps`, `snapshot`, `call`, `turn-ended`) plus global flags (`-h`, `-v`). Bare invocation checks permissions and only opens the dock-icon-less onboarding window when something is missing; `doctor` follows the same rule.
- `apps/OpenAraFixture/` — local SwiftUI fixture used to run deterministic click / type / scroll / drag verifications.
- `apps/OpenAraSmokeSuite/` — end-to-end smoke runner. Spawns the fixture and the MCP server and exercises every tool over JSON-RPC. Includes a separate visual-cursor idle smoke that uses a cross-process observation file to assert the next move starts as anchored-tip + small rotation, not a horizontal drift.
- `packages/OpenAraKit/` — the shared library. Tools live under `Sources/OpenAraKit/Tools/`, one struct per tool. Other modules cover MCP transport, app discovery, accessibility / window snapshots, input simulation, the visible cursor overlay, the fixture test bridge, and the public `OpenAraLogger` API.
- `experiments/CursorMotion/` — standalone Swift cursor-motion lab. Used to tune the heading-driven motion model and pose dynamics without coupling to the MCP runtime.
- `experiments/StandaloneCursor/` — Swift cursor viewer that reuses the candidate paths, scoring, and raw spring timeline derived from `scripts/cursor-motion-re/official_cursor_motion.py`. Helpful for comparison with the official binary.
- `scripts/` — repo-level build, smoke, and install scripts.
- `docs/` — architecture, reliability, CI/CD, release notes, exec plans, and the reverse-engineering reference notes.

## Runtime layers

### 1. App mode

- The default `OpenAra` invocation launches `PermissionOnboardingApp`.
- The bundle is an `LSUIElement` agent-style app, so it doesn't keep a Dock icon — but can show the permissions window when needed.
- The window renders Accessibility / Screen & System Audio Recording cards and `Allow` / `Done` states. Once both grants are present it auxiliary closes itself.
- A drag-target accessory panel deep-links to the right `System Settings` page. After the user clicks `Allow`, the panel runs a spring + curved-frame entrance from the button, lands at the bottom of the settings content area, and stays anchored there. It explicitly orders above any active `System Settings` window so a freshly-opened privacy list can't cover it. The panel includes an explicit back affordance.
- Permission state is read from TCC's persistent grant records first so a CLI subprocess and the GUI app don't disagree. Release builds ship `OpenAra.app`; local debug/dev builds use `OpenAra (Dev).app`, which the dev runtime preferentially binds to so System Settings doesn't show two identically-named entries.

### 2. MCP

- Only `stdio` transport is implemented.
- When `OPENARA_VISUAL_CURSOR` is not explicitly disabled, the `mcp` command runs inside a minimal AppKit runtime: the main thread keeps an event loop for overlay UI while the stdio server reads and replies on a background thread.
- Framing: one JSON-RPC message per line.
- Methods: `initialize`, `notifications/initialized`, `notifications/turn-ended`, `ping`, `tools/list`, `tools/call`.
- `notifications/turn-ended` is OpenAra's explicit turn-boundary hook. On receipt, the visual cursor overlay is reset. The CLI `openara turn-ended [payload]` posts a macOS distributed notification to the running AppKit MCP process so legacy hosts that send a post-turn payload can still drive cleanup.

### 3. Tool service + registry

- `ComputerUseService` maps tool calls to local capabilities. The new `ToolRegistry` pattern (under `Sources/OpenAraKit/Tools/`) wires nine `Tool` conformers — one per OpenAI Computer Use spec tool — into a name → `Tool` lookup. Each tool's `run(arguments:, service:)` extracts its arguments and delegates to the service. `ComputerUseToolDispatcher` is now a thin compatibility shim that forwards to the registry.
- `list_apps` queries Spotlight metadata for application bundles and reads `kMDItemUseCount` / `kMDItemLastUsedDate_Ranking`, then merges with `NSWorkspace`'s running-app set to produce a "running + recently-used (last 14 days)" view.
- `get_app_state` prefers real Accessibility tree + window screenshot. It does **not** call `activate` on the target app just to read state. When the target is the in-repo fixture, it falls back to the fixture-exported synthetic state.
- The `tools/list` description and input schemas track the official Computer Use surface to minimize prompt drift between hosts.
- `openara call <tool> --args '{...}'` prints an MCP-style JSON result. `openara call --calls '[...]'` (or `--calls-file <path>`) runs a sequence in the same process, sharing one `ComputerUseService` so an action tool can reuse `element_index` from the previous `get_app_state`. Sequence runs sleep 1 second between successful steps by default (override with `--sleep <seconds>`) and stop on the first `isError=true` result.
- Action tools enforce a high-risk bundle denylist on real apps: bundle-id queries return a safety denial directly; name matches are blocked from resolving to those apps. Coverage matches the official bundle's denylist for terminals, password managers, Chrome, and a few system-sensitive components.
- Element frames are reported in window-relative coordinates (origin = window's top-left), so `element_index` and screenshot pixels share one reference frame.
- Around real actions, `click` / `set_value` drive a transparent `SoftwareCursorOverlay` window. Both share one heading-driven motion kernel that produces single-side arc trajectories (with explicit turnaround when the cursor's current heading opposes the travel direction). On first show, the start point comes from AppKit's global `(0,0)` window origin, matching the official binary's fresh-state behavior. The visible tip, velocity, angle, and fog/offset are pushed through a separate visual-dynamics state so the rendered cursor isn't simply the path sample. `click` ends with a click pulse and a small but perceptible rotate wobble; `set_value` does the settle/idle without a pulse. Both keep the cursor in idle (anchored tip + small angle wobble) for a window after the action so back-to-back tools don't reset to fresh `(0,0)`. After 30 idle seconds it cleans up. `notifications/turn-ended` from the host clears it immediately.
- Overlay rendering uses the `official-software-cursor-window-252.png` baseline that ships in the repo, falling back to a procedural pointer/fog only when the asset is missing. Hit-anchor offset and neutral heading match the lab. The overlay window moves in AppKit global coordinates: AX / `CGWindowList` y-down screenspace targets are translated to AppKit globals before being handed to overlay; path selection uses the on-screen AppKit forward heading; visual dynamics translate velocity back to y-down for rendering.
- The overlay's window level isn't fixed at `.floating`. It tracks the snapshot's target window id / layer and orders itself directly above that window, not blanket-over-everything.
- Path generation uses a heading-driven candidate family (`direct` / `turn` / `brake` / `orbit`) with stable single-side-arc selection. Target-window hit-testing is a tie-breaker among similarly-scored candidates. The 20-candidate set recovered from the binary lift remains in `StandaloneCursor` and the Python script for cross-checking, but is not the runtime chooser.
- Progress along the path follows the official spring (`response=1.4`, `dampingFraction=0.9`, `dt=1/240`). Default move duration is the recovered close-enough endpoint-lock time (`343 / 240 = 1.4291667 s`); we don't shrink it by path length.
- Render input includes `rotation`, `cursorBodyOffset`, `fogOffset`, and `fogScale` so velocity lag is visible, not just internal state. `rotation` is split between `SoftwareCursorStyle.angle` and `CursorView._animatedAngleOffsetDegrees`-style components.
- Tools default to non-intrusive paths; physical-pointer fallbacks must be explicitly opted in:
  - `perform_secondary_action` only runs already-exposed AX actions; invalid actions return the official-style `... is not a valid secondary action for ...`.
  - `set_value` checks `AXUIElementIsAttributeSettable(kAXValueAttribute)` first; if non-settable it returns the official non-settable error rather than falling back to the keyboard, the clipboard, or undocumented text APIs.
  - Element-targeted left `click` tries `AXPress` / `AXConfirm` / `AXOpen` first, then descends into AX children (e.g. Finder sidebar rows that expose `AXOpen` on a cell), then AX hit-test results, then falls through to `AXRaise` / `kAXMainAttribute` / `kAXFocusedAttribute` on the window/root, then `postToPid` directed mouse events, then — only with explicit opt-in — the global physical-pointer path.
  - Coordinate clicks pass through `AXUIElementCopyElementAtPosition` first to surface a usable AX element from raw `(x, y)`.
  - `CGEvent.postToPid` is the default for `type_text` / `press_key` to avoid foreground stealing. The `press_key` xdotool parser covers `BackSpace`, `Page_Up`, `Prior` / `Next`, `F1...F12`, and `KP_*` aliases.
  - `scroll.pages` matches the official `number` schema and accepts fractional pages. Integer pages with a target exposing `AXScroll*ByPage` go through AX action; otherwise we send scroll events via `CGEvent.postToPid` directed at the target process.
  - `drag` is coordinate-only but defaults to `CGEvent.postToPid` directed events instead of global `.cghidEventTap`, so it doesn't move the user's real cursor.
  - All coordinate input is interpreted in screenshot pixels first, then mapped to window points / Quartz globals using the screenshot/window ratio — Retina mismatches don't shift clicks.
  - `click` / `scroll` / `drag` only fall through to global `CGEvent.post(tap: .cghidEventTap)` when `OPENARA_ALLOW_GLOBAL_POINTER_FALLBACKS=1` is set. The default path also doesn't call `NSRunningApplication.activate` for fallback purposes.

### 4. Fixture bridge

- `OpenAraFixture` writes its window and element state to a temp JSON file.
- `FixtureBridge` exposes a small command channel that fixture-targeted `get_app_state` and a few test-only actions use directly.
- The bridge serves only the in-repo deterministic smoke path; it doesn't define a third-party-app capability boundary.
- A SwiftPM bare-executable fixture has no stable bundle identifier, so `list_apps` injects a synthetic identifier specifically for `OpenAraFixture` to keep smoke coverage; real third-party apps pass through with their actual bundle ids.

### 5. Cursor labs

- `StandaloneCursor` (`swift run StandaloneCursor`) verifies the Python-derived motion core: 20 candidate paths, `measure + score`, `prefer in-bounds then lowest-score` selection, and the raw spring timeline. It deliberately doesn't introduce speculative wall-clock duration mappings or borrow `CursorMotion`'s pose dynamics.
- `CursorMotion` (`swift run CursorMotion`) verifies the heading-driven motion model itself: turn / brake / orbit / direct candidate family, spring progress, independent visual dynamics, debug UI. Drawn arrow angle tracks visual-dynamics heading during motion and settles back to a default resting pose, with a small idle wobble.
- Both labs render the cursor using `scripts/render-synthesized-software-cursor.swift` as a reference: prefer the repo's official `252x252` runtime baseline; fall back to procedural pointer/fog when missing. Settle is small angular wobble at fixed center, not XY drift.
- Neither lab dispatches real tool calls or writes back to the production `SoftwareCursorOverlay`. They isolate experimental noise from product behavior.

## Non-goals / boundaries

- We do not reproduce the closed-source binary's caller signing, private IPC, full overlay choreography, or self-installing plugin behavior.
- `SkyComputerUseClient` (Apple-side, in the official bundle) has launch constraints that can kill an unsigned stdio client. For direct connectivity to a Computer Use surface from your own code, use OpenAra's MCP server.
- The current onboarding has a working app, deep links, drag-target panel, official-style accessory entrance and back affordance. The click pipeline has the visible cursor, official asset fallback, and target-window-relative ordering (re-asserted while the overlay is visible so user-activated foreground apps don't cover it). It does not yet reproduce the official binary's full embedded choreography / host integration / session-approval UX.
- Screenshots are captured via `ScreenCaptureKit` and returned directly as MCP `image` content blocks (base64 PNG); they are not written to the repo or temp directories.
- Session state is per-process in-memory: most-recent snapshot + `element_index` map, per app.

## How we verify

- Unit tests: `swift test`
- Standalone cursor: `swift build --product StandaloneCursor`
- Cursor lab: `swift build --product CursorMotion`
- End-to-end smoke: `./scripts/run-tool-smoke-tests.sh` (the nine-tool smoke + the visual-cursor idle smoke)
- App bundle: `./scripts/build-openara-app.sh debug`
- npm staging: `node ./scripts/npm/build-packages.mjs`
- Release tarball: `./scripts/release-package.sh`
- Comparison artifacts: `artifacts/tool-comparisons/20260417-focus-behavior/`
- Manual diagnostics:
  - `.build/debug/OpenAra doctor`
  - `.build/debug/OpenAra snapshot <app>`
  - `.build/debug/OpenAra call list_apps`
  - `.build/debug/OpenAra call --calls '[{"tool":"get_app_state","args":{"app":"TextEdit"}}]'`
