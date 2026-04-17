```markdown
---
name: logo-generator-skill
description: Professional SVG logo generator with AI-powered showcase images using Claude Code skills workflow
triggers:
  - generate a logo for my project
  - create a logo with SVG variants
  - logo generator skill
  - make a professional logo
  - design a logo for my app
  - generate logo showcase images
  - create brand identity logo
  - SVG logo with background styles
---

# Logo Generator Skill

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

Professional SVG logo generator that creates 6+ design variants and stunning showcase presentations. Uses geometric design principles and Gemini image generation to produce production-ready logos with 12 professional background styles.

## What This Skill Does

- Generates 6+ distinct SVG logo variants per request (dot matrix, line systems, mixed compositions)
- Creates interactive HTML showcase pages with hover effects
- Exports SVG to PNG at multiple resolutions
- Generates high-end showcase images via Gemini 3.1 Flash Image Preview
- Supports 12 curated background styles (6 dark, 6 light)

## Installation

### Method 1: Automatic (Recommended)

```bash
npx skills add https://github.com/op7418/logo-generator-skill.git
```

### Method 2: Git Clone

```bash
git clone https://github.com/op7418/logo-generator-skill.git ~/.claude/skills/logo-generator
```

### Method 3: Manual

```bash
# macOS/Linux
cp -r logo-generator ~/.claude/skills/logo-generator

# Windows
xcopy logo-generator %USERPROFILE%\.claude\skills\logo-generator /E /I
```

### Post-Installation Setup

```bash
cd ~/.claude/skills/logo-generator
pip install -r requirements.txt

# Configure API key
cp .env.example .env
# Edit .env and set GEMINI_API_KEY
```

## Configuration

### `.env` file

```env
# Official Google Gemini API
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-3.1-flash-image-preview

# Optional: Third-party endpoint
GEMINI_API_BASE_URL=https://api.example.com/v1
```

Get a Gemini API key at: https://aistudio.google.com/apikey

## Key Scripts

### SVG to PNG Conversion

```bash
python scripts/svg_to_png.py --input logo.svg --output logo.png --size 1024
```

```python
# scripts/svg_to_png.py usage in code
import cairosvg

def convert_svg_to_png(svg_path: str, output_path: str, size: int = 1024):
    cairosvg.svg2png(
        url=svg_path,
        write_to=output_path,
        output_width=size,
        output_height=size
    )
```

### Generate Showcase Images

```bash
python scripts/generate_showcase.py \
  --logo logo.png \
  --styles "void,frosted,fluid,spotlight" \
  --output ./showcases/
```

```python
# scripts/generate_showcase.py usage in code
import os
from google import genai
from dotenv import load_dotenv

load_dotenv()

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

def generate_showcase(logo_path: str, style: str, output_path: str):
    """Generate a professional showcase image for a logo."""
    
    with open(logo_path, "rb") as f:
        logo_data = f.read()
    
    style_prompts = {
        "void": "absolute black background with silver micro noise, hardcore tech aesthetic",
        "frosted": "titanium gray with organic texture, premium product feel",
        "fluid": "deep purple with fluid fusion effects, AI-native aesthetic",
        "spotlight": "carbon gray with editorial spotlight lighting, magazine quality",
        "editorial": "off-white paper texture, humanistic brand feel",
        "swiss": "pure solid color, zero effects, timeless Swiss design authority"
    }
    
    prompt = f"""
    Create a professional logo showcase image.
    Place this logo centered on a {style_prompts.get(style, style)} background.
    The logo should be the focal point with generous negative space around it.
    Make it look like a high-end design studio presentation.
    Output as a 1600x900 landscape showcase image.
    """
    
    response = client.models.generate_content(
        model=os.getenv("GEMINI_MODEL", "gemini-3.1-flash-image-preview"),
        contents=[
            {"role": "user", "parts": [
                {"inline_data": {"mime_type": "image/png", "data": logo_data}},
                {"text": prompt}
            ]}
        ]
    )
    
    # Save generated image
    for part in response.candidates[0].content.parts:
        if hasattr(part, "inline_data"):
            with open(output_path, "wb") as f:
                import base64
                f.write(base64.b64decode(part.inline_data.data))
            return output_path
    
    raise ValueError("No image generated in response")
```

## SVG Logo Design Patterns

### Dot Matrix Pattern

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs>
    <pattern id="dots" x="0" y="0" width="20" height="20" patternUnits="userSpaceOnUse">
      <circle cx="10" cy="10" r="1.5" fill="#ffffff" opacity="0.8"/>
    </pattern>
  </defs>
  <!-- Background -->
  <rect width="200" height="200" fill="#0a0a0a"/>
  <!-- Dot matrix field -->
  <rect width="200" height="200" fill="url(#dots)"/>
  <!-- Focal element -->
  <circle cx="100" cy="100" r="30" fill="none" stroke="#ffffff" stroke-width="2.5"/>
  <circle cx="100" cy="100" r="4" fill="#ffffff"/>
</svg>
```

