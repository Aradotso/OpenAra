```markdown
---
name: md-this-page-extension
description: Browser extension that converts any webpage to clean, LLM-ready Markdown using Mozilla Readability and Turndown
triggers:
  - convert webpage to markdown
  - md this page extension
  - html to markdown browser extension
  - extract page content as markdown
  - build chrome extension with plasmo
  - webpage markdown converter
  - readability turndown extension
  - llm ready markdown from webpage
---

# MD This Page Extension

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

A Chrome/Firefox browser extension built with Plasmo + React that converts any webpage into clean, structured Markdown in one click. Uses Mozilla's Readability for content extraction and Turndown for HTML-to-Markdown conversion — optimized for LLM workflows.

---

## What It Does

- Strips navigation, ads, scripts, and boilerplate from any webpage
- Extracts the main content using `@mozilla/readability`
- Converts extracted HTML to Markdown using `turndown`
- Opens a preview tab with copy/download/prompt-copy options
- Supports toggling images, links, metadata, source URL, and page structure output

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| [Plasmo](https://docs.plasmo.com/) | Browser extension framework |
| React | UI |
| Tailwind CSS | Styling |
| `@mozilla/readability` | Content extraction |
| `turndown` | HTML → Markdown |

---

## Installation & Development Setup

### Prerequisites
- Node.js 18+
- pnpm

### Clone & Install

```bash
git clone https://github.com/Ademking/MD-This-Page.git
cd MD-This-Page
pnpm install
```

### Development (Chrome)

```bash
pnpm dev
# Generates: build/chrome-mv3-dev/
```

Load in Chrome:
1. Navigate to `chrome://extensions/`
2. Enable **Developer mode**
3. Click **Load unpacked**
4. Select `build/chrome-mv3-dev`

### Development (Firefox)

```bash
pnpm dev --target=firefox-mv2
# Generates: build/firefox-mv2-dev/
```

### Production Build

```bash
pnpm build
# Output: build/chrome-mv3-prod/

pnpm build --target=firefox-mv2
# Output: build/firefox-mv2-prod/
```

---

## Project Structure

```
md-this-page/
├── background/
│   └── index.ts          # Service worker: context menu, keyboard shortcut
├── contents/
│   └── extractor.ts      # Content script: Readability extraction
├── tabs/
│   └── preview.tsx       # Preview tab UI (React)
├── components/           # Shared React components
├── utils/
│   └── turndown.ts       # Turndown configuration/helpers
├── assets/               # Icons, SVGs
├── package.json
└── plasmo.config.ts      # Plasmo configuration
```

---

## Key Code Patterns

### 1. Content Script: Extracting Page Content with Readability

```typescript
// contents/extractor.ts
import { Readability } from "@mozilla/readability";

export function extractPageContent(): {
  title: string;
  content: string;
  author: string | null;
  publishedTime: string | null;
  url: string;
} {
  // Clone document so Readability doesn't mutate the live DOM
  const documentClone = document.cloneNode(true) as Document;
  const reader = new Readability(documentClone);
  const article = reader.parse();

  return {
    title: article?.title ?? document.title,
    content: article?.content ?? document.body.innerHTML,
    author: article?.byline ?? null,
    publishedTime: article?.publishedTime ?? null,
    url: window.location.href,
  };
}
```

### 2. Converting HTML to Markdown with Turndown

```typescript
// utils/turndown.ts
import TurndownService from "turndown";

export interface ConversionOptions {
  keepImages: boolean;
  keepLinks: boolean;
  includeMetadata: boolean;
  includeSourceUrl: boolean;
  generatePageMap: boolean;
}

export function htmlToMarkdown(
  html: string,
  options: ConversionOptions
): string {
  const turndownService = new TurndownService({
    headingStyle: "atx",      // # H1, ## H2 style
    codeBlockStyle: "fenced", // ```code``` style
    bulletListMarker: "-",
  });

  // Optionally strip images
  if (!options.keepImages) {
    turndownService.addRule("removeImages", {
      filter: "img",
      replacement: () => "",
    });
  }

  // Optionally strip links (keep text only)
  if (!options.keepLinks) {
    turndownService.addRule("removeLinks", {
      filter: "a",
      replacement: (content) => content,
    });
  }

  return turndownService.turndown(html);
}

export function buildFullMarkdown(
  extracted: { title: string; content: string; author: string | null; publishedTime: string | null; url: string },
  options: ConversionOptions
): string {
  const lines: string[] = [];

  if (options.includeMetadata) {
    lines.push(`# ${extracted.title}`);
    if (extracted.author) lines.push(`**Author:** ${extracted.author}`);
    if (extracted.publishedTime) lines.push(`**Published:** ${extracted.publishedTime}`);
    lines.push("");
  }

  if (options.includeSourceUrl) {
    lines.push(`**Source:** ${extracted.url}`);
    lines.push("");
  }

  const markdown = htmlToMarkdown(extracted.content, options);
  lines.push(markdown);

  return lines.join("\n");
}
```

### 3. Background Service Worker: Context Menu & Shortcut

```typescript
// background/index.ts
import { sendToContentScript } from "@plasmohq/messaging";

