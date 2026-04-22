```markdown
---
name: agents-md-senior-engineer
description: Drop-in AGENTS.md that makes coding agents behave like senior engineers — kills sycophancy, stops drive-by refactors, forces verification loops.
triggers:
  - set up agents md in my project
  - make my coding agent behave better
  - install agents md
  - stop my AI from being sycophantic
  - configure claude code with agents md
  - add senior engineer behavior to my agent
  - set up AGENTS.md CLAUDE.md GEMINI.md
  - prevent drive-by refactors from my coding agent
---

# agents-md: Senior Engineer Behavior for Every Coding Agent

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

## What It Does

`agents-md` is a single drop-in file (`AGENTS.md`) that rewires coding agents to behave like senior engineers. It:

- **Kills sycophancy** — agents push back when you're wrong instead of agreeing and breaking working code
- **Stops drive-by refactors** — every changed line must trace to the user's request
- **Forces verification loops** — agents write and run checks before claiming "done"
- **Surfaces ambiguity** — agents ask once rather than silently guessing
- **Stays compact** — ~200 lines so rules remain loaded throughout the session

Works with Claude Code, Codex, Cursor, Gemini CLI, Aider, Windsurf, Copilot, Devin, Amp, opencode, and RooCode. No plugins, no config, no setup rituals.

---

## Install

### Option 1 — Let the agent install it (recommended)

Paste this into Claude Code, Codex, Cursor, or any coding agent at your project root:

```
Install https://github.com/TheRealSeanDonahoe/agents-md into this project.

1. Fetch `https://raw.githubusercontent.com/TheRealSeanDonahoe/agents-md/main/AGENTS.md` and save it as `./AGENTS.md` at the project root. If `AGENTS.md` already exists, stop and show me the diff before overwriting.
2. Symlink `CLAUDE.md` and `GEMINI.md` to `AGENTS.md` so Claude Code and Gemini CLI read the same file. Use the right command for my OS (`ln -s` on macOS/Linux, `New-Item -ItemType SymbolicLink` on Windows). If symlinks fail, fall back to copying the file. If `CLAUDE.md` or `GEMINI.md` already exist with content, do not overwrite — prepend `@AGENTS.md` as the first line and leave the rest intact.
3. Open the new `AGENTS.md`, find section 10 (Project context), and fill in only what you can verify by reading this codebase: stack, build/test/lint commands from `package.json`, `pyproject.toml`, `Cargo.toml`, or `Makefile`, and source/test directory layout. Leave anything you can't confirm as `TODO`.
4. Do not touch section 11 — it stays empty by design.
5. When done, tell me to restart this session so the file loads.
```

Then **restart your agent session**. Done.

### Option 2 — Manual install (bash)

```bash
# Download AGENTS.md
curl -o AGENTS.md https://raw.githubusercontent.com/TheRealSeanDonahoe/agents-md/main/AGENTS.md

# Symlink for Claude Code and Gemini CLI (macOS/Linux)
ln -s AGENTS.md CLAUDE.md
ln -s AGENTS.md GEMINI.md
```

```powershell
# Windows (PowerShell — run as admin or with Developer Mode enabled)
curl -o AGENTS.md https://raw.githubusercontent.com/TheRealSeanDonahoe/agents-md/main/AGENTS.md
New-Item -ItemType SymbolicLink -Path CLAUDE.md -Target AGENTS.md
New-Item -ItemType SymbolicLink -Path GEMINI.md -Target AGENTS.md
```

```powershell
# Windows — fallback if symlinks unavailable
Copy-Item AGENTS.md CLAUDE.md
Copy-Item AGENTS.md GEMINI.md
```

### Which file each tool reads

| Tool | File read |
|---|---|
| Codex, Cursor, Aider, Windsurf, Copilot, Devin, Amp, opencode, RooCode | `AGENTS.md` |
| Claude Code | `CLAUDE.md` |
| Gemini CLI | `GEMINI.md` |

Symlink all three to `AGENTS.md` → one source of truth.

---

## The Two Sections You Edit

Everything in `AGENTS.md` except sections 10 and 11 is the behavioral scaffold. Leave it alone.

### Section 10 — Project Context

Fill this in once after install. Takes ~5 minutes.

```markdown
## 10. Project context

**Stack:** Node 20, TypeScript 5.4, Fastify, Prisma, PostgreSQL
**Package manager:** pnpm

**Commands:**
- Build: `pnpm build`
- Test: `pnpm test`
- Lint: `pnpm lint`
- Type-check: `pnpm typecheck`

**Layout:**
- Source: `src/`
- Tests: `tests/`
- Generated: `prisma/generated/` — do not edit by hand

**Forbidden:** Never edit `prisma/generated/`. Never commit `.env`.
```

Fill in only what you can verify from `package.json`, `pyproject.toml`, `Cargo.toml`, or `Makefile`. Leave anything unverifiable as `TODO`.

### Section 11 — Project Learnings

Starts **empty**. The agent appends to it when you correct a mistake. You never write to it manually.

```markdown
## 11. Project Learnings

