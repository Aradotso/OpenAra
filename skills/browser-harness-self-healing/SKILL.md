```markdown
---
name: browser-harness-self-healing
description: Self-healing browser harness that gives LLMs complete freedom to complete any browser task via CDP, with auto-written helpers.
triggers:
  - set up browser harness
  - automate browser with LLM
  - self-healing browser agent
  - use browser-harness for web tasks
  - connect LLM to real browser
  - browser automation with CDP
  - install browser-use harness
  - run browser task with AI agent
---

# Browser Harness (Self-Healing LLM Browser Agent)

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

Browser Harness is the simplest, thinnest self-healing harness that gives an LLM complete freedom to complete any browser task. It connects directly to Chrome via the Chrome DevTools Protocol (CDP) over a single WebSocket — no framework, no recipes, no rails. When a helper function is missing mid-task, the agent writes it into `helpers.py` and continues.

---

## Installation

### 1. Clone and read `install.md`

```bash
git clone https://github.com/browser-use/browser-harness
cd browser-harness
cat install.md
```

Always read `install.md` first — it covers the exact steps to install dependencies and connect to your real browser.

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Enable Chrome Remote Debugging

Launch Chrome with remote debugging enabled:

```bash
# macOS
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/chrome-debug

# Linux
google-chrome --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug

# Windows
"C:\Program Files\Google\Chrome\Application\chrome.exe" ^
  --remote-debugging-port=9222 --user-data-dir=C:\tmp\chrome-debug
```

When the browser opens, tick the checkbox on the setup page to allow connection.

### 4. Start the daemon

```bash
python daemon.py
```

This launches the CDP WebSocket bridge and socket server that `run.py` and `admin.py` communicate through.

---

## Core Files

| File | Lines | Purpose |
|------|-------|---------|
| `run.py` | ~36 | Runs plain Python with helpers preloaded |
| `helpers.py` | ~195 | Starting tool calls; **the agent edits this** |
| `admin.py` | ~180 | Admin/bootstrap utilities |
| `daemon.py` | ~181 | CDP WebSocket + socket bridge |
| `install.md` | — | First-time install guide |
| `SKILL.md` | — | Day-to-day usage reference |

---

## Running Tasks

### Basic usage

```bash
python run.py
```

`run.py` imports `helpers.py` and drops into an interactive loop where the agent (or you, as the agent) can call any helper directly.

### Example: star a GitHub repository

```python
# Inside run.py context — helpers are already imported
navigate("https://github.com/browser-use/browser-harness")
click('[aria-label="Star this repository"]')
```

### Example: fill a form

```python
navigate("https://example.com/form")
type_text("#name", "Jane Doe")
type_text("#email", "jane@example.com")
click('button[type="submit"]')
wait_for_selector(".success-message")
```

---

## helpers.py — Key Functions

Read `helpers.py` every time before writing a task — the agent edits it and functions evolve. Typical starting helpers:

```python
# Navigate to a URL
navigate(url: str)

# Click an element by CSS selector
click(selector: str)

# Type text into an input
type_text(selector: str, text: str)

# Wait for an element to appear
wait_for_selector(selector: str, timeout: int = 5000)

# Get text content of an element
get_text(selector: str) -> str

# Evaluate arbitrary JS in the page
evaluate(js: str) -> Any

# Take a screenshot (returns base64 PNG)
screenshot() -> str

# Scroll the page
scroll(x: int, y: int)

# Upload a file (agent writes this if missing)
upload_file(selector: str, path: str)
```

**Self-healing pattern:** If a function doesn't exist yet, the agent appends it to `helpers.py` and continues:

```
● agent: wants to upload a file
│
● helpers.py → upload_file() missing
│
● agent edits helpers.py                helpers.py  192 → 199 lines
│                                                   + upload_file()
✓ file uploaded
```

---

## CDP / WebSocket Architecture

```
  Agent (Python) → run.py → helpers.py
                                │
                           socket bridge
                                │
                           daemon.py
                                │
                      CDP WebSocket (port 9222)
                                │
                          Chrome browser
