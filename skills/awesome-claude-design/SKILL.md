```markdown
---
name: awesome-claude-design
description: Use 68 ready-to-use DESIGN.md files to scaffold full UI design systems with Claude Design in one shot
triggers:
  - set up a design system with Claude Design
  - use a DESIGN.md file for my project
  - scaffold a UI from a design system
  - pick a design inspiration for Claude Design
  - create a design system from DESIGN.md
  - drop a DESIGN.md into Claude Design
  - generate a UI kit with Claude Design
  - find a design system template for my app
---

# Awesome Claude Design

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

A curated collection of 68 ready-to-use `DESIGN.md` files covering AI platforms, developer tools, fintech, e-commerce, and more. Drop one into [Claude Design](https://claude.ai/design) and get a full design system scaffold — color tokens, type scale, components, preview cards, and a working UI kit — in a single shot.

---

## What This Project Does

`awesome-claude-design` gives you a library of pre-written `DESIGN.md` files, each describing a well-known brand's visual language (colors, typography, spacing, voice, component patterns) in a structured markdown format that Claude Design can act on directly.

**Input:** One `DESIGN.md` file  
**Output (from Claude Design):**
- `README.md` — brand context, voice, visual foundations
- `colors_and_type.css` — CSS custom properties, type scale, utility classes
- `preview/` — cards for colors, type, spacing, components, and brand
- `index.html` — working UI kit / marketing page applying the system
- `SKILL.md` — portable skill file for future projects

---

## Understanding DESIGN.md

A `DESIGN.md` file is a single plain-text markdown document that encodes a brand's visual language so AI agents can make consistent decisions — not just *what* to use, but *why*.

### Minimal DESIGN.md structure

```markdown
# Brand Name Design System

## Overview
Brief brand description and personality.

## Color Palette
- **Primary:** #10B981 — Emerald; used for CTAs, active states, highlights
- **Background:** #0A0A0A — Void black; base canvas
- **Surface:** #111111 — Slightly lifted surface for cards
- **Text Primary:** #F5F5F5 — Near-white body copy
- **Text Muted:** #6B7280 — Secondary labels and captions
- **Accent:** #34D399 — Hover states, borders, focus rings

## Typography
- **Display:** Inter, 700–900 weight, tight tracking (-0.02em)
- **Body:** Inter, 400–500 weight, 1.6 line-height
- **Mono:** JetBrains Mono, used for code, terminals, data labels
- **Scale:** 12 / 14 / 16 / 20 / 24 / 32 / 48 / 64px

## Spacing
Base unit: 4px. Scale: 4, 8, 12, 16, 24, 32, 48, 64, 96, 128px

## Border Radius
- Small: 4px (inputs, badges)
- Medium: 8px (cards, buttons)
- Large: 16px (modals, panels)
- Full: 9999px (pills, avatars)

## Shadows
- Subtle: 0 1px 3px rgba(0,0,0,0.4)
- Card: 0 4px 16px rgba(0,0,0,0.6)
- Glow: 0 0 24px rgba(16,185,129,0.3)

## Voice & Tone
Direct, technical, never corporate. Short sentences. Active verbs.

## Component Patterns
- **Buttons:** Filled primary (emerald bg), ghost (border only), destructive (red)
- **Cards:** Dark surface, 1px border, subtle hover lift with glow shadow
- **Navigation:** Top bar, logo left, links center, CTA right
- **Code blocks:** Monospace font, syntax-highlighted, copy button top-right

