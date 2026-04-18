```markdown
---
name: agentic-stack-portable-brain
description: Portable .agent/ folder (memory + skills + protocols) that plugs into Claude Code, Cursor, Windsurf, OpenCode, OpenClaw, Hermes, Pi, or DIY Python and keeps knowledge across harness switches.
triggers:
  - set up agentic stack for this project
  - install portable agent brain
  - add agent memory to my project
  - configure claude code with agentic stack
  - switch my agent to a different harness
  - set up persistent agent memory and skills
  - run the dream cycle for agent lessons
  - graduate or reject agent candidate lessons
---

# agentic-stack-portable-brain

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

## What agentic-stack does

`agentic-stack` gives any AI coding agent a **portable brain**: a `.agent/` folder containing four memory layers, a progressive-disclosure skill system, enforced permissions, and adapters for eight harnesses. When you switch from Claude Code to Cursor (or any other supported harness), the agent's accumulated knowledge travels with the project — no re-learning, no lost lessons.

### Core concepts

| Concept | Description |
|---|---|
| **Memory layers** | `working/` (session), `episodic/` (action log), `semantic/` (graduated lessons), `personal/` (preferences) |
| **Skills** | Markdown files with trigger matching; manifest always loads, full `SKILL.md` only when relevant |
| **Protocols** | Typed tool schemas, `permissions.md`, delegation contracts |
| **Review protocol** | `auto_dream.py` stages candidates mechanically; host agent reviews with CLI tools |
| **Harness adapters** | Thin shims per tool (CLAUDE.md, .windsurfrules, AGENTS.md, etc.) |

---

## Installation

### macOS / Linux (Homebrew)

```bash
brew tap codejunkie99/agentic-stack https://github.com/codejunkie99/agentic-stack
brew install agentic-stack

cd your-project
agentic-stack claude-code   # or: cursor | windsurf | opencode | openclaw | hermes | pi | standalone-python
```

### Windows (PowerShell)

```powershell
git clone https://github.com/codejunkie99/agentic-stack.git
cd agentic-stack
.\install.ps1 claude-code C:\path\to\your-project
```

### Clone and install manually

```bash
git clone https://github.com/codejunkie99/agentic-stack.git
cd agentic-stack

# macOS / Linux / Git Bash
./install.sh claude-code /path/to/your-project

# Windows PowerShell
.\install.ps1 claude-code C:\path\to\your-project
```

### Supported harness names

```
claude-code | cursor | windsurf | opencode | openclaw | hermes | pi | standalone-python
```

### Upgrade

```bash
brew update && brew upgrade agentic-stack
```

---

## Onboarding wizard

The wizard runs automatically after adapter installation and writes:
- `.agent/memory/personal/PREFERENCES.md` — first file the AI reads each session
- `.agent/memory/.features.json` — feature toggles

```bash
# accept all defaults silently (CI / scripted environments)
agentic-stack claude-code --yes

# re-run wizard on an existing project
agentic-stack claude-code --reconfigure
```

### Wizard questions

| Question | Default |
|---|---|
| What should I call you? | *(skip)* |
| Primary language(s)? | `unspecified` |
| Explanation style? | `concise` |
| Test strategy? | `test-after` |
| Commit message style? | `conventional commits` |
| Code review depth? | `critical issues only` |

### Manual preference editing

```bash
# Edit preferences any time
$EDITOR .agent/memory/personal/PREFERENCES.md

# Toggle features
$EDITOR .agent/memory/.features.json
```

`.features.json` example:

```json
{
  "fts_memory_search": false
}
```

---

## Key CLI commands

### Review protocol (host-agent tools)

```bash
# List pending candidate lessons, sorted by priority
python3 .agent/tools/list_candidates.py

# Accept a candidate (--rationale required — rubber-stamping is structurally impossible)
python3 .agent/tools/graduate.py <id> --rationale "evidence holds, matches PREFERENCES"

# Reject a candidate (--reason required; decision history preserved)
python3 .agent/tools/reject.py <id> --reason "too specific to this repo to generalize"

