<div align="center">
  <h1>OpenAra</h1>
  <p><em>Open-source Computer Use, packaged as a local MCP server.</em></p>

  <p>
    <a href="https://chat.whatsapp.com/"><img src="https://img.shields.io/badge/Join-Community%20WhatsApp-25D366?style=for-the-badge&logo=whatsapp&logoColor=white" alt="Join Community WhatsApp" /></a>
    <a href="https://github.com/Aradotso/OpenAra/releases/latest"><img src="https://img.shields.io/badge/Download-for%20macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" /></a>
    <a href="https://deepwiki.com/Aradotso/OpenAra"><img src="https://img.shields.io/badge/Ask-DeepWiki-7C3AED?style=for-the-badge" alt="Ask DeepWiki" /></a>
  </p>

  <img src="./assets/brand/openara-header.png" alt="OpenAra" width="260" />
</div>

---

## Install

```bash
npm i -g @openara/cli && openara
```

---

### Add to Claude Code

```bash
openara install-claude-mcp
```

Writes `mcpServers.openara` into `~/.claude.json`.

### Add to Claude Desktop

Use the Claude Code installer above — Claude Desktop reads the same MCP config:

```bash
openara install-claude-mcp
```

### Add to Codex CLI

```bash
openara install-codex-mcp
```

Writes `[mcp_servers.openara]` into `~/.codex/config.toml`.

### Add to Codex App

```bash
openara install-codex-plugin
```

Installs OpenAra as a Codex plugin (manifest under `plugins/openara/`).

### Add to Gemini CLI

```bash
openara install-gemini-mcp                # current project (./.gemini/settings.json)
openara install-gemini-mcp --scope user   # global (~/.gemini/settings.json)
```

### Add to OpenCode

```bash
openara install-opencode-mcp
```

Writes `mcpServers.openara` into `~/.config/opencode/opencode.json`.

---

## What it gives you

- **A local Computer Use MCP server.** Nine well-tested desktop-control tools (`list_apps`, `get_app_state`, `click`, `type_text`, `press_key`, `set_value`, `scroll`, `drag`, `perform_secondary_action`) callable from any MCP-aware client.
- **Native macOS Swift** runtime — built on Accessibility + AppKit, no Electron, no Python.
- **Accessibility-first execution.** Tries to drive UI through semantic AX paths before falling back to coordinate-level HID input — you keep using your computer while the agent works.
- **One-line installers** for Claude Code, Codex CLI, Codex App (plugin), Gemini CLI, and OpenCode.
- **Visible cursor overlay** when the agent does need to move a pointer, so you can see what it's about to do.

---

## Manual MCP config

If your agent doesn't have an installer above, or you want to see exactly what's being written, here are the raw configs.

### Claude Code

Add to your project's `.claude.json`:

```json
{
  "mcpServers": {
    "openara": {
      "command": "openara",
      "args": ["mcp"]
    }
  }
}
```

### Codex CLI

Add to `~/.codex/config.toml`:

```toml
[mcp_servers.openara]
command = "openara"
args = ["mcp"]
```

### Codex App (plugin)

OpenAra ships as a Codex plugin under `plugins/openara/`. From a packaged release run `openara install-codex-plugin`. From source, point Codex App's local plugin marketplace at this repo's `.agents/plugins/marketplace.json`.

### Gemini CLI

Add to `./.gemini/settings.json` for the current project, or `~/.gemini/settings.json` for global use:

```json
{
  "mcpServers": {
    "openara": {
      "command": "openara",
      "args": ["mcp"]
    }
  }
}
```

### OpenCode

Add to `~/.config/opencode/opencode.json`:

```json
{
  "mcpServers": {
    "openara": {
      "command": "openara",
      "args": ["mcp"]
    }
  }
}
```

---

## macOS permissions

OpenAra needs **Accessibility** and **Screen Recording** to read window state and drive UI. The first run launches an onboarding window that takes you through granting both. To re-check at any time:

```bash
openara doctor
```

---

## CLI reference

```bash
openara                                          # first-run onboarding / no-op once granted
openara mcp                                      # stdio MCP server
openara call list_apps                           # one tool, prints MCP-style JSON
openara call get_app_state --args '{"app":"TextEdit"}'
openara call --calls '[{"tool":"get_app_state","args":{"app":"TextEdit"}}]'
openara call --calls-file examples/textedit-overlay-seq.json --sleep 0.5
openara doctor                                   # permissions check
openara install-claude-mcp                       # write Claude Code config
openara install-codex-mcp                        # write Codex CLI config
openara install-codex-plugin                     # install as Codex plugin
openara install-gemini-mcp [--scope user]        # write Gemini CLI config
openara install-opencode-mcp                     # write OpenCode config
openara -h
```

---

## Build from source

For contributors, or while the npm package is still being prepared:

```bash
git clone https://github.com/Aradotso/ara-cua.git
cd ara-cua/OpenAra

# Build everything (kit + apps + smoke suite)
swift build -c release

# Run the binary directly
.build/release/OpenAra -h
```

You can also run through Swift Package Manager during development. Anywhere this README says `openara <command>`, substitute `swift run OpenAra <command>` from inside the repo:

```bash
swift run OpenAra -h
swift run OpenAra mcp                  # start the stdio MCP server
swift run OpenAra call list_apps       # call a single tool
swift run OpenAra doctor               # check macOS permissions
swift run OpenAra install-claude-mcp   # write Claude Code config
```

---

## Repository layout

```
OpenAra/
├── apps/
│   ├── OpenAra/             # macOS app target (CLI + onboarding GUI)
│   ├── OpenAraFixture/      # SwiftUI fixture app for tool smoke tests
│   └── OpenAraSmokeSuite/   # automated smoke runner
├── packages/
│   └── OpenAraKit/          # the shared Swift library — the nine tools live here
├── plugins/
│   └── openara/             # Codex plugin manifest + assets
├── experiments/
│   ├── CursorMotion/        # standalone cursor-motion lab
│   └── StandaloneCursor/    # cursor overlay isolation lab
└── docs/                    # architecture, exec plans, references
```

See [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) for the full module map and [`docs/exec-plans/active/`](./docs/exec-plans/active/) for in-flight work.

---

## Cursor Motion

`experiments/CursorMotion/` is a standalone macOS app reverse-engineering the cursor motion system from public Software.Inc material. It's not part of the MCP runtime — it's a research lab whose findings feed back into OpenAra's visual cursor overlay.

---

## License

[MIT](./LICENSE) — forked from [iFurySt/open-codex-computer-use](https://github.com/iFurySt/open-codex-computer-use).
