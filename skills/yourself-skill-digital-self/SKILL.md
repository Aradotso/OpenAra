---
name: yourself-skill-digital-self
description: "Distill a runnable AI persona from chat logs, diary entries, and photos using create-yourself. Use when building a digital twin, generating a Self Memory + Persona Model skill, merging new data into an existing self-skill, or managing persona versions and corrections."
triggers:
  - create a digital version of myself
  - distill myself into an AI skill
  - build my persona skill from chat logs
  - generate my self skill
  - create yourself skill
  - build a digital twin of me
  - make an AI that talks like me
  - run create-yourself
---

# 自己.skill (yourself-skill)

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

A Claude Code skill that distills *you* into a runnable AI persona. Provide chat logs, diary entries, and photos — the skill extracts a two-part structure: **Part A (Self Memory)** and **Part B (Persona Model)** — producing a digital copy that thinks in your logic and speaks in your voice.

Inspired by [colleague-skill](https://github.com/titanwings/colleague-skill) and [ex-partner-skill](https://github.com/therealXiaomanChu/ex-partner-skill), but the subject is **yourself**.

---

## Installation

### Into a specific project (run from git root)

```bash
mkdir -p .claude/skills
git clone https://github.com/notdog1998/yourself-skill .claude/skills/create-yourself
```

### Globally (available in all projects)

```bash
git clone https://github.com/notdog1998/yourself-skill ~/.claude/skills/create-yourself
```

### Optional Python dependencies

```bash
cd .claude/skills/create-yourself
pip install -r requirements.txt
```

---

## Core Commands

| Command | Description |
|---|---|
| `/create-yourself` | Launch the intake wizard — enter your codename, bio, self-portrait, and data sources |
| `/list-selves` | List all generated self-skills |
| `/{slug}` | Invoke your full self-skill (thinks and speaks as you) |
| `/{slug}-self` | Self-archive mode (helps you recall and analyse yourself) |
| `/{slug}-persona` | Persona-only mode (personality and expression style) |
| `/yourself-rollback {slug} {version}` | Roll back to a previous version |
| `/delete-yourself {slug}` | Delete a self-skill |

---

## Quick Start

### Step 1 — Run the intake wizard

In Claude Code:

```
/create-yourself
```

You will be prompted for:
- **Codename / slug** — e.g. `notdog` → creates `/{notdog}` commands
- **Basic info** — age, occupation, location (all optional)
- **Self-portrait** — free-text description of yourself
- **Data sources** — paths to chat exports, diary files, photo folders

All fields are skippable; a description alone is enough to generate a skill.

### Step 2 — Invoke your self-skill

```
/notdog
```

### Step 3 — Add more data later (incremental merge)

Drop new exports into the data folder, then:

```
/create-yourself --merge notdog
```

The merger prompt (`prompts/merger.md`) automatically diffs and merges new information into the existing `self.md` and `persona.md`.

---

## Data Sources

| Source | Format | Notes |
|---|---|---|
| WeChat logs | WeChatMsg / 留痕 / PyWxDump export | Best source — focus on messages *you* sent |
| QQ logs | `.txt` / `.mht` export | Good for capturing your younger self |
| Social media / diary | Screenshots / Markdown / `.txt` | Extracts values and expression style |
| Photos | JPEG/PNG (with EXIF) | Extracts timeline and locations |
| Freetext / paste | Plain text | Your own self-description |

### Recommended export tools (external, not bundled)

- **[WeChatMsg](https://github.com/LC044/WeChatMsg)** — Windows
- **[PyWxDump](https://github.com/xaoyaoo/PyWxDump)** — Windows
- **留痕** — macOS

---

## Python Tools — Direct Usage

### Parse WeChat export

```python
from tools.wechat_parser import WeChatParser

parser = WeChatParser("path/to/wechat_export.csv")
my_messages = parser.extract_self_messages(self_name="notdog")
# Returns list[dict] with keys: timestamp, content, context
print(my_messages[:3])
```

### Parse QQ export

```python
from tools.qq_parser import QQParser

parser = QQParser("path/to/qq_export.txt")
messages = parser.extract_self_messages(self_qq="123456789")
```

### Analyse photos

```python
from tools.photo_analyzer import PhotoAnalyzer

analyzer = PhotoAnalyzer("path/to/photos/")
timeline = analyzer.build_timeline()
# Returns list[dict]: {date, location, description}
for entry in timeline:
    print(entry["date"], entry["location"])
```

### Write / update a skill file

```python
from tools.skill_writer import SkillWriter

writer = SkillWriter(slug="notdog")
writer.write_self(self_memory_markdown)     # writes selves/notdog/self.md
writer.write_persona(persona_markdown)      # writes selves/notdog/persona.md
writer.write_skill_md()                     # writes selves/notdog/SKILL.md
```

### Version management

```python
from tools.version_manager import VersionManager

vm = VersionManager(slug="notdog")
vm.snapshot()                    # save current version
versions = vm.list_versions()    # ["v1", "v2", "v3"]
vm.rollback("v2")                # restore a previous snapshot
```

---

## Generated Skill Structure

Each self-skill is stored under `selves/{slug}/`:

```
selves/notdog/
├── SKILL.md          # callable skill entry point
├── self.md           # Part A — Self Memory
├── persona.md        # Part B — Persona Model (5-layer)
├── corrections.md    # live correction log
└── versions/
    ├── v1/
    └── v2/
```

### Part A — Self Memory (`self.md`)

Contains:
- Personal history and milestones
- Core values and beliefs
- Daily habits and routines
- Important memories
- Key relationships
- Growth trajectory

### Part B — Persona Model (`persona.md`) — 5-layer structure

| Layer | Content |
|---|---|
| Hard rules | Non-negotiable behaviours and absolute limits |
| Identity | Who you are at your core |
| Speech style | Vocabulary, sentence rhythm, catchphrases, emoji habits |
| Emotional patterns | How you react under stress, joy, boredom, conflict |
| Interpersonal behaviour | How you treat different types of people |

### Runtime logic

```
Incoming message
  → Persona layer: how would you respond?
  → Self Memory layer: what personal context applies?
  → Output in your voice
```

---

## Correction System

During a conversation with your self-skill, you can correct it in real time:

```
User    ❯ I would never say it that way.
Skill   ❯ Noted. How would you say it?
User    ❯ I'd just say "doesn't make sense" — I never use formal phrasing.
```

The correction is appended to `corrections.md` and takes effect immediately in the same session. It is merged into `persona.md` on the next `/create-yourself --merge` run.

---

## Project Layout

```
create-yourself/
├── SKILL.md                       # skill entry point
├── prompts/
│   ├── intake.md                  # conversational intake wizard
│   ├── self_analyzer.md           # memory/cognition extraction
│   ├── persona_analyzer.md        # personality extraction + tag table
│   ├── self_builder.md            # self.md generation template
│   ├── persona_builder.md         # 5-layer persona template
│   ├── merger.md                  # incremental merge logic
│   └── correction_handler.md      # real-time correction handling
├── tools/
│   ├── wechat_parser.py
│   ├── qq_parser.py
│   ├── social_parser.py
│   ├── photo_analyzer.py
│   ├── skill_writer.py
│   └── version_manager.py
├── selves/                        # generated self-skills (gitignored)
├── docs/PRD.md
├── requirements.txt
└── LICENSE
```

---

## Troubleshooting

**`/create-yourself` not found**
- Confirm you are inside a git repository.
- Confirm the skill is at `.claude/skills/create-yourself/SKILL.md` (project-level) or `~/.claude/skills/create-yourself/SKILL.md` (global).

**WeChat parser returns empty results**
- Verify `self_name` matches exactly the display name used in the export file (case-sensitive).
- PyWxDump exports use a different column schema than WeChatMsg — instantiate `WeChatParser(source="pywxdump")`.

**Low persona accuracy**
- Prioritise late-night conversations and emotionally charged records — they reveal authentic voice better than daytime small talk.
- Include decision-making chats to expose your reasoning patterns.
- Run a merge after adding new sources rather than regenerating from scratch.

**Rollback fails**
- Check `versions/` exists inside the slug folder: `ls selves/{slug}/versions/`.
- Run `vm.snapshot()` manually before large updates to ensure a restore point exists.

**Corrections not persisting across sessions**
- Corrections in `corrections.md` are merged into `persona.md` only on the next merge run. Run `/create-yourself --merge {slug}` to bake them in permanently.

---

## Best Practices

1. **Quality over quantity** — 500 messages you actually wrote beat 10,000 forwarded links.
2. **Prioritise in this order**: late-night monologues → emotional moments → decision conversations → daily chatter.
3. **Re-distill after major life changes** — the skill captures a checkpoint, not a continuous stream.
4. **Use `/{slug}-self` for self-reflection**, not just roleplay — it can surface patterns you haven't consciously noticed.
5. Keep `selves/` in `.gitignore` (it is by default) — your personal data should not be committed.

---

## License

MIT © [Notdog](https://github.com/notdog1998)