# Requeue a previously-rejected candidate
python3 .agent/tools/reopen.py <id>
```

### Memory search [BETA]

```bash
# Enable during onboarding or toggle manually in .features.json, then:
python3 .agent/memory/memory_search.py "deploy failure"
python3 .agent/memory/memory_search.py --status
python3 .agent/memory/memory_search.py --rebuild
```

Falls back to `ripgrep` → `grep` when FTS5 index is not enabled. Index stored at `.agent/memory/.index/` (gitignored).

### Nightly staging cycle (cron)

```bash
# Add to crontab: runs at 03:00 daily, safe to run unattended
crontab -e
# Paste:
0 3 * * * python3 /absolute/path/to/project/.agent/memory/auto_dream.py >> /absolute/path/to/project/.agent/memory/dream.log 2>&1
```

`auto_dream.py` only does mechanical work: cluster, stage, prefilter, decay. No git commits, no network calls, no LLM reasoning.

---

## Repository layout

```
.agent/
├── AGENTS.md                   # the map every harness reads
├── harness/                    # conductor + hooks (standalone path)
├── memory/
│   ├── working/                # session-scoped scratch
│   ├── episodic/               # action log (all skill events)
│   ├── semantic/
│   │   ├── lessons.jsonl       # source of truth for graduated lessons
│   │   └── LESSONS.md          # rendered from lessons.jsonl
│   ├── personal/
│   │   └── PREFERENCES.md      # loaded first every session
│   ├── auto_dream.py           # nightly staging cycle
│   ├── cluster.py              # Jaccard single-linkage clustering
│   ├── promote.py              # stage candidates
│   ├── validate.py             # heuristic prefilter
│   ├── review_state.py         # candidate lifecycle + decision log
│   ├── render_lessons.py       # lessons.jsonl → LESSONS.md
│   └── memory_search.py        # [BETA] FTS5 search
├── skills/
│   ├── _index.md               # always-loaded lightweight manifest
│   ├── _manifest.jsonl         # trigger → skill mapping
│   └── *.SKILL.md              # full skill files (lazy-loaded)
├── protocols/
│   ├── permissions.md          # enforced by pre-tool-call hook
│   ├── tool-schemas/           # typed schemas per tool
│   └── delegation.md           # sub-agent contract
└── tools/
    ├── list_candidates.py
    ├── graduate.py
    ├── reject.py
    ├── reopen.py
    ├── memory_reflect.py
    └── skill_loader.py

adapters/
├── claude-code/    # CLAUDE.md + .claude/settings.json (PostToolUse, Stop hooks)
├── cursor/         # .cursor/rules/*.mdc
├── windsurf/       # .windsurfrules
├── opencode/       # AGENTS.md + opencode.json
├── openclaw/       # .openclaw-system.md
├── hermes/         # AGENTS.md
├── pi/             # AGENTS.md + .pi/skills symlink → .agent/skills
└── standalone-python/  # run.py DIY conductor
```

---

## Seed skills (shipped with every install)

| Skill | Purpose |
|---|---|
| `skillforge` | Creates new skills from recurring patterns |
| `memory-manager` | Runs reflection cycles, surfaces candidate lessons |
| `git-proxy` | All git ops with safety constraints |
| `debug-investigator` | Reproduce → isolate → hypothesize → verify loop |
| `deploy-checklist` | Gate between staging and production |

---

## Code examples

### Python: running the staging cycle programmatically

```python
import subprocess
import sys
from pathlib import Path

def run_dream_cycle(project_root: str) -> None:
    dream_script = Path(project_root) / ".agent" / "memory" / "auto_dream.py"
    log_path = Path(project_root) / ".agent" / "memory" / "dream.log"

    if not dream_script.exists():
        raise FileNotFoundError(f"auto_dream.py not found at {dream_script}")

    with log_path.open("a") as log_file:
        result = subprocess.run(
            [sys.executable, str(dream_script)],
            stdout=log_file,
            stderr=log_file,
            cwd=project_root,
        )

    if result.returncode != 0:
        print(f"Dream cycle exited with code {result.returncode}. Check {log_path}")
    else:
        print("Dream cycle complete.")