## Do / Don't
- ✅ Dark backgrounds with high contrast text
- ✅ Emerald for interactive elements only
- ❌ Light mode variants
- ❌ Rounded corners above 16px on cards
```

---

## Finding & Downloading a DESIGN.md

All 68 design systems are hosted at [getdesign.md](https://getdesign.md/). Each has a preview page where you can inspect the full system before downloading.

### URL pattern
```
https://getdesign.md/{brand-slug}/design-md
```

### Examples
```
https://getdesign.md/vercel/design-md       # Black/white precision, Geist font
https://getdesign.md/stripe/design-md       # Purple gradients, weight-300 elegance
https://getdesign.md/linear.app/design-md   # Ultra-minimal, purple accent
https://getdesign.md/supabase/design-md     # Dark emerald, code-first
https://getdesign.md/voltagent/design-md    # Void-black, emerald, terminal-native
https://getdesign.md/figma/design-md        # Vibrant multi-color, playful
https://getdesign.md/notion/design-md       # Warm minimalism, serif headings
https://getdesign.md/spotify/design-md      # Dark canvas, neon green
```

---

## Using a DESIGN.md with Claude Design

### Option A — Start from a design system (recommended)

1. Go to [claude.ai/design/#org](https://claude.ai/design/#org)
2. Click **Create new design system**
3. On the *Set up your design system* screen, upload your `DESIGN.md` under **Add assets**
4. Claude scaffolds the full system automatically

### Option B — Start from a prototype

1. Go to [claude.ai/design](https://claude.ai/design) and create a new prototype
2. Attach your `DESIGN.md` in the chat input
3. Send the prompt:

```
Create a design system from this DESIGN.md
```

### Follow-up prompts after scaffolding

```
Generate a SaaS dashboard page using this design system
Build a pricing page with 3 tiers using the established tokens
Create a login/signup flow consistent with this system
Add a data table component following the component patterns
Build a mobile navigation drawer using existing tokens
```

---

## Choosing the Right Design System

### By aesthetic

| You want… | Use this DESIGN.md |
|-----------|-------------------|
| Minimal dark + precise | `vercel`, `linear.app`, `ollama` |
| Warm, editorial, light | `notion`, `apple`, `airbnb` |
| Cinematic dark + neon | `shopify`, `elevenlabs`, `runwayml` |
| Bold + high-contrast | `nike`, `spacex`, `xai` |
| Colorful + playful | `figma`, `lovable`, `airtable` |
| Enterprise + trustworthy | `ibm`, `hashicorp`, `coinbase` |
| Purple gradient premium | `stripe`, `superhuman`, `kraken` |
| Developer terminal-native | `voltagent`, `warp`, `cursor` |
| Green brand | `supabase`, `mongodb`, `wise` |

### By use-case

| Building… | Inspiration |
|-----------|-------------|
| SaaS dashboard | `linear.app`, `posthog`, `sentry` |
| Developer docs | `mintlify`, `supabase`, `vercel` |
| Marketing site | `stripe`, `framer`, `webflow` |
| E-commerce | `shopify`, `airbnb`, `nike` |
| Fintech app | `stripe`, `revolut`, `wise` |
| AI product | `claude`, `cohere`, `mistral.ai` |
| Productivity tool | `notion`, `linear.app`, `cal` |

---

## Creating a Custom DESIGN.md

If none of the 68 presets match your brand, create your own:

```markdown
# MyApp Design System

## Overview
[2–3 sentences: what the product is, who uses it, personality]

## Color Palette
- **Primary:** #HEX — Name; usage note
- **Background:** #HEX — Name; usage note
- **Surface:** #HEX — Name; usage note
- **Text Primary:** #HEX
- **Text Muted:** #HEX
- **Accent:** #HEX
- **Destructive:** #HEX
- **Success:** #HEX

## Typography
- **Display font:** [Font name], [weights], [tracking]
- **Body font:** [Font name], [weights], [line-height]
- **Mono font:** [Font name]
- **Scale:** [list of px sizes]

## Spacing
[Base unit and scale]

## Border Radius
[Named sizes with px values and when to use each]

## Shadows
[Named shadow levels]

## Voice & Tone
[3–5 bullet adjectives + one "we sound like X, not Y"]

## Component Patterns
- **Buttons:** [variants and usage]
- **Cards:** [structure and feel]
- **Navigation:** [layout pattern]
- **Forms:** [input style]

## Do / Don't
- ✅ [rule]
- ❌ [rule]
```

---

## Generated Output Structure

After Claude Design processes your `DESIGN.md`, expect this file structure:

```
design-system/
├── README.md                  # Brand overview, usage guide
├── colors_and_type.css        # All CSS custom properties
├── index.html                 # Working UI kit / marketing page
├── SKILL.md                   # Portable skill for future use
└── preview/
    ├── colors.html            # Color swatch cards
    ├── typography.html        # Type scale showcase
    ├── spacing.html           # Spacing scale visual
    ├── components.html        # Button, card, input previews
    └── brand.html             # Full brand overview card
