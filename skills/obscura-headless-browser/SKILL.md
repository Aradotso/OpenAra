```markdown
---
name: obscura-headless-browser
description: Use Obscura, the lightweight Rust-based headless browser for AI agents and web scraping with CDP, Puppeteer, and Playwright support.
triggers:
  - headless browser for scraping
  - use obscura browser
  - puppeteer with obscura
  - playwright headless rust browser
  - web scraping with CDP
  - run headless chrome alternative
  - automate browser with obscura
  - stealth web scraping rust
---

# Obscura Headless Browser

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

Obscura is a headless browser engine written in Rust for web scraping and AI agent automation. It runs real JavaScript via V8, implements the Chrome DevTools Protocol (CDP), and acts as a drop-in replacement for headless Chrome — with 30 MB memory usage, instant startup, and built-in anti-detection.

## Installation

### Download Binary (Recommended)

```bash
# Linux x86_64
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-x86_64-linux.tar.gz
tar xzf obscura-x86_64-linux.tar.gz
sudo mv obscura /usr/local/bin/

# macOS Apple Silicon
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-aarch64-macos.tar.gz
tar xzf obscura-aarch64-macos.tar.gz
sudo mv obscura /usr/local/bin/

# macOS Intel
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-x86_64-macos.tar.gz
tar xzf obscura-x86_64-macos.tar.gz
sudo mv obscura /usr/local/bin/

# Windows: download .zip from releases page and extract manually
```

Single binary. No Chrome, no Node.js, no dependencies required.

### Build from Source

```bash
git clone https://github.com/h4ckf0r0day/obscura.git
cd obscura
cargo build --release

# With stealth mode (anti-detection + tracker blocking)
cargo build --release --features stealth
```

Requires Rust 1.75+. First build ~5 min (V8 compiles from source, cached after).

## CLI Quick Reference

### `obscura fetch` — Render a Single Page

```bash
# Get page title via JS eval
obscura fetch https://example.com --eval "document.title"

# Dump rendered HTML (after JS executes)
obscura fetch https://news.ycombinator.com --dump html

# Dump plain text content
obscura fetch https://example.com --dump text

# Dump all links
obscura fetch https://example.com --dump links

# Wait for network to be idle (SPAs, dynamic content)
obscura fetch https://example.com --wait-until networkidle0

# Wait for a specific CSS selector to appear
obscura fetch https://example.com --selector "#main-content"

# Enable stealth mode for anti-bot sites
obscura fetch https://example.com --stealth --eval "document.title"

# Suppress banner output
obscura fetch https://example.com --quiet --dump html
```

### `obscura serve` — Start CDP WebSocket Server

```bash
# Basic server on default port
obscura serve --port 9222

# With stealth mode enabled
obscura serve --port 9222 --stealth

# With proxy
obscura serve --port 9222 --proxy http://proxy.example.com:8080
obscura serve --port 9222 --proxy socks5://proxy.example.com:1080

# Multiple parallel workers
obscura serve --port 9222 --workers 4 --stealth

# Respect robots.txt
obscura serve --port 9222 --obey-robots
```

### `obscura scrape` — Parallel Scraping

```bash
# Scrape multiple URLs in parallel
obscura scrape https://site1.com https://site2.com https://site3.com \
  --concurrency 25 \
  --eval "document.querySelector('h1').textContent" \
  --format json

# Output as plain text
obscura scrape https://site1.com https://site2.com \
  --eval "document.title" \
  --format text
```

## Puppeteer Integration

```bash
npm install puppeteer-core
```

```javascript
import puppeteer from 'puppeteer-core';

// Start obscura first: obscura serve --port 9222
const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://127.0.0.1:9222/devtools/browser',
});

const page = await browser.newPage();
await page.goto('https://news.ycombinator.com');

// Extract structured data
const stories = await page.evaluate(() =>
  Array.from(document.querySelectorAll('.titleline > a'))
    .map(a => ({ title: a.textContent, url: a.href }))
);
console.log(stories);

