```markdown
---
name: builderpulse-daily-intelligence
description: AI-powered daily build intelligence for indie hackers — aggregates 300+ signals from HN, GitHub, Product Hunt, HuggingFace, Google Trends, and Reddit into actionable "what to build today" reports.
triggers:
  - "what should I build today"
  - "show me today's builderpulse report"
  - "find trending build opportunities"
  - "what are indie hackers building right now"
  - "analyze signals from hacker news and github"
  - "generate a builder intelligence report"
  - "what problems can I build in 2 hours"
  - "find underserved markets from trending topics"
---

# BuilderPulse Daily Intelligence

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

BuilderPulse aggregates 300+ signals daily from Hacker News, GitHub Trending, Product Hunt, HuggingFace, Google Trends, and Reddit to surface actionable build opportunities for indie hackers and solo builders. Every morning it publishes a structured report (in English and Chinese) answering: _"What should you build today?"_ — including a flagship "2-hour build" idea, trend analysis, and a 20-question intelligence brief.

---

## How It Works

The project is a **GitHub repository as a publishing platform**:

- Daily Markdown reports are committed to `en/YYYY/YYYY-MM-DD.md` and `zh/YYYY/YYYY-MM-DD.md`
- An RSS feed is available via GitHub's commit atom feed: `../../commits/main.atom`
- Reports reference signals sourced from 10+ platforms and synthesised by AI
- The README always shows the latest report with badge links

---

## Consuming Reports Programmatically

### Fetch Today's Report via GitHub Raw API

```python
import httpx
from datetime import date

REPO = "BuilderPulse/BuilderPulse"
TODAY = date.today().strftime("%Y-%m-%d")
YEAR = date.today().strftime("%Y")

url = f"https://raw.githubusercontent.com/{REPO}/main/en/{YEAR}/{TODAY}.md"

response = httpx.get(url)
if response.status_code == 200:
    report_md = response.text
    print(report_md[:2000])  # preview first 2000 chars
else:
    print(f"No report yet for {TODAY} (status {response.status_code})")
```

### Fetch via GitHub Contents API (with metadata)

```python
import httpx
import base64
import os

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]  # optional, increases rate limit
REPO = "BuilderPulse/BuilderPulse"
TODAY = "2026-04-16"
YEAR = "2026"

headers = {"Authorization": f"Bearer {GITHUB_TOKEN}"} if GITHUB_TOKEN else {}

url = f"https://api.github.com/repos/{REPO}/contents/en/{YEAR}/{TODAY}.md"
resp = httpx.get(url, headers=headers)
data = resp.json()

content = base64.b64decode(data["content"]).decode("utf-8")
print(content)
```

### Subscribe to RSS / Atom Feed

```
https://github.com/BuilderPulse/BuilderPulse/commits/main.atom
```

Parse with any RSS library:

```python
import feedparser

feed = feedparser.parse(
    "https://github.com/BuilderPulse/BuilderPulse/commits/main.atom"
)

for entry in feed.entries[:5]:
    print(entry.title)
    print(entry.link)
    print(entry.updated)
    print("---")
```

---

## Navigating the Report Archive

### Directory Structure

```
BuilderPulse/BuilderPulse
├── README.md                  ← always current, links to today
├── en/
│   ├── index.md               ← full English archive index
│   └── 2026/
│       ├── 2026-04-16.md
│       ├── 2026-04-15.md
│       └── ...
└── zh/
    ├── index.md               ← full Chinese archive index
    └── 2026/
        ├── 2026-04-16.md
        └── ...
```

### List All Available Reports

```python
import httpx
import os

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
REPO = "BuilderPulse/BuilderPulse"
YEAR = "2026"

headers = {"Authorization": f"Bearer {GITHUB_TOKEN}"}
url = f"https://api.github.com/repos/{REPO}/contents/en/{YEAR}"

resp = httpx.get(url, headers=headers)
files = resp.json()

report_dates = sorted([f["name"].replace(".md", "") for f in files if f["name"].endswith(".md")])
print(f"Available reports: {len(report_dates)}")
for d in report_dates[-7:]:  # last 7
    print(f"  {d} → https://github.com/{REPO}/blob/main/en/{YEAR}/{d}.md")
```

---

## Parsing Report Structure

A BuilderPulse report follows a consistent Markdown schema you can parse:

```python
import re

def parse_builderpulse_report(markdown: str) -> dict:
    """Extract key sections from a BuilderPulse daily report."""
    result = {}

    # Extract the headline summary (bold line near top)
    headline = re.search(r"\*\*Today: (.+?)\*\*", markdown)
    if headline:
        result["headline"] = headline.group(1)

    # Extract the 2-hour build idea
    build_idea = re.search(r"💡 \*\*If you had 2 hours, (.+?)\*\*", markdown)
    if build_idea:
        result["two_hour_build"] = build_idea.group(1)

    # Extract all H2/H3 section headings (signal categories)
    sections = re.findall(r"^#{2,3} (.+)$", markdown, re.MULTILINE)
    result["sections"] = sections

    # Extract all URLs referenced
    urls = re.findall(r"\(https?://[^\)]+\)", markdown)
    result["urls"] = [u.strip("()") for u in urls]

    # Extract signal source mentions
    sources = ["Hacker News", "GitHub", "Product Hunt", "HuggingFace",
               "Google Trends", "Reddit"]
    result["sources_mentioned"] = [s for s in sources if s in markdown]

    return result