run_dream_cycle("/path/to/your-project")
```

### Python: reading feature toggles

```python
import json
from pathlib import Path

def get_features(project_root: str) -> dict:
    features_path = Path(project_root) / ".agent" / "memory" / ".features.json"
    if not features_path.exists():
        return {}
    with features_path.open() as f:
        return json.load(f)

def is_fts_enabled(project_root: str) -> bool:
    return get_features(project_root).get("fts_memory_search", False)

# Usage
if is_fts_enabled("."):
    print("FTS memory search is active")
```

### Python: querying memory search programmatically

```python
import subprocess
import sys
from pathlib import Path

def search_memory(project_root: str, query: str) -> str:
    search_script = Path(project_root) / ".agent" / "memory" / "memory_search.py"
    result = subprocess.run(
        [sys.executable, str(search_script), query],
        capture_output=True,
        text=True,
        cwd=project_root,
    )
    return result.stdout

hits = search_memory(".", "deploy failure")
print(hits)
```

### Python: reading graduated lessons from lessons.jsonl

```python
import json
from pathlib import Path

def load_lessons(project_root: str) -> list[dict]:
    lessons_path = Path(project_root) / ".agent" / "memory" / "semantic" / "lessons.jsonl"
    if not lessons_path.exists():
        return []
    lessons = []
    with lessons_path.open() as f:
        for line in f:
            line = line.strip()
            if line:
                lessons.append(json.loads(line))
    return lessons

for lesson in load_lessons("."):
    print(lesson.get("claim"), "—", lesson.get("graduated_at"))
```

### Python: standalone harness entrypoint pattern

```python
# adapters/standalone-python/run.py pattern
import os
from pathlib import Path

AGENT_ROOT = Path(__file__).parent.parent.parent / ".agent"
PREFERENCES = AGENT_ROOT / "memory" / "personal" / "PREFERENCES.md"
LESSONS = AGENT_ROOT / "memory" / "semantic" / "LESSONS.md"
SKILL_INDEX = AGENT_ROOT / "skills" / "_index.md"

def build_system_prompt() -> str:
    parts = []
    for path in [PREFERENCES, LESSONS, SKILL_INDEX]:
        if path.exists():
            parts.append(f"## {path.name}\n{path.read_text()}")
    return "\n\n---\n\n".join(parts)

# Pass build_system_prompt() as the system message to your LLM client
system = build_system_prompt()
```

### Shell: install for a specific harness then verify

```bash
# Install for Cursor
./install.sh cursor /path/to/my-project

# Verify adapter file was written
ls /path/to/my-project/.cursor/rules/
# → agent-brain.mdc

# Verify brain is present
ls /path/to/my-project/.agent/
# → AGENTS.md  harness/  memory/  skills/  protocols/  tools/
```

### Shell: switching from OpenClient to OpenClaw (breaking change in v0.6.0)

```bash
# Remove old adapter file
rm .openclient-system.md

# Re-run installer for openclaw
./install.sh openclaw /path/to/your-project

# Verify
ls .openclaw-system.md
```

---

## Configuration reference

### `.agent/memory/personal/PREFERENCES.md`

Hand-editable at any time. Example sections:

```markdown
## Identity
Call me: Alex

## Languages
Primary: Python, TypeScript

## Style
Explanations: concise
Tests: test-after
Commits: conventional commits
Code review: critical issues only
```

### `.agent/memory/.features.json`

```json
{
  "fts_memory_search": false
}
```

Set `fts_memory_search` to `true` to enable FTS5 search index (requires SQLite with FTS5; most systems have it).

### `.agent/protocols/permissions.md`

Controls what the pre-tool-call hook allows. Example pattern:

```markdown
## Allowed
- Read any file in the project
- Write to .agent/memory/
- Run git status, git log, git diff

## Requires confirmation
- git push
- rm -rf
- Any network request outside localhost

