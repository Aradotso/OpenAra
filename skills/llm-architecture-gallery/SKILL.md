---
name: llm-architecture-gallery
description: "Manage models.yml entries and architecture images for Sebastian Raschka's LLM Architecture Gallery. Use when adding a new model entry, updating model metadata, contributing architecture diagrams, or querying the gallery's YAML schema."
triggers:
  - add a model to the LLM architecture gallery
  - update models.yml for the architecture gallery
  - how do I contribute a new LLM architecture entry
  - edit the LLM gallery metadata
  - add image and metadata for a new language model
  - update model facts in the architecture gallery
  - how does the models.yml schema work
  - submit a new entry to rasbt llm architecture gallery
---

# LLM Architecture Gallery

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

## What This Project Does

The [LLM Architecture Gallery](https://sebastianraschka.com/llm-architecture-gallery/) is a visual catalog of large language model architectures. This repository (`rasbt/llm-architecture-gallery`) is the **source data layer** — it contains the `models.yml` file that drives every gallery card: model names, architecture images, release dates, fact-sheet fields, and external links.

The live site reads from this repo. Contributing here means your model entry appears on the public gallery.

---

## Repository Structure

```
llm-architecture-gallery/
├── models.yml          # Primary data file — all model metadata
└── images/
    └── architectures/  # .webp architecture diagrams
        └── hero/       # Hero/banner images
```

---

## The `models.yml` Schema

Each top-level key is the **canonical model name** as it appears on the gallery card.

### Minimal Entry

```yaml
GPT-4o:
  image: "/llm-architecture-gallery/images/architectures/gpt-4o.webp"
  date: '2024-05-13'
```

### Full Entry (all known fields)

```yaml
DeepSeek R1:
  image: "/llm-architecture-gallery/images/architectures/deepseek-v3-r1-671-billion.webp"
  date: '2025-01-20'
  parameters: "671B"
  architecture: "Mixture of Experts (MoE)"
  context_length: "128K"
  organization: "DeepSeek"
  license: "MIT"
  paper: "https://arxiv.org/abs/2501.12948"
  code: "https://github.com/deepseek-ai/DeepSeek-R1"
  notes: "Reasoning model trained via reinforcement learning."
```

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `image` | string (path) | Yes | Site-relative path to architecture `.webp` image |
| `date` | string (YYYY-MM-DD) | Yes | Public release / paper date |
| `parameters` | string | No | E.g. `"7B"`, `"671B"`, `"1.5T"` |
| `architecture` | string | No | E.g. `"Transformer"`, `"MoE"`, `"SSM"` |
| `context_length` | string | No | E.g. `"128K"`, `"1M"` |
| `organization` | string | No | Releasing organization |
| `license` | string | No | SPDX identifier or descriptive string |
| `paper` | string (URL) | No | arXiv or official paper link |
| `code` | string (URL) | No | GitHub or official code link |
| `notes` | string | No | Short freeform description |

---

## Image URL Convention

Images are stored under `/llm-architecture-gallery/images/architectures/` as `.webp` files.

To get a full public URL, prepend `https://sebastianraschka.com`:

```
# Stored path in models.yml:
/llm-architecture-gallery/images/architectures/deepseek-v3-r1-671-billion.webp

# Full public URL:
https://sebastianraschka.com/llm-architecture-gallery/images/architectures/deepseek-v3-r1-671-billion.webp
```

**Naming convention for image files:**
- lowercase, hyphen-separated
- include organization or model family when helpful
- suffix with parameter count if known
- always `.webp` format

Examples:
```
llama-3-70-billion.webp
mistral-7b.webp
deepseek-v3-r1-671-billion.webp
gemma-2-27b.webp
```

---

## Adding a New Model Entry

### Step 1 — Prepare the architecture image

Convert your diagram to `.webp` and place it at:
```
images/architectures/<model-slug>.webp
```

Recommended dimensions: ~1200×900px or similar landscape ratio.

### Step 2 — Add entry to `models.yml`

Open `models.yml` and insert your entry. Entries are **not required to be sorted**, but keeping them roughly chronological by `date` helps reviewers.

```yaml
Llama 3.1 405B:
  image: "/llm-architecture-gallery/images/architectures/llama-3-1-405-billion.webp"
  date: '2024-07-23'
  parameters: "405B"
  architecture: "Transformer (GQA)"
  context_length: "128K"
  organization: "Meta"
  license: "Llama 3.1 Community License"
  paper: "https://arxiv.org/abs/2407.21783"
  code: "https://github.com/meta-llama/llama3"
  notes: "Flagship open-weights model from Meta's Llama 3.1 family."
```

### Step 3 — Validate YAML syntax

```bash
# Python — validate the file parses without errors
python3 -c "
import yaml, sys
with open('models.yml') as f:
    data = yaml.safe_load(f)
print(f'OK: {len(data)} models loaded')
for name, meta in data.items():
    if 'image' not in meta:
        print(f'WARNING: {name!r} missing image field')
    if 'date' not in meta:
        print(f'WARNING: {name!r} missing date field')
"
```

### Step 4 — Open a Pull Request

```bash
git checkout -b add-llama-3-1-405b
git add models.yml images/architectures/llama-3-1-405-billion.webp
git commit -m "Add Llama 3.1 405B entry"
git push origin add-llama-3-1-405b
# Then open PR at: https://github.com/rasbt/llm-architecture-gallery/pulls
```

---

## Working with `models.yml` Programmatically

### Python — load and query all entries

```python
import yaml
from pathlib import Path
from datetime import date

with open("models.yml") as f:
    models = yaml.safe_load(f)

# List all models sorted by date
sorted_models = sorted(
    models.items(),
    key=lambda kv: kv[1].get("date", "1900-01-01")
)

for name, meta in sorted_models:
    print(f"{meta.get('date', 'unknown')}  {name}  [{meta.get('parameters', '?')}]")
```

### Python — find all MoE models

```python
import yaml

with open("models.yml") as f:
    models = yaml.safe_load(f)

moe_models = {
    name: meta
    for name, meta in models.items()
    if "moe" in meta.get("architecture", "").lower()
    or "mixture" in meta.get("architecture", "").lower()
}

for name, meta in moe_models.items():
    print(f"{name}: {meta.get('architecture')} — {meta.get('parameters', '?')}")
```

### Python — add a new model entry programmatically

```python
import yaml
from collections import OrderedDict

NEW_MODEL = {
    "Phi-4": {
        "image": "/llm-architecture-gallery/images/architectures/phi-4-14b.webp",
        "date": "2024-12-12",
        "parameters": "14B",
        "architecture": "Transformer",
        "context_length": "16K",
        "organization": "Microsoft",
        "license": "MIT",
        "paper": "https://arxiv.org/abs/2412.08905",
        "code": "https://huggingface.co/microsoft/phi-4",
        "notes": "Small language model emphasizing reasoning and STEM."
    }
}

with open("models.yml") as f:
    models = yaml.safe_load(f)

models.update(NEW_MODEL)

with open("models.yml", "w") as f:
    yaml.dump(models, f, allow_unicode=True, sort_keys=False, default_flow_style=False)

print(f"Written. Total models: {len(models)}")
```

---

## Common Patterns

### Check for missing required fields across all entries

```python
import yaml

REQUIRED = {"image", "date"}

with open("models.yml") as f:
    models = yaml.safe_load(f)

issues = []
for name, meta in models.items():
    for field in REQUIRED:
        if field not in meta:
            issues.append(f"  {name!r}: missing '{field}'")

if issues:
    print("Validation errors:")
    print("\n".join(issues))
else:
    print(f"All {len(models)} entries valid.")
```

---

## Troubleshooting

### YAML parse errors

```bash
# Quick check with Python
python3 -c "import yaml; yaml.safe_load(open('models.yml'))"

# Or install yamllint for detailed feedback
pip install yamllint
yamllint models.yml
```

Common causes:
- Unquoted strings containing `:` — wrap in quotes: `"Transformer: GQA"`
- Inconsistent indentation (mix of tabs and spaces)
- Missing quotes around dates that look like floats: use `'2024-01-01'` not `2024-01-01`

### Image path not resolving on the live site

Ensure the path starts with `/llm-architecture-gallery/images/architectures/` (not a bare filename or full URL). The site prepends `https://sebastianraschka.com` automatically.

```yaml
# ✅ Correct
image: "/llm-architecture-gallery/images/architectures/my-model.webp"

# ❌ Wrong — bare filename
image: "my-model.webp"

# ❌ Wrong — full URL
image: "https://sebastianraschka.com/llm-architecture-gallery/images/architectures/my-model.webp"
```

### Date field format

Always quote dates to avoid YAML parsing them as `datetime` objects:

```yaml
# ✅ Correct — quoted string
date: '2025-01-20'

# ⚠️ Risky — may parse as datetime depending on YAML loader
date: 2025-01-20
```

---

## Quick Reference

| Task | Action |
|---|---|
| Add new model | Edit `models.yml`, add `.webp` to `images/architectures/` |
| View live gallery | https://sebastianraschka.com/llm-architecture-gallery/ |
| Full image URL | `https://sebastianraschka.com` + `image` field value |
| Validate YAML | `python3 -c "import yaml; yaml.safe_load(open('models.yml'))"` |
| Primary data file | `models.yml` |
| License | Apache-2.0 |
