```markdown
---
name: kiro-auto-aws-builder-id
description: Automate AWS Builder ID account registration and switching for Kiro IDE using Playwright browser automation with anti-detection mechanisms
triggers:
  - register kiro account automatically
  - automate aws builder id registration
  - switch kiro ide account
  - bulk register kiro accounts
  - reset kiro machine id
  - kiro auto registration with proxy
  - automate builder id account creation
  - kiro account management tool
---

# kiro-auto AWS Builder ID Tool

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

A TypeScript/Node.js tool that automates AWS Builder ID account registration for Kiro IDE using Playwright browser automation. Features temporary email integration for verification codes, browser fingerprint spoofing, anti-detection mechanisms, and interactive account switching.

## Installation

```bash
# Clone the repository
git clone https://github.com/AERT-7Y/kiro-auto.git
cd kiro-auto

# Install dependencies
npm install

# Install Playwright browser (Chromium)
npm run install-browser
```

**Requirements:**
- Node.js >= 18.0.0
- npm >= 9.x

## Key Commands

### Auto Registration

```bash
# Register a single account
npm run register -- --count 1

# Register multiple accounts sequentially
npm run register -- --count 10

# Register with concurrency (3 parallel registrations)
npm run register -- --count 10 --concurrency 3

# Register with delay between accounts (5 seconds)
npm run register -- --count 5 --delayMs 5000

# Use a proxy server
npm run register -- --count 5 --proxyUrl "http://127.0.0.1:7890"

# Non-interactive mode (no prompts)
npm run register -- --count 1 --non-interactive

# Disable fingerprint spoofing
npm run register -- --count 1 --no-fingerprint

# Disable incognito mode
npm run register -- --count 1 --no-incognito
```

### Account Switching

```bash
# Launch interactive account switcher menu
npm run switch
```

The interactive menu provides:
- Switch active Kiro account
- Restart Kiro IDE
- Reset machine ID (requires admin/root)
- View current status

## CLI Parameters Reference

| Parameter | Short | Default | Description |
|-----------|-------|---------|-------------|
| `--count` | `-n` | `1` | Number of accounts to register |
| `--concurrency` | `-c` | `1` | Parallel registration count |
| `--delayMs` | `-d` | `0` | Delay between registrations (ms) |
| `--proxyUrl` | `--proxy` | — | Proxy server URL |
| `--non-interactive` | — | — | Skip all prompts |
| `--no-fingerprint` | — | — | Disable fingerprint spoofing |
| `--no-incognito` | — | — | Disable incognito browser mode |

## Project Structure

```
kiro-auto/
├── lib/
│   ├── auth.ts              # AWS OIDC device code auth flow
│   ├── register.ts          # Core registration logic
│   └── fingerprint/
│       ├── generator.ts     # Browser fingerprint generator
│       ├── injector.ts      # Page script injector
│       └── types.ts         # TypeScript type definitions
├── scripts/
│   ├── switch.ts            # Account switcher entry point
│   └── register.ts          # Registration entry point
├── show/
│   ├── builderid-template.json  # Account data template
│   └── results.json         # Registration results output
├── package.json
└── README.md
```

## How It Works

### Registration Flow

1. **Device Code Request** — Calls AWS OIDC to get a device authorization code
2. **Temp Email** — Fetches a temporary email address for verification
3. **Browser Launch** — Opens Playwright Chromium with anti-detection settings
4. **Form Fill** — Navigates to AWS Builder ID signup and fills email/name fields
5. **OTP Retrieval** — Polls temp email API for the verification code
6. **Password Setup** — Sets account password
7. **OAuth Complete** — Finalizes device authorization, saves SSO token

### Anti-Detection Mechanisms

- **Canvas fingerprint** spoofing via injected JS
- **WebGL renderer/vendor** randomization
- **Navigator properties** override (platform, languages, plugins)
- **Input delay simulation** — randomized typing speed
- **Mouse trajectory** simulation
- **Page warm-up** behavior (scroll, hover patterns)

## Code Examples

### Using the Auth Module Directly

```typescript
import { requestDeviceCode, pollToken } from './lib/auth';

// Request AWS OIDC device code
const deviceCode = await requestDeviceCode();
console.log('Verification URI:', deviceCode.verificationUriComplete);