await browser.disconnect();
```

### Puppeteer with Stealth Mode

```bash
# Start with stealth enabled
obscura serve --port 9222 --stealth
```

```javascript
import puppeteer from 'puppeteer-core';

const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://127.0.0.1:9222/devtools/browser',
});

const page = await browser.newPage();

// Set custom headers if needed
await page.setExtraHTTPHeaders({
  'Accept-Language': 'en-US,en;q=0.9',
});

await page.goto('https://bot-protected-site.com', {
  waitUntil: 'networkidle0',
});

const content = await page.content();
await browser.disconnect();
```

## Playwright Integration

```bash
npm install playwright-core
```

```javascript
import { chromium } from 'playwright-core';

// Start obscura first: obscura serve --port 9222
const browser = await chromium.connectOverCDP({
  endpointURL: 'ws://127.0.0.1:9222',
});

const context = await browser.newContext();
const page = await context.newPage();

await page.goto('https://en.wikipedia.org/wiki/Web_scraping');
console.log(await page.title());

// Wait for selector
await page.waitForSelector('#content');
const text = await page.locator('h1').textContent();
console.log(text);

await browser.close();
```

### Playwright Form Submission & Login

```javascript
import { chromium } from 'playwright-core';

const browser = await chromium.connectOverCDP({
  endpointURL: 'ws://127.0.0.1:9222',
});

const page = await browser.newContext().then(ctx => ctx.newPage());
await page.goto('https://quotes.toscrape.com/login');

// Fill and submit form
await page.fill('#username', process.env.SCRAPE_USERNAME);
await page.fill('#password', process.env.SCRAPE_PASSWORD);
await page.click('[type="submit"]');

// Obscura handles POST, follows 302 redirect, maintains cookies
await page.waitForNavigation();
console.log('Logged in:', page.url());

await browser.close();
```

## Common Automation Patterns

### Scrape Behind Login (Puppeteer)

```javascript
import puppeteer from 'puppeteer-core';

const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://127.0.0.1:9222/devtools/browser',
});
const page = await browser.newPage();

// Login
await page.goto('https://example.com/login');
await page.evaluate((user, pass) => {
  document.querySelector('#username').value = user;
  document.querySelector('#password').value = pass;
  document.querySelector('form').submit();
}, process.env.SITE_USERNAME, process.env.SITE_PASSWORD);

await page.waitForNavigation({ waitUntil: 'networkidle0' });

// Now scrape authenticated content
await page.goto('https://example.com/dashboard');
const data = await page.evaluate(() => ({
  title: document.title,
  content: document.querySelector('.data-table')?.innerHTML,
}));

await browser.disconnect();
```

### Request Interception (Fetch Domain)

```javascript
import puppeteer from 'puppeteer-core';

const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://127.0.0.1:9222/devtools/browser',
});
const page = await browser.newPage();

// Intercept and modify requests
await page.setRequestInterception(true);
page.on('request', (req) => {
  if (req.resourceType() === 'image') {
    req.abort(); // Block images for faster scraping
  } else {
    req.continue();
  }
});

await page.goto('https://example.com');
await browser.disconnect();
```

### Cookie Management

```javascript
import puppeteer from 'puppeteer-core';

const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://127.0.0.1:9222/devtools/browser',
});
const page = await browser.newPage();

// Set cookies before navigation
await page.setCookie({
  name: 'session_token',
  value: process.env.SESSION_TOKEN,
  domain: 'example.com',
});

await page.goto('https://example.com/protected');

// Get cookies after navigation
const cookies = await page.cookies();
console.log(cookies);

await browser.disconnect();
```

### Parallel Scraping with Node.js

```javascript
import puppeteer from 'puppeteer-core';

const urls = [
  'https://example.com/page1',
  'https://example.com/page2',
  'https://example.com/page3',
];

// Start obscura: obscura serve --port 9222 --workers 4
const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://127.0.0.1:9222/devtools/browser',
});

const scrape = async (url) => {
  const page = await browser.newPage();
  await page.goto(url, { waitUntil: 'networkidle0' });
  const result = await page.evaluate(() => ({
    title: document.title,
    h1: document.querySelector('h1')?.textContent,
  }));
  await page.close();
  return { url, ...result };
};