// Register context menu item
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "md-this-page",
    title: ".MD this page",
    contexts: ["page", "selection"],
  });
});

// Handle context menu click
chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "md-this-page" && tab?.id) {
    triggerExtraction(tab.id);
  }
});

// Handle keyboard shortcut (Alt+M defined in manifest)
chrome.commands.onCommand.addListener((command) => {
  if (command === "trigger-md") {
    chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
      if (tabs[0]?.id) triggerExtraction(tabs[0].id);
    });
  }
});

async function triggerExtraction(tabId: number) {
  // Execute content script to extract content
  const results = await chrome.scripting.executeScript({
    target: { tabId },
    func: () => {
      // This runs in page context — calls extractPageContent()
      return window.__mdThisPage?.extract();
    },
  });

  const data = results?.[0]?.result;
  if (!data) return;

  // Open preview tab with extracted data
  chrome.storage.session.set({ extractedContent: data }, () => {
    chrome.tabs.create({
      url: chrome.runtime.getURL("tabs/preview.html"),
    });
  });
}
```

### 4. Preview Tab: React UI

```tsx
// tabs/preview.tsx
import { useEffect, useState } from "react";
import { buildFullMarkdown, ConversionOptions } from "../utils/turndown";

const DEFAULT_OPTIONS: ConversionOptions = {
  keepImages: true,
  keepLinks: true,
  includeMetadata: true,
  includeSourceUrl: true,
  generatePageMap: false,
};