### Line System Pattern

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect width="200" height="200" fill="#0a0a0a"/>
  <!-- Horizontal lines with tension -->
  <line x1="40" y1="85" x2="160" y2="85" stroke="#ffffff" stroke-width="2.5" opacity="0.9"/>
  <line x1="40" y1="100" x2="160" y2="100" stroke="#ffffff" stroke-width="2.5" opacity="0.9"/>
  <line x1="40" y1="115" x2="160" y2="115" stroke="#ffffff" stroke-width="2.5" opacity="0.9"/>
  <!-- Vertical interrupt creating focal point -->
  <rect x="90" y="75" width="20" height="50" fill="#0a0a0a"/>
  <line x1="100" y1="70" x2="100" y2="130" stroke="#ffffff" stroke-width="3.5"/>
</svg>
```

### Mixed Composition Pattern

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <rect width="200" height="200" fill="#0a0a0a"/>
  <!-- Geometric anchor -->
  <rect x="70" y="70" width="60" height="60" fill="none" 
        stroke="#ffffff" stroke-width="2.5" transform="rotate(45 100 100)"/>
  <!-- Dot accent (asymmetric tension) -->
  <circle cx="130" cy="75" r="5" fill="#ffffff"/>
  <!-- Minimal line extension -->
  <line x1="100" y1="45" x2="100" y2="65" stroke="#ffffff" stroke-width="2.5" opacity="0.6"/>
</svg>
```

## Complete Workflow Example

### 1. Information Gathering Prompt

When a user asks for a logo, gather:

```
Product Name: [name]
Industry/Category: [AI / Fintech / Design Tools / SaaS / etc.]
Core Concept: [connection / flow / security / intelligence / etc.]
Design Preference: [minimal/complex] [cold/warm] [geometric/organic]
```

### 2. Generate 6 SVG Variants

