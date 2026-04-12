```markdown
---
name: obsidian-ai-orange-book
description: Guide and methodology for building an AI-powered personal knowledge management system using Obsidian + Claude Code
triggers:
  - set up obsidian with claude code
  - build a second brain with AI
  - obsidian vault architecture for AI
  - let AI maintain my knowledge base
  - obsidian claude code workflow
  - CLAUDE.md knowledge management setup
  - obsidian markdown AI agent memory
  - karpathy LLM wiki pattern obsidian
---

# Obsidian + Claude Code: AI-Powered Second Brain

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

## What This Project Is

This is a free, open-source guide ("Orange Book") for building an AI-native personal knowledge management (PKM) system using **Obsidian** (local Markdown vault) and **Claude Code** (AI coding agent). It covers methodology, vault architecture, workflows, and copy-paste prompts.

Core insight: Obsidian vaults are just Markdown files — the same format that AI agents (Manus, OpenClaw, Claude Code) use natively for memory. You don't need RAG or vector DBs; you let the LLM directly maintain your knowledge base.

## Installation / Getting Started

### 1. Install Obsidian

Download from [obsidian.md](https://obsidian.md) — available for macOS, Windows, Linux, iOS, Android. No account required for local use.

### 2. Install Claude Code

```bash
npm install -g @anthropic-ai/claude-code
```

Requires an Anthropic API key:

```bash
export ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
```

### 3. Open Your Vault with Claude Code

```bash
# Navigate to your Obsidian vault directory
cd ~/Documents/MyVault

# Launch Claude Code inside the vault
claude
```

Claude Code can now read, create, edit, and organize every Markdown file in your vault.

---

## Recommended Vault Architecture

```
MyVault/
├── CLAUDE.md              ← AI instruction file (critical)
├── index.md               ← Top-level map of content
├── inbox/
│   ├── index.md
│   └── ...
├── projects/
│   ├── index.md
│   └── project-name/
│       ├── index.md
│       └── notes.md
├── knowledge/
│   ├── index.md
│   ├── topic-a.md
│   └── topic-b.md
├── journal/
│   ├── index.md
│   └── 2026-04-12.md
└── resources/
    ├── index.md
    └── ...
```

### CLAUDE.md — The Most Important File

This file tells Claude Code how to navigate and operate your vault. Place it in the vault root.

```markdown
# CLAUDE.md — Vault Instructions for AI

## Vault Overview
This is my personal knowledge base. All files are Markdown.
Primary language: English (or Chinese, adjust as needed).

## Navigation
- Each folder has an `index.md` listing its contents
- Always update `index.md` when creating or moving files
- Use `[[wikilinks]]` for internal links (Obsidian syntax)

## File Naming
- Use kebab-case: `my-note-title.md`
- Date-prefixed journals: `YYYY-MM-DD.md`
- No spaces in filenames

## Frontmatter Template
Every note should start with:
```yaml
---
title: Note Title
date: YYYY-MM-DD
tags: [tag1, tag2]
status: draft | active | archived
---
```

## When Adding Knowledge
1. Check if a related note already exists before creating a new one
2. Link new notes to existing ones with `[[note-name]]`
3. Update the folder `index.md` to include the new file
4. Add relevant tags in frontmatter

## Inbox Processing
- Raw captures go in `/inbox/`
- Processed notes move to appropriate folders
- Delete or archive inbox items after processing

