# OpenAra agent guide

OpenAra is Ara's open-source Computer Use server for macOS — a local MCP
server exposing nine desktop-control tools to any AI agent.

## Read first

- [README.md](./README.md) — what OpenAra is and how to run it.
- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — module map and runtime layering.

## Working rules

- Reply in the language the user is using.
- Verify changes with `swift build` and `swift test` before claiming a task is done.
- Don't reintroduce the Linux/Windows runtimes — OpenAra is macOS-only by design.
- The nine MCP tool names and argument schemas are frozen by OpenAI's Computer Use spec; refactor implementations freely, but never the wire surface.
- Keep upstream attribution in `LICENSE` and the README "Credits" section. MIT requires the original copyright notice to remain.

## Where things live

- `apps/OpenAra/` — macOS app target (CLI + permissions onboarding GUI).
- `apps/OpenAraFixture/` — SwiftUI fixture used by smoke tests.
- `apps/OpenAraSmokeSuite/` — automated end-to-end smoke runner.
- `packages/OpenAraKit/` — the shared Swift library; the nine tools live under `Sources/OpenAraKit/Tools/`.
- `plugins/openara/` — Codex plugin manifest.
- `experiments/` — research labs (CursorMotion, StandaloneCursor) that feed back into the cursor overlay.