- Prisma migrations must be run with `pnpm prisma migrate dev`, not `migrate deploy`, in local dev.
- The `AuthService` constructor requires `ConfigService` injected — don't instantiate it directly in tests.
- All date fields in the DB are stored as UTC; always convert at the API boundary.
```

This section compounds over time. After months of real use, it becomes a trained reflex for the agent — not a manifesto.

---

## Behavioral Changes After Install

| Before | After |
|---|---|
| *"You're absolutely right!"* → reverts working code | Agent pushes back when you're wrong |
| 200 lines when 50 would do | Simplest diff that solves the problem |
| Reformats whole file while fixing a typo | Every changed line traces to your request |
| Claims "done" on code that doesn't compile | Writes verification first, runs it, then reports |
| Silently guesses between two interpretations | Surfaces ambiguity, asks once |
| Rules forgotten mid-session (file too long) | ~200 lines — rules stay loaded |

---

## Common Patterns

### Verifying the install worked

After restarting your session, ask the agent:

```
What are the rules you're operating under for this project?
```

A properly loaded agent will summarize the AGENTS.md sections including your project context from section 10.

### Adding a learning after a correction

When you correct the agent, say:

```
Add that to section 11 of AGENTS.md as a project learning.
```

The agent will append a one-line learning. You don't write to the file yourself.

### Scoping rules to specific file paths (Claude Code)

If your codebase grows large enough that one file isn't enough, use Claude Code's native path-scoped rules instead of putting everything in `CLAUDE.md`:

```
.claude/rules/api.md        # loads only when touching src/api/**
.claude/rules/database.md   # loads only when touching prisma/**
```

Frontmatter for a scoped rule:

```markdown
---
paths:
  - src/api/**
---

# API rules

- All routes must have Zod input validation.
- Never return raw Prisma errors to the client.
```

### Cursor path-scoped rules

```
.cursor/rules/tests.mdc     # loads only when touching tests/**
```

### Keeping Claude.md pointing to AGENTS.md (existing file)

If `CLAUDE.md` already exists with project-specific content, don't overwrite it. Prepend the import reference as the first line:

```markdown
@AGENTS.md

<!-- your existing CLAUDE.md content below -->
```

Claude Code will load `AGENTS.md` first, then apply anything below.

---

## Updating AGENTS.md

```bash
# Re-fetch latest version
curl -o AGENTS.md https://raw.githubusercontent.com/TheRealSeanDonahoe/agents-md/main/AGENTS.md

# Symlinks update automatically — nothing else to do on macOS/Linux
# On Windows with copied files, re-copy:
# Copy-Item AGENTS.md CLAUDE.md; Copy-Item AGENTS.md GEMINI.md
```

After updating, restart your agent session.

---

## Troubleshooting

### Agent ignores the rules

- Confirm the file exists at project root: `ls -la AGENTS.md CLAUDE.md GEMINI.md`
- Confirm symlinks resolve: `cat CLAUDE.md` should show AGENTS.md content
- **Restart the session** — most agents load context files at session start only
- Check file size: if AGENTS.md is under 1 KB the download likely failed; re-curl

### Symlink fails on Windows

```powershell
# Check if Developer Mode is on (Settings > For developers > Developer Mode)
# Or run PowerShell as Administrator, then:
New-Item -ItemType SymbolicLink -Path CLAUDE.md -Target AGENTS.md

# If still failing, use copy fallback:
Copy-Item AGENTS.md CLAUDE.md
Copy-Item AGENTS.md GEMINI.md
```

### CLAUDE.md or GEMINI.md already existed

Don't overwrite. Add `@AGENTS.md` as the first line of the existing file:

```bash
# macOS/Linux — prepend the import
echo '@AGENTS.md' | cat - CLAUDE.md > /tmp/claude_tmp && mv /tmp/claude_tmp CLAUDE.md
```

### Agent still sycophantic after install

The behavioral rules take effect at session start. If behavior didn't change:

1. Restart the session
2. Ask: *"What does your AGENTS.md say about disagreeing with the user?"* — the agent should quote the anti-sycophancy rule
3. If it can't, the file isn't loading — check the path and file content

### Section 10 has TODOs the agent filled in wrong

The agent is only supposed to fill in what it can verify from config files. Fix wrong entries manually, then add a line to section 11:

```markdown
- Stack is Python 3.12 + FastAPI, not Node — agent inferred wrong from a stray package.json in a subdirectory.
```

---

## Architecture: Why It Stays Small

The file is deliberately ~200 lines. Context windows are finite. Every line of AGENTS.md competes with your codebase, diffs, and tool outputs for the agent's attention. Bloated instruction files cause rules to drop out mid-session.

The design principle: **tight rules that stay loaded beat comprehensive rules that get forgotten.**

Section 11 (Project Learnings) scales the system without scaling the file — one line per correction, appended over time, replacing general rules with specific institutional knowledge about your project.

---

## References

- [AGENTS.md repo](https://github.com/TheRealSeanDonahoe/agents-md)
- [agents.md open standard](https://agents.md) — Linux Foundation Agentic AI Foundation
- [Claude Code best practices](https://code.claude.com/docs/en/best-practices)
- Andrej Karpathy's four principles on LLM coding failure modes
- Boris Cherny's Claude Code workflow (reactive pruning, accumulated learnings)
```