// Poll until user completes verification
const token = await pollToken(deviceCode.deviceCode, deviceCode.interval);
console.log('Access Token:', token.accessToken);
```

### Triggering Registration Programmatically

```typescript
import { registerAccount } from './lib/register';

const result = await registerAccount({
  count: 1,
  concurrency: 1,
  delayMs: 2000,
  proxyUrl: process.env.PROXY_URL,  // Optional: set via env var
  fingerprint: true,
  incognito: true,
});

console.log('Registered accounts:', result);
// Results are also saved to show/results.json
```

### Fingerprint Generator Usage

```typescript
import { generateFingerprint } from './lib/fingerprint/generator';
import { injectFingerprint } from './lib/fingerprint/injector';
import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: false });
const context = await browser.newContext();
const page = await context.newPage();

// Generate a randomized fingerprint profile
const fingerprint = generateFingerprint();

// Inject fingerprint scripts before page load
await injectFingerprint(page, fingerprint);

await page.goto('https://example.com');
```

### Batch Registration with Concurrency

```typescript
// Run from CLI — registers 20 accounts, 5 at a time, 3s apart
// npm run register -- --count 20 --concurrency 5 --delayMs 3000 --non-interactive

// Equivalent programmatic call:
import { registerAccount } from './lib/register';

await registerAccount({
  count: 20,
  concurrency: 5,
  delayMs: 3000,
  fingerprint: true,
  incognito: true,
});
```

### With Proxy Configuration

```typescript
// Via CLI
// npm run register -- --count 5 --proxyUrl "http://user:pass@proxy.example.com:8080"

// Via environment variable pattern (recommended)
import { registerAccount } from './lib/register';

await registerAccount({
  count: 5,
  proxyUrl: process.env.PROXY_URL,  // e.g. "http://127.0.0.1:7890"
});
```

## Configuration Files

### `show/builderid-template.json`
Template for account data structure. Registered accounts follow this schema and results are appended to `show/results.json`.

### `show/results.json`
Auto-generated file storing all successfully registered account credentials and tokens.

## Common Patterns

### Check Registration Results

```bash
# View saved accounts after registration
cat show/results.json
```

### Reset Machine ID (Windows)

Machine ID reset requires **administrator terminal**:

```bash
# Run terminal as Administrator, then:
npm run switch
# Select "Reset Machine ID" from the menu
```

Default Kiro install path (Windows):
```
C:\Users\<Username>\AppData\Local\Programs\Kiro\Kiro.exe
```

### Non-Interactive CI/CD Usage

```bash
# Fully automated, no prompts
npm run register -- --count 3 --non-interactive --no-fingerprint
```

## Troubleshooting

### Registration Fails

```bash
# 1. Verify network can reach AWS services
curl https://oidc.us-east-1.amazonaws.com

# 2. Add delay between attempts
npm run register -- --count 5 --delayMs 10000

# 3. Use a proxy if AWS blocks your IP
npm run register -- --count 5 --proxyUrl "http://127.0.0.1:7890"

# 4. Try single account first to debug
npm run register -- --count 1
```

### Browser Launch Errors

```bash
# Reinstall Playwright browser
npm run install-browser

# Or manually
npx playwright install chromium
```

### Machine ID Reset Fails

- **Windows**: Run terminal as Administrator
- **Linux/macOS**: Run with `sudo`
- Ensure Kiro IDE is fully closed before resetting

### Kiro Not Found

Default paths per OS:
- **Windows**: `C:\Users\<User>\AppData\Local\Programs\Kiro\Kiro.exe`
- **macOS**: `/Applications/Kiro.app`
- **Linux**: `/usr/bin/kiro` or `~/.local/bin/kiro`

### Temp Email Verification Timeout

The tool polls for the OTP email automatically. If it times out:
1. The temp email service may be slow — increase poll timeout in `lib/register.ts`
2. Try running a single account registration to check the flow
3. Check if the temp email provider API is accessible from your network

## TypeScript Development

```bash
# Compile TypeScript
npx tsc

# Run scripts directly with ts-node (if installed)
npx ts-node scripts/register.ts --count 1

# Watch mode for development
npx tsc --watch
```

## Legal Notice

This tool is for **learning and research purposes only**. Users must comply with AWS Terms of Service and applicable laws. The authors bear no responsibility for misuse.
```
