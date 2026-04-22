```markdown
---
name: mercury-agent-cosmicstack
description: Soul-driven AI agent with permission-hardened tools, token budgets, and multi-channel CLI/Telegram access
triggers:
  - set up mercury agent
  - run mercury ai agent
  - configure mercury telegram bot
  - add mercury agent to my project
  - mercury agent daemon mode
  - schedule tasks with mercury agent
  - extend mercury agent with skills
  - mercury agent token budget
---

# Mercury Agent

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

Mercury is a soul-driven AI agent that runs 24/7 from CLI or Telegram. It features 21 built-in tools, permission-hardened execution (asks before it acts), token budget enforcement, extensible skills, and daemon mode with system service integration.

---

## Installation

```bash
# One-shot via npx (no install required)
npx @cosmicstack/mercury-agent

# Global install
npm i -g @cosmicstack/mercury-agent
mercury
```

First run launches the setup wizard — enter your name, LLM API key, and optionally a Telegram bot token. Takes ~30 seconds.

---

## Key CLI Commands

```bash
# === Lifecycle ===
mercury up              # Recommended: install service + start daemon + ensure running
mercury                 # Start in foreground (same as mercury start)
mercury start           # Start in foreground
mercury start -d        # Start in background (daemon mode)
mercury restart         # Restart background process
mercury stop            # Stop background process

# === Diagnostics ===
mercury logs            # View recent daemon logs
mercury status          # Show config and daemon status
mercury doctor          # Reconfigure (Enter to keep current values)
mercury setup           # Re-run setup wizard
mercury help            # Show full manual
mercury --verbose       # Start with debug logging