```

### Example generated CSS variables

```css
/* colors_and_type.css — generated from DESIGN.md */
:root {
  /* Colors */
  --color-primary: #10B981;
  --color-background: #0A0A0A;
  --color-surface: #111111;
  --color-surface-raised: #1A1A1A;
  --color-text-primary: #F5F5F5;
  --color-text-muted: #6B7280;
  --color-accent: #34D399;
  --color-destructive: #EF4444;
  --color-success: #10B981;
  --color-border: rgba(255,255,255,0.08);

  /* Typography */
  --font-display: 'Inter', sans-serif;
  --font-body: 'Inter', sans-serif;
  --font-mono: 'JetBrains Mono', monospace;

  /* Type scale */
  --text-xs: 0.75rem;    /* 12px */
  --text-sm: 0.875rem;   /* 14px */
  --text-base: 1rem;     /* 16px */
  --text-lg: 1.25rem;    /* 20px */
  --text-xl: 1.5rem;     /* 24px */
  --text-2xl: 2rem;      /* 32px */
  --text-3xl: 3rem;      /* 48px */
  --text-4xl: 4rem;      /* 64px */

  /* Spacing */
  --space-1: 4px;
  --space-2: 8px;
  --space-3: 12px;
  --space-4: 16px;
  --space-6: 24px;
  --space-8: 32px;
  --space-12: 48px;
  --space-16: 64px;
  --space-24: 96px;
  --space-32: 128px;

  /* Radius */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 16px;
  --radius-full: 9999px;

  /* Shadows */
  --shadow-subtle: 0 1px 3px rgba(0,0,0,0.4);
  --shadow-card: 0 4px 16px rgba(0,0,0,0.6);
  --shadow-glow: 0 0 24px rgba(16,185,129,0.3);
}
```

---

## Common Patterns & Prompts

### After uploading a DESIGN.md, use these prompts

```
# Generate specific pages
Build a landing page hero section using this design system
Create a user settings page following the established component patterns
Design a 404 error page consistent with the brand voice

# Extend the system
Add a notification/toast component to this design system
Create a data visualization color palette extension
Design dark and light mode variants of the card component

# Export for frameworks
Convert the CSS variables to Tailwind CSS config format
Generate a shadcn/ui theme config from this design system
Create a Figma-ready color token JSON from the palette

# Apply to real UI
Build a complete SaaS onboarding flow (3 steps) using this system
Create a pricing page with monthly/annual toggle
Design a dashboard sidebar navigation component
```

### Prompt to generate Tailwind config from Claude Design output

```
Take the CSS variables from colors_and_type.css and generate a complete
tailwind.config.js that maps all color tokens, font families, spacing,
border radius, and box shadows to Tailwind theme extensions.
```

### Prompt to apply system to an existing component

```
I have this React component [paste component]. Refactor it to use the
CSS custom properties from colors_and_type.css. Keep the same structure
but replace all hardcoded colors, fonts, and spacing with token references.
```

---

## Full Collection Reference

### AI & LLM Platforms (12)
`claude` · `cohere` · `elevenlabs` · `minimax` · `mistral.ai` · `ollama` · `opencode.ai` · `replicate` · `runwayml` · `together.ai` · `voltagent` · `x.ai`

### Developer Tools & IDEs (9)
`cursor` · `expo` · `lovable` · `raycast` · `superhuman` · `vercel` · `warp`

### Backend, Database & DevOps (8)
`clickhouse` · `composio` · `hashicorp` · `mongodb` · `posthog` · `sanity` · `sentry` · `supabase`

### Productivity & SaaS (7)
`cal` · `intercom` · `linear.app` · `mintlify` · `notion` · `resend` · `zapier`

### Design & Creative Tools (6)
`airtable` · `clay` · `figma` · `framer` · `miro` · `webflow`

### Fintech & Crypto (7)
`binance` · `coinbase` · `kraken` · `mastercard` · `revolut` · `stripe` · `wise`

### E-commerce & Retail (4)
`airbnb` · `meta` · `nike` · `shopify`

### Media & Consumer Tech (8+)
`apple` · `ibm` · `nvidia` · `pinterest` · `playstation` · `spacex` · `spotify` · …

---

## Troubleshooting

### Claude Design ignores parts of the DESIGN.md
- Keep the file under ~4000 tokens; split into `DESIGN.md` + `COMPONENTS.md` if needed
- Use consistent heading levels (`##` for sections, `###` for subsections)
- Be explicit: "Use `#10B981` for all interactive elements" rather than "use green"

### Generated colors look washed out
- Specify exact hex values — don't say "a warm orange", say `#F97316`
- Add contrast notes: "primary text must pass WCAG AA on background"

### Typography doesn't match expectations
- Name the exact Google Font or specify a substitute: "Use Inter (available on Google Fonts) as substitute for SF Pro"
- Include weights explicitly: `Inter 400, 500, 700, 900`

### Components feel generic
- Add a **Component Patterns** section with specific behavioral notes
- Include a **Do / Don't** table with concrete examples
- Reference a real product's interaction pattern: "Cards lift on hover like Linear's issue cards"

### DESIGN.md not accepted in upload
- Ensure the file is saved as plain `.md` (UTF-8, no BOM)
- File must be named `DESIGN.md` exactly (case-sensitive on some systems)
- Remove any HTML tags — Claude Design expects pure Markdown

---

## Related Resources

- [Claude Design](https://claude.ai/design) — Anthropic's design workspace
- [getdesign.md](https://getdesign.md/) — Full preview of all 68 design systems
- [VoltAgent](https://github.com/VoltAgent/voltagent) — AI agent framework by the same team
- [What is DESIGN.md?](https://getdesign.md/what-is-design-md) — Concept documentation
```