# Usage
with open("2026-04-16.md") as f:
    md = f.read()

report = parse_builderpulse_report(md)
print(report["two_hour_build"])
# → "build a self-hosted social media scheduler deployable on a $10/month VPS for small agencies"
```

---

## Building a Personal Daily Digest Agent

Use BuilderPulse as a data source for your own AI-enhanced workflow:

```python
import httpx
import base64
import os
from datetime import date
from anthropic import Anthropic

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
ANTHROPIC_API_KEY = os.environ["ANTHROPIC_API_KEY"]

def fetch_todays_report() -> str:
    today = date.today()
    year = today.strftime("%Y")
    day = today.strftime("%Y-%m-%d")
    repo = "BuilderPulse/BuilderPulse"

    headers = {"Authorization": f"Bearer {GITHUB_TOKEN}"}
    url = f"https://api.github.com/repos/{repo}/contents/en/{year}/{day}.md"
    resp = httpx.get(url, headers=headers)

    if resp.status_code != 200:
        raise ValueError(f"No report for {day}")

    data = resp.json()
    return base64.b64decode(data["content"]).decode("utf-8")


def personalize_digest(report: str, your_skills: str, your_interests: str) -> str:
    client = Anthropic()

    message = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=1024,
        messages=[
            {
                "role": "user",
                "content": f"""Here is today's BuilderPulse report:

{report}

My skills: {your_skills}
My interests: {your_interests}

Based on this report, give me:
1. The top 3 build opportunities most relevant to me
2. Why each one fits my skills/interests
3. A concrete first step I could take today
Keep it under 300 words.""",
            }
        ],
    )
    return message.content[0].text


# Run it
report = fetch_todays_report()
digest = personalize_digest(
    report,
    your_skills="Python, React, solo developer",
    your_interests="developer tools, SaaS, automation"
)
print(digest)
```

---

## Setting Up a Daily Notification Bot

### GitHub Actions — Daily Slack/Discord Alert

```yaml
# .github/workflows/daily-digest.yml
name: Daily BuilderPulse Digest

on:
  schedule:
    - cron: "0 8 * * *"   # 8 AM UTC every day
  workflow_dispatch:

jobs:
  fetch-and-notify:
    runs-on: ubuntu-latest
    steps:
      - name: Fetch today's BuilderPulse report
        id: fetch
        run: |
          TODAY=$(date +%Y-%m-%d)
          YEAR=$(date +%Y)
          URL="https://raw.githubusercontent.com/BuilderPulse/BuilderPulse/main/en/${YEAR}/${TODAY}.md"
          CONTENT=$(curl -sf "$URL" || echo "NO_REPORT")
          echo "content<<EOF" >> $GITHUB_OUTPUT
          echo "$CONTENT" | head -30 >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
          echo "date=$TODAY" >> $GITHUB_OUTPUT

      - name: Post to Discord
        if: steps.fetch.outputs.content != 'NO_REPORT'
        run: |
          DATE="${{ steps.fetch.outputs.date }}"
          MSG="📡 **BuilderPulse $DATE**\nhttps://github.com/BuilderPulse/BuilderPulse/blob/main/en/${DATE:0:4}/${DATE}.md"
          curl -X POST "${{ secrets.DISCORD_WEBHOOK_URL }}" \
            -H "Content-Type: application/json" \
            -d "{\"content\": \"$MSG\"}"
```

### Python Cron Script (local)

```python
#!/usr/bin/env python3
"""Run with: python digest.py | mail -s "BuilderPulse $(date +%Y-%m-%d)" you@example.com"""

import httpx
import base64
import os
import sys
from datetime import date

def main():
    today = date.today()
    year = today.strftime("%Y")
    day = today.strftime("%Y-%m-%d")

    token = os.environ.get("GITHUB_TOKEN", "")
    headers = {"Authorization": f"Bearer {token}"} if token else {}

    url = f"https://api.github.com/repos/BuilderPulse/BuilderPulse/contents/en/{year}/{day}.md"
    resp = httpx.get(url, headers=headers, timeout=10)

    if resp.status_code == 404:
        print(f"No BuilderPulse report yet for {day}. Check back later.")
        sys.exit(0)

    resp.raise_for_status()
    content = base64.b64decode(resp.json()["content"]).decode("utf-8")
    print(content)

if __name__ == "__main__":
    main()
```

---

## Trend Tracking Across Multiple Days

```python
import httpx
import base64
import os
import re
from datetime import date, timedelta

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
REPO = "BuilderPulse/BuilderPulse"