Create an HTML showcase file:

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    body { background: #0a0a0a; display: flex; flex-wrap: wrap; 
           gap: 20px; padding: 40px; font-family: monospace; }
    .variant { 
      width: 200px; text-align: center; 
      transition: transform 0.3s ease;
    }
    .variant:hover { transform: scale(1.05); }
    .variant svg { border: 1px solid #333; border-radius: 8px; }
    .label { color: #666; font-size: 11px; margin-top: 8px; }
  </style>
</head>
<body>
  <div class="variant">
    <!-- SVG Variant 1: Dot Matrix -->
    <svg width="200" height="200" xmlns="http://www.w3.org/2000/svg">
      <!-- Insert dot matrix SVG content -->
    </svg>
    <div class="label">01 — Dot Matrix</div>
  </div>
  <!-- Repeat for variants 2-6 -->
</body>
</html>
```

### 3. Export Selected Logo as PNG

```python
#!/usr/bin/env python3
"""Export SVG logo to multiple PNG sizes."""

import cairosvg
import os

def export_logo(svg_path: str, output_dir: str):
    """Export logo at standard sizes."""
    
    sizes = {
        "icon_32": 32,
        "icon_64": 64, 
        "icon_128": 128,
        "logo_512": 512,
        "logo_1024": 1024,
        "logo_2048": 2048,
    }
    
    os.makedirs(output_dir, exist_ok=True)
    
    for name, size in sizes.items():
        output_path = os.path.join(output_dir, f"{name}.png")
        cairosvg.svg2png(
            url=svg_path,
            write_to=output_path,
            output_width=size,
            output_height=size
        )
        print(f"✓ Exported {name}.png ({size}x{size})")

if __name__ == "__main__":
    import sys
    export_logo(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else "./exports")
```

### 4. Generate Showcase Images

```python
#!/usr/bin/env python3
"""Generate all showcase images for a logo."""

import os
import json
from pathlib import Path
from generate_showcase import generate_showcase

STYLE_SELECTIONS = {
    "ai": ["void", "fluid", "morning", "swiss"],
    "fintech": ["void", "frosted", "clinical", "swiss"],
    "design": ["editorial", "iridescent", "spotlight", "swiss"],
    "saas": ["frosted", "ui_container", "morning", "swiss"],
    "default": ["void", "frosted", "editorial", "swiss"]
}

def generate_all_showcases(logo_png: str, product_type: str, output_dir: str):
    styles = STYLE_SELECTIONS.get(product_type, STYLE_SELECTIONS["default"])
    
    Path(output_dir).mkdir(parents=True, exist_ok=True)
    results = []
    
    for style in styles:
        output_path = os.path.join(output_dir, f"showcase_{style}.png")
        try:
            generate_showcase(logo_png, style, output_path)
            results.append({"style": style, "path": output_path, "status": "success"})
            print(f"✓ Generated {style} showcase")
        except Exception as e:
            results.append({"style": style, "error": str(e), "status": "failed"})
            print(f"✗ Failed {style}: {e}")
    
    # Save manifest
    manifest_path = os.path.join(output_dir, "manifest.json")
    with open(manifest_path, "w") as f:
        json.dump(results, f, indent=2)
    
    return results

if __name__ == "__main__":
    import sys
    generate_all_showcases(
        logo_png=sys.argv[1],
        product_type=sys.argv[2] if len(sys.argv) > 2 else "default",
        output_dir=sys.argv[3] if len(sys.argv) > 3 else "./showcases"
    )
```

## Design Principles to Follow

When generating SVG logos, always apply:

1. **Extreme Simplicity** — Maximum 1-2 core visual elements
2. **Generous Negative Space** — At least 40-50% empty canvas
3. **Precise Line Weights** — Use 2.5px–4px strokes only
4. **Single Focal Point** — One clear visual anchor
5. **Visual Tension** — Intentional asymmetry (not centered-everything)
6. **Restraint** — Every element must justify its presence

```svg
<!-- ✅ Good: Simple, focused, negative space -->
<svg viewBox="0 0 200 200">
  <rect width="200" height="200" fill="#0a0a0a"/>
  <circle cx="100" cy="100" r="35" fill="none" stroke="#fff" stroke-width="3"/>
  <circle cx="118" cy="85" r="6" fill="#fff"/>
</svg>

<!-- ❌ Bad: Too many elements, no focal point -->
<svg viewBox="0 0 200 200">
  <rect width="200" height="200" fill="#0a0a0a"/>
  <circle cx="50" cy="50" r="20" fill="#fff"/>
  <circle cx="150" cy="50" r="20" fill="#fff"/>
  <rect x="40" y="100" width="120" height="40" fill="#fff"/>
  <line x1="20" y1="160" x2="180" y2="160" stroke="#fff"/>
  <text x="100" y="190" fill="#fff">BRAND</text>
</svg>
```

## Background Style Reference

| Style | Key | Aesthetic | Best For |
|-------|-----|-----------|----------|
| The Void | `void` | Pure black + silver noise | Hardcore tech |
| Frosted Horizon | `frosted` | Titanium gray + texture | Premium products |
| Fluid Abyss | `fluid` | Deep purple + fluid FX | AI-native |
| Studio Spotlight | `spotlight` | Carbon + editorial light | Magazine quality |
| Analog Liquid | `analog` | Metallic shimmer | Creative brands |
| LED Matrix | `led` | Digital retro glow | Cyberpunk |
| Editorial Paper | `editorial` | Off-white paper | Humanistic |
| Iridescent Frost | `iridescent` | Silver + holographic | Tech hardware |
| Morning Aura | `morning` | Warm ivory + pastels | Approachable AI |
| Clinical Studio | `clinical` | Pure white + shadows | Algorithm-driven |
| UI Container | `ui_container` | Frosted glass frame | SaaS platforms |
| Swiss Flat | `swiss` | Solid color, zero FX | Timeless authority |

## Triggering the Skill in Claude Code

```
/logo-generator
```

Or naturally:
```
Generate a logo for my fintech startup called "Meridian" — focused on clarity and trust
```

```
Create 6 logo variants for "NeuralPath" — an AI research tool, geometric and minimal
```

```
Take the logo I selected and generate showcase images in void, frosted, morning, and swiss styles
```

## Troubleshooting

### `cairosvg` installation fails

```bash
# macOS
brew install cairo pango gdk-pixbuf libffi
pip install cairosvg

# Ubuntu/Debian
sudo apt-get install libcairo2-dev libpango1.0-dev libgdk-pixbuf2.0-dev
pip install cairosvg

# Windows (use conda)
conda install -c conda-forge cairosvg
```

### Gemini API errors

```bash
# Test API key
python -c "
import os
from dotenv import load_dotenv
from google import genai
load_dotenv()
client = genai.Client(api_key=os.getenv('GEMINI_API_KEY'))
print('API key valid:', bool(client))
"
```

### Skill not recognized in Claude Code

```bash
# Verify installation
ls ~/.claude/skills/logo-generator/
# Should show: SKILL.md README.md scripts/ requirements.txt .env

# Check SKILL.md exists
cat ~/.claude/skills/logo-generator/SKILL.md | head -5
```

### SVG renders as blank PNG

- Ensure SVG has explicit `width`/`height` or `viewBox` attribute
- Check that `xmlns="http://www.w3.org/2000/svg"` is present
- Avoid external font references in SVG

```svg
<!-- Always include these attributes -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" width="200" height="200">
```

## File Structure

```
~/.claude/skills/logo-generator/
├── SKILL.md                     # Skill activation definition
├── README.md                    # Full documentation
├── requirements.txt             # google-genai, cairosvg, Pillow, python-dotenv
├── .env.example                 # GEMINI_API_KEY template
├── .env                         # Your actual API key (gitignored)
├── scripts/
│   ├── svg_to_png.py           # SVG → PNG converter
│   └── generate_showcase.py    # Gemini showcase generator
├── references/
│   ├── design_patterns.md      # Design pattern library
│   ├── background_styles.md    # Background specifications
│   └── webgl_backgrounds.md    # WebGL dynamic backgrounds
└── assets/
    ├── showcase_template.html  # HTML presentation template
    └── background_library.html # Interactive WebGL backgrounds
```
```