export default function PreviewTab() {
  const [markdown, setMarkdown] = useState("");
  const [options, setOptions] = useState<ConversionOptions>(DEFAULT_OPTIONS);
  const [extracted, setExtracted] = useState(null);

  useEffect(() => {
    chrome.storage.session.get("extractedContent", ({ extractedContent }) => {
      if (extractedContent) {
        setExtracted(extractedContent);
        setMarkdown(buildFullMarkdown(extractedContent, options));
      }
    });
  }, []);

  useEffect(() => {
    if (extracted) {
      setMarkdown(buildFullMarkdown(extracted, options));
    }
  }, [options, extracted]);

  const handleCopy = () => {
    navigator.clipboard.writeText(markdown);
  };

  const handleDownload = () => {
    const blob = new Blob([markdown], { type: "text/markdown" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${extracted?.title ?? "page"}.md`;
    a.click();
    URL.revokeObjectURL(url);
  };

  const handleCopyAsPrompt = () => {
    const prompt = `Please analyze the following content:\n\n${markdown}`;
    navigator.clipboard.writeText(prompt);
  };

  return (
    <div className="flex flex-col h-screen p-4 bg-gray-900 text-white">
      {/* Options toggles */}
      <div className="flex gap-4 mb-4 flex-wrap">
        {(Object.keys(DEFAULT_OPTIONS) as Array<keyof ConversionOptions>).map((key) => (
          <label key={key} className="flex items-center gap-2 text-sm cursor-pointer">
            <input
              type="checkbox"
              checked={options[key]}
              onChange={(e) =>
                setOptions((prev) => ({ ...prev, [key]: e.target.checked }))
              }
            />
            {key}
          </label>
        ))}
      </div>

      {/* Action buttons */}
      <div className="flex gap-2 mb-4">
        <button onClick={handleCopy} className="btn">Copy</button>
        <button onClick={handleDownload} className="btn">Download .md</button>
        <button onClick={handleCopyAsPrompt} className="btn">Copy as Prompt</button>
      </div>

      {/* Markdown preview */}
      <textarea
        className="flex-1 bg-gray-800 p-4 rounded font-mono text-sm resize-none"
        value={markdown}
        onChange={(e) => setMarkdown(e.target.value)}
      />
    </div>
  );
}
```

### 5. Plasmo Manifest Configuration

```json
// In package.json (Plasmo reads this)
{
  "manifest": {
    "permissions": ["activeTab", "scripting", "contextMenus", "storage"],
    "commands": {
      "trigger-md": {
        "suggested_key": {
          "default": "Alt+M"
        },
        "description": "Convert page to Markdown"
      }
    }
  }
}
```

---

## Plasmo Framework Essentials

### Messaging Between Extension Parts

```typescript
// Using @plasmohq/messaging for background <-> content communication
import { sendToContentScript } from "@plasmohq/messaging";

// From background to content script
await sendToContentScript({
  name: "extract",
  tabId: tab.id,
});

// In content script — register handler
import { onMessage } from "@plasmohq/messaging/message";

onMessage("extract", async (req) => {
  const data = extractPageContent();
  return data;
});
```

### Storage (Plasmo wrapper)

```typescript
import { Storage } from "@plasmohq/storage";

const storage = new Storage();

// Set
await storage.set("options", { keepImages: true });

// Get
const options = await storage.get("options");

// Watch for changes
storage.watch({
  options: (change) => {
    console.log("Options changed:", change.newValue);
  },
});
```

---

## Adding a New Turndown Rule

```typescript
// Example: Convert <mark> tags to ==highlighted== (for Obsidian)
turndownService.addRule("highlight", {
  filter: "mark",
  replacement: (content) => `==${content}==`,
});

// Example: Preserve <kbd> tags
turndownService.addRule("keyboard", {
  filter: "kbd",
  replacement: (content) => `\`${content}\``,
});

// Example: Remove all tables
turndownService.addRule("removeTables", {
  filter: ["table", "thead", "tbody", "tr", "td", "th"],
  replacement: () => "",
});
```

---

## Common Patterns & Troubleshooting

### Readability Returns Null
Some pages (SPAs, dashboards) don't have article-style content. Fallback to full body:

```typescript
const reader = new Readability(documentClone);
const article = reader.parse();

// Fallback
const content = article?.content ?? document.body.innerHTML;
```

### Content Script Not Running on Certain Pages
Chrome blocks extensions on `chrome://`, `chrome-extension://`, and some protected pages. Check:

```typescript
chrome.tabs.query({ active: true, currentWindow: true }, ([tab]) => {
  if (!tab?.url || tab.url.startsWith("chrome://")) {
    console.warn("Cannot run on this page");
    return;
  }
  triggerExtraction(tab.id);
});
```

### Session Storage Not Persisting Between Tabs
Use `chrome.storage.session` (Manifest V3) — it persists within a browser session but not across restarts:

```typescript
// Set before opening preview tab
chrome.storage.session.set({ extractedContent: data });

// Read in preview tab
chrome.storage.session.get("extractedContent", ({ extractedContent }) => { ... });
```

### Build Errors with Plasmo

```bash
# Clear build cache
rm -rf build/ .plasmo/
pnpm install
pnpm dev
```

### Large Pages Hitting Storage Limits
`chrome.storage.session` has a 10MB limit. For large pages, truncate or compress:

```typescript
const MAX_SIZE = 8 * 1024 * 1024; // 8MB
const content = extracted.content.slice(0, MAX_SIZE);
```

---

## Available Scripts

```bash
pnpm dev                          # Chrome MV3 dev build (hot reload)
pnpm dev --target=firefox-mv2     # Firefox MV2 dev build
pnpm build                        # Chrome MV3 production build
pnpm build --target=firefox-mv2   # Firefox MV2 production build
pnpm package                      # Zip extension for store submission
```

---

## Keyboard Shortcut

Default: `Alt+M` on any page triggers conversion. Users can customize in:
- Chrome: `chrome://extensions/shortcuts`
- Firefox: `about:addons` → gear icon → Manage Extension Shortcuts

---

## Store Links

- [Chrome Web Store](https://chromewebstore.google.com/detail/md-this-page/banfcmclfmmlbkhionmemhibbjedhikm)
- [Firefox Add-ons](https://addons.mozilla.org/en-US/firefox/addon/md-this-page/)
```