def fetch_report(day: str) -> str | None:
    year = day[:4]
    headers = {"Authorization": f"Bearer {GITHUB_TOKEN}"}
    url = f"https://api.github.com/repos/{REPO}/contents/en/{year}/{day}.md"
    resp = httpx.get(url, headers=headers)
    if resp.status_code != 200:
        return None
    return base64.b64decode(resp.json()["content"]).decode("utf-8")


def extract_two_hour_build(report: str) -> str | None:
    m = re.search(r"💡 \*\*If you had 2 hours, (.+?)\*\*", report)
    return m.group(1) if m else None


# Pull last 7 days of build ideas
today = date.today()
print("📡 BuilderPulse — Last 7 'Two Hour Build' Ideas\n")

for i in range(7):
    day = (today - timedelta(days=i)).strftime("%Y-%m-%d")
    report = fetch_report(day)
    if report:
        idea = extract_two_hour_build(report)
        print(f"  {day}: {idea or '(not found)'}")
    else:
        print(f"  {day}: (no report)")
```

---

## Configuration & Environment Variables

| Variable | Required | Purpose |
|---|---|---|
| `GITHUB_TOKEN` | Recommended | Raises GitHub API rate limit from 60 to 5000 req/hr |
| `ANTHROPIC_API_KEY` | For AI features | Personalise reports with Claude |
| `DISCORD_WEBHOOK_URL` | For Discord bots | Post daily digest to a channel |
| `SLACK_WEBHOOK_URL` | For Slack bots | Post daily digest to a channel |

Create a `.env` file (never commit it):

```bash
GITHUB_TOKEN=ghp_...
ANTHROPIC_API_KEY=sk-ant-...
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
```

Load with:

```python
from dotenv import load_dotenv
load_dotenv()
```

---

## Common Patterns

### Pattern 1 — Check if today's report is live

```python
from datetime import date
import httpx

def report_is_live(lang="en") -> bool:
    today = date.today()
    url = (
        f"https://raw.githubusercontent.com/BuilderPulse/BuilderPulse/main/"
        f"{lang}/{today.year}/{today.strftime('%Y-%m-%d')}.md"
    )
    return httpx.head(url).status_code == 200
```

### Pattern 2 — Watch for new commits (polling)

```python
import httpx, time, os

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
last_sha = None

while True:
    headers = {"Authorization": f"Bearer {GITHUB_TOKEN}"}
    resp = httpx.get(
        "https://api.github.com/repos/BuilderPulse/BuilderPulse/commits?per_page=1",
        headers=headers
    )
    latest_sha = resp.json()[0]["sha"]
    if latest_sha != last_sha and last_sha is not None:
        print(f"🆕 New BuilderPulse commit: {latest_sha[:8]}")
        # trigger your digest pipeline here
    last_sha = latest_sha
    time.sleep(300)  # poll every 5 minutes
```

### Pattern 3 — Build a searchable local cache

```python
import httpx, base64, os, json
from pathlib import Path

GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
CACHE_DIR = Path(".builderpulse_cache")
CACHE_DIR.mkdir(exist_ok=True)

def get_report(day: str, lang="en") -> str:
    cache_file = CACHE_DIR / f"{lang}_{day}.md"
    if cache_file.exists():
        return cache_file.read_text()

    year = day[:4]
    headers = {"Authorization": f"Bearer {GITHUB_TOKEN}"}
    url = f"https://api.github.com/repos/BuilderPulse/BuilderPulse/contents/{lang}/{year}/{day}.md"
    resp = httpx.get(url, headers=headers)
    if resp.status_code != 200:
        return ""

    content = base64.b64decode(resp.json()["content"]).decode("utf-8")
    cache_file.write_text(content)
    return content
```

---

## Troubleshooting

### "403 rate limit exceeded" from GitHub API

```bash
# Check your current rate limit status
curl -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/rate_limit
```

Always pass a `GITHUB_TOKEN` — unauthenticated requests are limited to 60/hr.

### "404 Not Found" for today's report

Reports are published each morning (timezone: roughly UTC+8, Shanghai). If it's early UTC, the report may not be live yet. Use `report_is_live()` to check before fetching.

### Report content looks garbled

GitHub API returns base64-encoded content. Always decode:

```python
import base64
content = base64.b64decode(api_response["content"]).decode("utf-8")
```

### RSS feed not updating

GitHub's atom feed at `https://github.com/BuilderPulse/BuilderPulse/commits/main.atom` has aggressive CDN caching. If you need real-time updates, poll the commits API directly rather than the feed URL.

---

## Resources

- **Live site**: https://builderpulse.ai
- **Repository**: https://github.com/BuilderPulse/BuilderPulse
- **RSS/Atom**: https://github.com/BuilderPulse/BuilderPulse/commits/main.atom
- **English archive**: https://github.com/BuilderPulse/BuilderPulse/tree/main/en
- **Chinese archive**: https://github.com/BuilderPulse/BuilderPulse/tree/main/zh
- **Author on X**: https://x.com/bourneliu66
```