```

- `daemon.py` holds the persistent CDP connection
- All helper calls go through the socket bridge — no direct CDP in user code
- The agent only touches `helpers.py` and `run.py`

---

## Remote Browsers (Free Tier)

For sub-agents or deployment without a local browser:

1. Get a free API key (3 concurrent browsers, no card): [cloud.browser-use.com/new-api-key](https://cloud.browser-use.com/new-api-key)
2. Or let the agent sign up via [docs.browser-use.com/llms.txt](https://docs.browser-use.com/llms.txt)

```python
# Set your key before starting daemon
import os
os.environ["BROWSER_USE_API_KEY"] = "your-key-here"  # use env var, never hardcode
```

Or export in shell:

```bash
export BROWSER_USE_API_KEY=$BROWSER_USE_API_KEY
python daemon.py
```

---

## Domain Skills

Pre-learned skills for specific sites live in `domain-skills/`:

```
domain-skills/
  github/
  linkedin/
  amazon/
  ...
```

Each skill teaches the agent site-specific selectors, flows, and edge cases. **Skills are written by the harness, not by you** — run your task, and when the agent figures out something non-obvious, it files the skill itself.

To use an existing skill, the agent reads it automatically when navigating to a matching domain. To contribute, open a PR with the generated `domain-skills/<site>/` folder.

---

## Setup Prompt (for Claude Code / Codex / Cursor)

Paste this to bootstrap the entire setup:

```text
Set up https://github.com/browser-use/browser-harness for me.

Read `install.md` first to install and connect this repo to my real browser.
Then read `SKILL.md` for normal usage. Always read `helpers.py` because that
is where the functions are. When you open a setup or verification tab, activate
it so I can see the active browser tab. After it is installed, if I am already
logged in to GitHub, star this repository as a small verification task; if I
am not logged in, just go to browser-use.com.
```

---

## Common Patterns

### Pattern: navigate and extract data

```python
navigate("https://news.ycombinator.com")
titles = evaluate("""
  Array.from(document.querySelectorAll('.titleline > a'))
    .map(a => a.textContent)
    .slice(0, 10)
""")
print(titles)
```

### Pattern: wait and retry

```python
navigate("https://example.com/slow-page")
wait_for_selector(".data-table", timeout=10000)
rows = evaluate("""
  Array.from(document.querySelectorAll('.data-table tr'))
    .map(r => r.innerText)
""")
```

### Pattern: handle auth (already logged in)

```python
# The harness uses your real Chrome profile — cookies and sessions are live
navigate("https://github.com")
# If already logged in, your session is active immediately
click('a[href="/new"]')
```

### Pattern: agent writes a missing helper

```python
# Agent detects upload_file is missing, appends to helpers.py:
def upload_file(selector: str, path: str):
    abs_path = os.path.abspath(path)
    node_id = _get_node_id(selector)
    _cdp("DOM.setFileInputFiles", {"files": [abs_path], "nodeId": node_id})
```

---

## Troubleshooting

### Daemon won't connect

- Confirm Chrome is running with `--remote-debugging-port=9222`
- Visit `http://localhost:9222/json` — you should see open tabs as JSON
- Make sure no other process owns port 9222

```bash
lsof -i :9222   # macOS/Linux
netstat -ano | findstr 9222   # Windows
```

### Helper function raises `AttributeError`

- Read `helpers.py` — the function may have been renamed or not yet written
- If missing, add it to `helpers.py` following the existing CDP call pattern
- Restart `run.py` after editing `helpers.py`

### Page state is stale after navigation

```python
wait_for_selector("body", timeout=3000)
# or
evaluate("document.readyState")  # should return 'complete'
```

### Selector not found

```python
# Debug: dump all matching selectors
evaluate("document.querySelectorAll('button').length")
evaluate("document.querySelector('button')?.textContent")
# Use broader selectors if the page structure changed
click('button:contains("Submit")')  # via JS evaluate if needed
```

### Remote browser key errors

```bash
# Verify key is set
echo $BROWSER_USE_API_KEY
# Re-export and restart daemon
export BROWSER_USE_API_KEY=bu_...
python daemon.py
```

---

## Key References

- `install.md` — authoritative install steps
- `SKILL.md` — day-to-day usage (always read before a task)
- `helpers.py` — live function reference (always read; changes mid-task)
- [Bitter Lesson post](https://browser-use.com/posts/bitter-lesson-agent-frameworks)
- [Skills post](https://browser-use.com/posts/web-agents-that-actually-learn)
- [cloud.browser-use.com](https://cloud.browser-use.com) — remote browsers
- [docs.browser-use.com/llms.txt](https://docs.browser-use.com/llms.txt) — LLM-readable docs
```
