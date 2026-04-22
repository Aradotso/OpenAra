---
name: cc-haha-local-runner
description: "Run the patched Claude Code source locally with any Anthropic-compatible API endpoint (MiniMax, OpenRouter, etc.). Use when setting up claude-code-haha, configuring custom API providers, troubleshooting TUI startup issues, or running headless print-mode queries."
triggers:
  - set up claude code haha locally
  - run claude code from source
  - configure custom API endpoint for claude code
  - use minimax or openrouter with claude code
  - fix claude code not starting
  - connect claude code to compatible API
  - run leaked claude code source
  - self-host claude code with custom model
---

# Claude Code Haha — Local Runnable Claude Code from Leaked Source

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

A patched, locally runnable version of the Claude Code source that leaked from Anthropic's npm registry on 2026-03-31. Fixes multiple blocking issues in the original leak so the full Ink TUI works. Supports any Anthropic-compatible API (MiniMax, OpenRouter, etc.).

---

## What It Does

- Full Ink TUI interactive interface (identical to official Claude Code)
- `--print` headless mode for scripts/CI
- MCP server, plugin, and Skills support
- Custom API endpoint and model configuration
- Fallback Recovery CLI mode if TUI fails

---

## Installation

### 1. Install Bun (required runtime)

```bash
# macOS / Linux
curl -fsSL https://bun.sh/install | bash

# If unzip is missing on minimal Linux
apt update && apt install -y unzip

# macOS via Homebrew
brew install bun

# Windows (PowerShell)
powershell -c "irm bun.sh/install.ps1 | iex"
```

Verify:

```bash
bun --version
```

### 2. Clone and install dependencies

```bash
git clone https://github.com/NanmiCoder/claude-code-haha.git
cd claude-code-haha
bun install
```

### 3. Configure environment

```bash
cp .env.example .env
```

Edit `.env`:

```env
# Authentication — pick ONE
ANTHROPIC_API_KEY=         # sent as x-api-key header
ANTHROPIC_AUTH_TOKEN=      # sent as Authorization: Bearer header

# Custom endpoint (omit for official Anthropic)
ANTHROPIC_BASE_URL=https://api.minimaxi.com/anthropic

# Model names — map all tiers to your provider's model
ANTHROPIC_MODEL=MiniMax-M2.7-highspeed
ANTHROPIC_DEFAULT_SONNET_MODEL=MiniMax-M2.7-highspeed
ANTHROPIC_DEFAULT_HAIKU_MODEL=MiniMax-M2.7-highspeed
ANTHROPIC_DEFAULT_OPUS_MODEL=MiniMax-M2.7-highspeed

# Timeout in ms (default 600000 = 10 min)
API_TIMEOUT_MS=3000000

# Disable telemetry and non-essential network requests
DISABLE_TELEMETRY=1
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```

---

## Key Commands

```bash
# Full interactive TUI
./bin/claude-haha

# Headless single-shot (print mode)
./bin/claude-haha -p "explain this codebase"

# Pipe input into headless mode
echo "what does main.tsx do?" | ./bin/claude-haha -p

# Force fallback Recovery CLI (plain readline)
CLAUDE_CODE_FORCE_RECOVERY_CLI=1 ./bin/claude-haha

# Help / all options
./bin/claude-haha --help
```

---

## Supported Environment Variables

| Variable | Required | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | One of two | Sent as `x-api-key` |
| `ANTHROPIC_AUTH_TOKEN` | One of two | Sent as `Authorization: Bearer` |
| `ANTHROPIC_BASE_URL` | No | Override API endpoint |
| `ANTHROPIC_MODEL` | No | Primary model name |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | No | Sonnet-tier model |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | No | Haiku-tier model |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | No | Opus-tier model |
| `API_TIMEOUT_MS` | No | Request timeout (ms) |
| `DISABLE_TELEMETRY` | No | Set `1` to disable |
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` | No | Set `1` to suppress extras |
| `CLAUDE_CODE_FORCE_RECOVERY_CLI` | No | Set `1` for plain CLI fallback |

---

## Provider Configuration Examples

### Official Anthropic API

```env
ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
ANTHROPIC_MODEL=claude-sonnet-4-5
ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-5
ANTHROPIC_DEFAULT_HAIKU_MODEL=claude-haiku-4-5
ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-5
```

### MiniMax

```env
ANTHROPIC_AUTH_TOKEN=$MINIMAX_API_KEY
ANTHROPIC_BASE_URL=https://api.minimaxi.com/anthropic
ANTHROPIC_MODEL=MiniMax-M2.7-highspeed
ANTHROPIC_DEFAULT_SONNET_MODEL=MiniMax-M2.7-highspeed
ANTHROPIC_DEFAULT_HAIKU_MODEL=MiniMax-M2.7-highspeed
ANTHROPIC_DEFAULT_OPUS_MODEL=MiniMax-M2.7-highspeed
```

### OpenRouter

```env
ANTHROPIC_AUTH_TOKEN=$OPENROUTER_API_KEY
ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1
ANTHROPIC_MODEL=anthropic/claude-sonnet-4-5
ANTHROPIC_DEFAULT_SONNET_MODEL=anthropic/claude-sonnet-4-5
ANTHROPIC_DEFAULT_HAIKU_MODEL=anthropic/claude-haiku-4-5
ANTHROPIC_DEFAULT_OPUS_MODEL=anthropic/claude-opus-4-5
```

---

## Project Structure

```
bin/claude-haha          # Entry script
preload.ts               # Bun preload — sets MACRO globals
.env.example             # Env var template
src/
├── entrypoints/cli.tsx  # CLI main entry
├── main.tsx             # TUI logic (Commander.js + React/Ink)
├── localRecoveryCli.ts  # Fallback Recovery CLI
├── setup.ts             # Startup initialization
├── screens/REPL.tsx     # Interactive REPL screen
├── ink/                 # Ink terminal render engine
├── components/          # UI components
├── tools/               # Agent tools (Bash, Edit, Grep…)
├── commands/            # Slash commands (/commit, /review…)
├── skills/              # Skill system
├── services/            # Services (API, MCP, OAuth…)
├── hooks/               # React hooks
└── utils/               # Utilities
```

---

## Common Patterns

### Run a one-shot code review in CI

```bash
#!/bin/bash
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
export ANTHROPIC_MODEL="claude-sonnet-4-5"
export DISABLE_TELEMETRY=1
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