## Writing Style
- Concise, atomic notes (one idea per file when possible)
- Use headers (##, ###) to structure longer notes
- Bullet points for lists, not prose paragraphs
```

---

## The Karpathy LLM Wiki Pattern

Instead of building RAG (retrieval-augmented generation), let Claude Code **directly maintain** your knowledge base as a wiki.

### Setup: Knowledge Base Folder

```markdown
<!-- knowledge/index.md -->
# Knowledge Base Index

## Technology
- [[llm-fundamentals]] — How large language models work
- [[claude-code-tips]] — Claude Code workflows and tricks
- [[obsidian-plugins]] — Plugin evaluations

## Productivity
- [[pkm-methodology]] — Personal knowledge management approaches
- [[time-blocking]] — Scheduling strategies

## Reading Notes
- [[atomic-habits-notes]]
- [[thinking-fast-and-slow-notes]]
```

### Prompt: Ask Claude Code to Update the Wiki

```
I just read about [topic]. Please:
1. Check if we have an existing note on this in /knowledge/
2. If yes, update it with what I learned
3. If no, create a new atomic note
4. Update /knowledge/index.md to include it
5. Link it to related existing notes
```

---

## 7 Real Workflows (with Prompts)

### Workflow 1: Daily Journal + Weekly Review

```bash
# In your vault directory
claude
```

Prompt:
```
Create today's journal entry at /journal/2026-04-12.md using this template:
- Date and day of week header
- ## Today's Focus (3 items max)
- ## Log (timestamped entries)
- ## End of Day Reflection
- ## Tomorrow's Top 3

Then update /journal/index.md to include today's entry.
```

### Workflow 2: Process Inbox Clippings

```
I have new items in /inbox/. Please:
1. List all unprocessed files there
2. For each one, suggest which folder it belongs in
3. Ask me to confirm before moving
4. After moving, update both the source and destination index.md files
5. Add appropriate frontmatter tags if missing
```

### Workflow 3: Capture and Connect Meeting Notes

```
I just had a meeting about [topic] with [people]. Key points:
- [point 1]
- [point 2]
- Action item: [action] by [date]

Please create a meeting note, find related existing notes to link to,
and add the action item to /projects/action-items.md.
```

### Workflow 4: Build a Topic Summary

```
Look through all notes tagged with #llm or in /knowledge/ that mention 
language models. Synthesize a summary note at /knowledge/llm-overview.md 
that links to all the atomic notes. Keep it under 500 words.
```

### Workflow 5: Weekly Review Automation

```
It's Sunday. Please:
1. Read all journal entries from this week (/journal/2026-04-06.md through today)
2. Extract recurring themes, completed tasks, and unresolved questions
3. Create /journal/weekly/2026-W15.md with a structured weekly review
4. Identify any notes that should be updated based on this week's learning
```

### Workflow 6: Research Deep Dive

```
I want to learn about [topic]. Please:
1. Check what I already have in /knowledge/ related to this
2. Create a structured learning note at /knowledge/[topic].md
3. Include: What I already know, Key questions to answer, Resources to check
4. Link it to existing related notes
```

### Workflow 7: Vault Health Check

```
Please audit my vault:
1. Find notes with no internal links (orphans)
2. Find index.md files that are out of date (files exist but aren't listed)
3. Find notes with no frontmatter
4. Give me a summary report and ask which issues I want to fix first
```

---

## Essential Obsidian Plugins (4 That Matter)

Based on the guide's recommendation — out of 1000+ plugins, focus on:

| Plugin | Purpose | Install |
|--------|---------|---------|
| **Templater** | Advanced templates with variables and scripting | Community plugins → search "Templater" |
| **Dataview** | Query your vault like a database | Community plugins → search "Dataview" |
| **Git** | Auto-commit vault to GitHub | Community plugins → search "Obsidian Git" |
| **Calendar** | Visual daily note navigation | Community plugins → search "Calendar" |

### Dataview Example: List All Active Projects

```dataview
TABLE date, status, tags
FROM "projects"
WHERE status = "active"
SORT date DESC
```

### Dataview Example: Today's Tasks

```dataview
TASK
FROM "journal"
WHERE !completed
SORT file.mtime DESC
```

---

## Git Version Control for Your Vault

### Setup

```bash
cd ~/Documents/MyVault
git init
git remote add origin https://github.com/yourusername/my-vault.git
```

### .gitignore for Obsidian Vault

```gitignore
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash/
.DS_Store
```

### Obsidian Git Plugin Config

In plugin settings:
- **Auto pull interval**: 10 minutes
- **Auto commit interval**: 20 minutes  
- **Commit message**: `vault backup: {{date}}`

### Manual Commit via Claude Code

```bash
# Claude Code can run git commands
claude
```

Prompt:
```
Please commit all changes to the vault with a descriptive commit message 
summarizing what was changed today.
```

---

## index.md Pattern (Per Folder)

Every folder should have an `index.md` that acts as a map:

```markdown
---
title: Knowledge Base Index
date: 2026-04-12
type: index
---

# Knowledge Base

## Overview
Atomic notes on topics I'm actively learning or have researched.

## Contents

### AI & Machine Learning
- [[llm-fundamentals]] — Core concepts, transformers, training
- [[claude-code-tips]] — Practical Claude Code usage patterns
- [[prompt-engineering]] — Techniques for better outputs

### Productivity Systems
- [[pkm-methodology]] — PKM approaches compared
- [[gtd-implementation]] — My GTD setup in Obsidian

## Recently Updated
- 2026-04-12: Updated [[llm-fundamentals]] with GPT-4o notes
- 2026-04-10: Created [[obsidian-dataview-queries]]

## Stats
- Total notes: 47
- Last full review: 2026-04-01
```

---

## Troubleshooting

### Claude Code Can't Find Files

```bash
# Confirm you launched Claude from vault root
pwd  # should output your vault path
ls *.md  # should show CLAUDE.md and index.md
```

Ensure `CLAUDE.md` exists at vault root — this is Claude Code's primary navigation aid.

### Wikilinks Breaking

Obsidian uses `[[note-name]]` syntax (without `.md` extension). Claude Code may sometimes add `.md`. Add to `CLAUDE.md`:

```markdown
## Link Format
Always use Obsidian wikilink format: [[note-name]] NOT [note](note.md)
For aliased links: [[note-name|Display Text]]
```

### Vault Getting Disorganized

Run the health check workflow (Workflow 7 above) monthly. Also add to `CLAUDE.md`:

```markdown
## Maintenance Rules
- Never create a file outside an existing folder without asking first
- Always check for duplicate notes before creating new ones
- Keep folder depth max 3 levels
```

### API Key Issues

```bash
# Verify key is set
echo $ANTHROPIC_API_KEY

# Set for current session
export ANTHROPIC_API_KEY=your_key_here

# Add to shell profile for persistence
echo 'export ANTHROPIC_API_KEY=your_key_here' >> ~/.zshrc
```

---

## Key Concepts Summary

| Concept | Description |
|---------|-------------|
| **CLAUDE.md** | Instruction file for AI — tells Claude how to operate your vault |
| **index.md per folder** | Navigation map — lets AI understand structure without reading every file |
| **Atomic notes** | One idea per file — easier for AI to update and link |
| **LLM as compiler** | AI maintains/updates knowledge, not just retrieves it |
| **Markdown-native** | No proprietary format — AI agents work with `.md` files natively |

## Related Orange Books

- [Claude Code Orange Book](https://github.com/alchaincyf/claude-code-orange-book) — Deep dive into Claude Code itself
- [Agent Skills Orange Book](https://github.com/alchaincyf/agent-skills-orange-book) — Building custom AI agent skills
- [Claude Code Source Analysis](https://github.com/alchaincyf/claude-code-source-analysis-orange-book) — How Claude Code works internally
```