# === System Service (auto-start on boot) ===
mercury service install    # Install as system service
mercury service uninstall  # Remove system service
mercury service status     # Check service status
```

---

## Configuration

All runtime data lives in `~/.mercury/` — never inside your project directory.

| Path | Purpose |
|------|---------|
| `~/.mercury/mercury.yaml` | Main config (providers, channels, budget) |
| `~/.mercury/soul/*.md` | Agent personality files |
| `~/.mercury/permissions.yaml` | Tool capabilities and approval rules |
| `~/.mercury/skills/` | Installed community skills |
| `~/.mercury/schedules.yaml` | Scheduled tasks (persisted across restarts) |
| `~/.mercury/token-usage.json` | Daily token tracking |
| `~/.mercury/memory/` | Short-term, long-term, episodic memory |
| `~/.mercury/daemon.pid` | Background process PID |
| `~/.mercury/daemon.log` | Daemon logs |

### Example `mercury.yaml`

```yaml
providers:
  - name: deepseek
    apiKey: $DEEPSEEK_API_KEY
    model: deepseek-chat
  - name: openai
    apiKey: $OPENAI_API_KEY
    model: gpt-4o-mini
  - name: anthropic
    apiKey: $ANTHROPIC_API_KEY
    model: claude-3-haiku-20240307

channels:
  telegram:
    token: $TELEGRAM_BOT_TOKEN

budget:
  dailyTokens: 100000
  conciseThreshold: 0.7  # Switch to concise mode at 70% usage

agent:
  name: Mercury
  soulDir: ~/.mercury/soul
```

### Example `permissions.yaml`

```yaml
filesystem:
  readPaths:
    - ~/projects
    - ~/Documents
  writePaths:
    - ~/projects
  requireApproval: false

shell:
  enabled: true
  requireApproval: true       # Always ask before running shell commands
  blocklist:
    - "sudo"
    - "rm -rf /"
    - "dd if="
    - "mkfs"

web:
  fetchEnabled: true
  requireApproval: false
```

---

## In-Chat Commands

These work in both CLI and Telegram without consuming API tokens:

```
/help                   Show the full manual
/status                 Show agent config, budget, and usage
/tools                  List all loaded tools
/skills                 List installed skills
/stream                 Toggle Telegram text streaming
/stream off             Disable streaming (single message delivery)
/budget                 Show token budget status
/budget override        Override budget limit for one request
/budget reset           Reset usage counter to zero
/budget set 50000       Change daily token budget to 50,000 tokens
```

---

## Built-in Tools Reference

| Category | Tool Names |
|----------|-----------|
| **Filesystem** | `read_file`, `write_file`, `create_file`, `edit_file`, `list_dir`, `delete_file`, `send_file` |
| **Shell** | `run_command`, `approve_command` |
| **Git** | `git_status`, `git_diff`, `git_log`, `git_add`, `git_commit`, `git_push` |
| **Web** | `fetch_url` |
| **Skills** | `install_skill`, `list_skills`, `use_skill` |
| **Scheduler** | `schedule_task`, `list_scheduled_tasks`, `cancel_scheduled_task` |
| **System** | `budget_status` |

---

## Soul / Personality Files

Mercury's personality is defined by markdown files you own:

```bash
~/.mercury/soul/
  soul.md        # Core identity and values
  persona.md     # How Mercury presents itself
  taste.md       # Aesthetic preferences, communication style
  heartbeat.md   # Proactive behavior and background monitoring rules
```

### Example `soul.md`

```markdown
# Soul

You are Mercury — a precise, thoughtful assistant who values clarity over verbosity.
You ask before acting on anything that could have side effects.
You prefer surgical edits over rewrites.
You treat the user's time as precious.
```

### Example `heartbeat.md`

```markdown
# Heartbeat

Every hour, check:
- Are there any failing CI pipelines in ~/projects?
- Are there unread Telegram messages that need follow-up?

Notify proactively only if something requires attention.
```

---

## Skill System

Mercury uses the [Agent Skills](https://agentskills.io) specification.

```bash
# Install a community skill (ask Mercury directly)
# In chat: "install the github-summary skill"
# Mercury calls: install_skill({ name: "github-summary" })

# List installed skills
# In chat: "/skills"

# Use a skill
# In chat: "use the github-summary skill on cosmicstack-labs/mercury-agent"
```

### Writing a Custom Skill

Skills are SKILL.md files with YAML frontmatter:

```markdown
---
name: daily-standup
description: Generate a daily standup report from git activity
version: 1.0.0
allowed-tools:
  - git_log
  - git_diff
  - run_command
triggers:
  - generate standup
  - what did I do today
  - daily report
---

# Daily Standup Skill

Fetch today's git commits across all repos in ~/projects and format
a standup report: what was done, what's in progress, any blockers.

Steps:
1. `list_dir` on ~/projects to find repos
2. `git_log --since=yesterday --author=$(git config user.email)` per repo
3. Summarize changes grouped by repo
4. Output in standup format: Done / Doing / Blockers
```

---

## Scheduler (Cron + One-Shot)

```
# In chat — schedule a recurring task:
"Every day at 9am, summarize my GitHub notifications"
# Mercury calls: schedule_task({ cron: "0 9 * * *", task: "..." })

# One-shot delayed task:
"In 15 minutes, remind me to review the PR"
# Mercury calls: schedule_task({ delay_seconds: 900, task: "..." })

# List scheduled tasks:
/tools → then ask "what tasks are scheduled?"
# Or: schedule_task → list_scheduled_tasks

# Cancel a task:
"Cancel the daily standup task"
# Mercury calls: cancel_scheduled_task({ id: "..." })
```

Tasks persist in `~/.mercury/schedules.yaml` and survive restarts. Responses route back to the channel where the task was created.

---

## Provider Fallback Pattern

Mercury tries providers in order and falls back automatically on failure:

```yaml
# mercury.yaml — order matters, first = primary
providers:
  - name: deepseek       # Primary: cost-effective
    apiKey: $DEEPSEEK_API_KEY
    model: deepseek-chat
  - name: openai         # Fallback 1
    apiKey: $OPENAI_API_KEY
    model: gpt-4o-mini
  - name: anthropic      # Fallback 2
    apiKey: $ANTHROPIC_API_KEY
    model: claude-3-haiku-20240307
```

Set environment variables before starting:

```bash
export DEEPSEEK_API_KEY=your_key_here
export OPENAI_API_KEY=your_key_here
export ANTHROPIC_API_KEY=your_key_here
export TELEGRAM_BOT_TOKEN=your_token_here

mercury up
```

---

## Telegram Setup

1. Create a bot via [@BotFather](https://t.me/BotFather) → copy token
2. Run `mercury doctor` and paste the token when prompted
3. Run `mercury up` to start daemon
4. Open your bot in Telegram and start chatting

Telegram features: HTML formatting, file uploads (photos, audio, video, documents), typing indicators, streaming toggle, all `/` commands.

---

## Daemon Mode & System Services

```bash
# Start persistent daemon (installs service on first run)
mercury up

# Platform-specific service locations:
# macOS:   ~/Library/LaunchAgents/org.cosmicstack.mercury.plist
# Linux:   ~/.config/systemd/user/mercury.service
# Windows: Task Scheduler entry "MercuryAgent"

# Check what's running
mercury status

# View live logs
mercury logs

# Crash recovery is automatic:
# - Watchdog detects crash → restarts with exponential backoff
# - Max 10 restarts/minute before cooldown
```

In daemon mode, Telegram is the primary interaction channel. CLI becomes log-only (no terminal input).

---

## Architecture Notes

- **TypeScript + Node.js 20+** — ESM modules, built with tsup, zero native dependencies
- **Vercel AI SDK v4** — `generateText` + `streamText`, 10-step agentic loop
- **grammY** — Telegram bot framework
- **Flat-file persistence** — No database; YAML + JSON in `~/.mercury/`
- **Daemon manager** — Background spawn + PID file + watchdog

---

## Common Patterns

### Pattern: Scoped file access for a project

```yaml
# permissions.yaml
filesystem:
  readPaths:
    - ~/projects/my-app
  writePaths:
    - ~/projects/my-app/src
  requireApproval: false
```

Then in chat: "Refactor all TypeScript files in src/ to use async/await" — Mercury reads freely, writes to `src/`, asks before touching anything outside.

### Pattern: Shell with approval for destructive ops

```yaml
# permissions.yaml
shell:
  enabled: true
  requireApproval: true
  blocklist:
    - "sudo"
    - "rm -rf"
    - "DROP TABLE"
    - "> /dev/sda"
```

Mercury will propose the command and wait for your "yes" before executing.

### Pattern: Daily digest via heartbeat

```markdown
# ~/.mercury/soul/heartbeat.md

Every day at 8am:
- Run `git log --since=yesterday` across ~/projects
- Fetch my top 3 GitHub notifications
- Send a digest to Telegram summarizing overnight activity
```

### Pattern: Override budget for a large task

```
# In chat when over budget:
/budget override
# Then immediately send your large request — budget is bypassed for one turn
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `mercury: command not found` | Run `npm i -g @cosmicstack/mercury-agent` or use `npx` |
| Agent not responding | `mercury status` → `mercury restart` |
| Wrong API key | `mercury doctor` → update key → Enter to keep others |
| Telegram bot silent | Check token in `mercury.yaml`, ensure `mercury up` is running |
| Over token budget | `/budget reset` or `/budget override` for one request |
| Permission denied on file | Add path to `readPaths`/`writePaths` in `permissions.yaml` |
| Skill not found | Ask Mercury: "install the X skill" — it calls `install_skill` |
| Service not starting on boot | `mercury service install` then check `mercury service status` |
| Daemon crash loop | `mercury logs` to diagnose, fix config, then `mercury up` |
| Provider errors | Check env vars are exported; add fallback provider in `mercury.yaml` |

### Debug mode

```bash
mercury --verbose       # Prints full tool call traces, provider selection, token counts
mercury logs            # View daemon log file (last N lines)
```

### Reset everything

```bash
mercury stop
rm -rf ~/.mercury
mercury setup           # Fresh wizard
```

---

## License

MIT © [Cosmic Stack](https://github.com/cosmicstack-labs)

> **Disclaimer:** This is AI — it can break sometimes. Use at your own risk.
```