git diff HEAD~1 | ./bin/claude-haha -p "Review this diff for bugs and security issues"
```

### Pipe a file for analysis

```bash
cat src/main.tsx | ./bin/claude-haha -p "Summarize what this file does"
```

### Use a longer timeout for large codebases

```bash
API_TIMEOUT_MS=600000 ./bin/claude-haha -p "Explain the architecture of this project"
```

### Force Recovery CLI for low-resource environments

```bash
CLAUDE_CODE_FORCE_RECOVERY_CLI=1 ./bin/claude-haha
```

---

## Troubleshooting

### TUI does not start / shows nothing

The original leak routed no-argument launches to recovery CLI. This repo fixes it, but if you see a blank screen:

```bash
# Check Bun version (needs recent)
bun --version

# Try recovery mode to confirm the API connection works
CLAUDE_CODE_FORCE_RECOVERY_CLI=1 ./bin/claude-haha
```

### Enter key does nothing in TUI

Caused by missing `modifiers-napi` native package. The repo patches this with a try-catch in the `handleEnter` path. If you still hit it:

```bash
bun install          # re-run in case native bindings failed
```

### Startup hangs immediately

Missing stub files (`verify` skill `.md`, `ultraplan/prompt.txt`, `filePersistence/types.ts`). These are included in this repo. If missing after a fresh clone:

```bash
git status           # check for untracked/missing files
git checkout .       # restore any accidentally deleted stubs
```

### `--print` mode hangs

Usually means `filePersistence/types.ts` or `ultraplan/prompt.txt` stub is absent. Verify:

```bash
ls src/filePersistence/types.ts
ls src/ultraplan/prompt.txt
```

If missing, create empty stubs:

```bash
touch src/filePersistence/types.ts
touch src/ultraplan/prompt.txt
```

### API authentication errors

- `ANTHROPIC_API_KEY` → sent as `x-api-key` header (standard Anthropic format)
- `ANTHROPIC_AUTH_TOKEN` → sent as `Authorization: Bearer <token>` (some compatible APIs require this)
- Set only one; if both are set, check which your provider expects

### Provider rejects model name

All four model env vars must be set to names your provider recognizes:

```env
ANTHROPIC_MODEL=your-provider-model-name
ANTHROPIC_DEFAULT_SONNET_MODEL=your-provider-model-name
ANTHROPIC_DEFAULT_HAIKU_MODEL=your-provider-model-name
ANTHROPIC_DEFAULT_OPUS_MODEL=your-provider-model-name
```

### Telemetry / unexpected outbound requests

```env
DISABLE_TELEMETRY=1
CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
```

---

## Key Fixes vs. Original Leaked Source

| Symptom | Root Cause | Fix Applied |
|---|---|---|
| TUI never starts | Entry script routed no-args to recovery CLI | Restored `cli.tsx` full entry path |
| Startup hangs forever | `verify` skill imports missing `.md` files; Bun text loader hangs | Created stub `.md` files |
| `--print` hangs | `filePersistence/types.ts` missing | Created type stub |
| `--print` hangs | `ultraplan/prompt.txt` missing | Created resource stub |
| Enter key does nothing | `modifiers-napi` native pkg absent; `isModifierPressed()` throws, breaking `handleEnter` | Added try-catch around modifier check |
| Setup skipped entirely | `preload.ts` auto-set `LOCAL_RECOVERY=1` bypassing all init | Removed that default |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | Bun |
| Language | TypeScript |
| Terminal UI | React + Ink |
| CLI parsing | Commander.js |
| API client | Anthropic SDK |
| Protocols | MCP, LSP |

---

## Disclaimer

This project is based on Claude Code source code that leaked from Anthropic's npm registry. All original source code copyright belongs to [Anthropic](https://www.anthropic.com). For educational and research use only.