// Run with concurrency limit
const results = await Promise.all(urls.map(scrape));
console.log(JSON.stringify(results, null, 2));

await browser.disconnect();
```

### DOM-to-Markdown (LP Domain)

Obscura exposes `LP.getMarkdown` for converting pages to LLM-friendly Markdown:

```javascript
import puppeteer from 'puppeteer-core';

const browser = await puppeteer.connect({
  browserWSEndpoint: 'ws://127.0.0.1:9222/devtools/browser',
});

const page = await browser.newPage();
await page.goto('https://en.wikipedia.org/wiki/Rust_(programming_language)');

// Use CDP directly for LP domain
const client = await page.target().createCDPSession();
const { markdown } = await client.send('LP.getMarkdown');
console.log(markdown); // Clean markdown for LLM ingestion

await browser.disconnect();
```

## Stealth Mode Details

Enable with `--stealth` flag or `--features stealth` at build time.

**Anti-fingerprinting protections:**
- Per-session fingerprint randomization (GPU, screen, canvas, audio, battery)
- Realistic `navigator.userAgentData` (Chrome 145, high-entropy values)
- `event.isTrusted = true` for dispatched events
- `navigator.webdriver = undefined`
- Native function masking (`Function.prototype.toString()` → `[native code]`)
- 3,520 tracker/analytics domains blocked

```bash
# Always use stealth for anti-bot protected sites
obscura serve --port 9222 --stealth --workers 2
```

## CDP Domains Reference

| Domain | Key Methods |
|--------|-------------|
| **Target** | `createTarget`, `closeTarget`, `attachToTarget`, `createBrowserContext`, `disposeBrowserContext` |
| **Page** | `navigate`, `getFrameTree`, `addScriptToEvaluateOnNewDocument`, `lifecycleEvents` |
| **Runtime** | `evaluate`, `callFunctionOn`, `getProperties`, `addBinding` |
| **DOM** | `getDocument`, `querySelector`, `querySelectorAll`, `getOuterHTML`, `resolveNode` |
| **Network** | `enable`, `setCookies`, `getCookies`, `setExtraHTTPHeaders`, `setUserAgentOverride` |
| **Fetch** | `enable`, `continueRequest`, `fulfillRequest`, `failRequest` |
| **Storage** | `getCookies`, `setCookies`, `deleteCookies` |
| **Input** | `dispatchMouseEvent`, `dispatchKeyEvent` |
| **LP** | `getMarkdown` |

## Performance Comparison

| Metric | Obscura | Headless Chrome |
|--------|---------|-----------------|
| Memory | **30 MB** | 200+ MB |
| Binary size | **70 MB** | 300+ MB |
| Startup | **Instant** | ~2s |
| Static HTML load | **51 ms** | ~500 ms |
| JS + XHR load | **84 ms** | ~800 ms |

## Troubleshooting

**Connection refused on `ws://127.0.0.1:9222`:**
```bash
# Ensure obscura serve is running
obscura serve --port 9222
# Check it's listening
curl http://127.0.0.1:9222/json/version
```

**Page content missing (SPA/dynamic):**
```bash
# Use networkidle0 wait strategy
obscura fetch https://example.com --wait-until networkidle0

# Or wait for a specific element
obscura fetch https://example.com --selector "#app-content"
```

**Bot detection triggered:**
```bash
# Always use stealth mode for protected sites
obscura serve --port 9222 --stealth
```

**High memory usage with many pages:**
```bash
# Always close pages after use in code
await page.close();
# Use --workers to isolate processes
obscura serve --port 9222 --workers 4
```

**Proxy authentication:**
```bash
# Include credentials in proxy URL
obscura serve --port 9222 --proxy http://$PROXY_USER:$PROXY_PASS@proxy.example.com:8080
```

**Build taking too long:**
- Normal: first build ~5 min (V8 compiles from source)
- Subsequent builds use cached V8 artifacts and are much faster
- Use the pre-built binary for fastest setup
```