## Always denied
- Modifying .agent/protocols/permissions.md without explicit user instruction
```

---

## Harness-specific notes

### Claude Code

Files written: `CLAUDE.md`, `.claude/settings.json`  
Hook support: `PostToolUse` (episodic logging), `Stop` (session summary)

```bash
./install.sh claude-code /path/to/project
# CLAUDE.md tells Claude to load .agent/AGENTS.md at session start
```

### Cursor

Files written: `.cursor/rules/agent-brain.mdc`  
No hook support — call reflection tools manually:

```bash
python3 .agent/tools/memory_reflect.py
```

### Windsurf

Files written: `.windsurfrules`  
Same manual reflection pattern as Cursor.

### Pi Coding Agent (v0.6.0+)

```bash
./install.sh pi /path/to/project
# Writes AGENTS.md and creates .pi/skills → .agent/skills symlink
# Safe alongside hermes/opencode — skips AGENTS.md overwrite if present
```

### Standalone Python

```bash
./install.sh standalone-python /path/to/project
# Drops adapters/standalone-python/run.py — bring your own LLM client
```

---

## How knowledge compounds

```
Session actions
    └─► episodic/ log
            └─► auto_dream.py clusters recurring patterns
                    └─► candidates staged (not committed)
                            └─► list_candidates.py → agent reviews
                                    ├─► graduate.py --rationale "..."
                                    │       └─► lessons.jsonl appended
                                    │               └─► LESSONS.md re-rendered
                                    │                       └─► future sessions load relevant lessons
                                    └─► reject.py --reason "..."
                                            └─► decision history preserved (churn visible)
```

Skills that fail 3+ times in 14 days are flagged for rewrite via the `on_failure` hook. `git log .agent/memory/` is the agent's full autobiography.

---

## Troubleshooting

### Wizard didn't run after install

```bash
# Re-run manually
python3 onboard.py claude-code /path/to/project

# Or force reconfigure
agentic-stack claude-code --reconfigure
```

### `auto_dream.py` exits non-zero

```bash
# Check the log
cat .agent/memory/dream.log | tail -50

# Common cause: relative path invocation — use absolute paths in crontab
python3 /absolute/path/.agent/memory/auto_dream.py
```

### Memory search returns nothing

```bash
# Check if FTS is enabled
python3 .agent/memory/memory_search.py --status

# Rebuild the index
python3 .agent/memory/memory_search.py --rebuild

# If FTS disabled, enable in .features.json then rebuild
```

### OpenClaw adapter not found after upgrade from v0.5.x

```bash
# Old file name was .openclient-system.md — re-run the installer
rm .openclient-system.md
./install.sh openclaw .
```

### `graduate.py` refuses to run without `--rationale`

This is intentional — the flag is structurally required to prevent rubber-stamping:

```bash
# Wrong
python3 .agent/tools/graduate.py abc123

# Right
python3 .agent/tools/graduate.py abc123 --rationale "Pattern appears in 5 episodes, consistent with PREFERENCES.md test strategy"
```

### Lessons.md out of sync with lessons.jsonl

```bash
python3 .agent/memory/render_lessons.py
```

Hand-curated content above the sentinel line in `LESSONS.md` is preserved; only the auto-rendered section below it is overwritten.

---

## Quick reference card

```bash
# Install
agentic-stack <harness>                    # brew install path
./install.sh <harness> /path/to/project    # clone path

# Onboarding
agentic-stack <harness> --yes              # CI/scripted defaults
agentic-stack <harness> --reconfigure      # re-run wizard

# Review
python3 .agent/tools/list_candidates.py
python3 .agent/tools/graduate.py <id> --rationale "..."
python3 .agent/tools/reject.py <id> --reason "..."
python3 .agent/tools/reopen.py <id>

# Memory
python3 .agent/memory/memory_search.py "query"
python3 .agent/memory/memory_search.py --rebuild
python3 .agent/memory/render_lessons.py

# Manual reflection
python3 .agent/tools/memory_reflect.py
```
```
