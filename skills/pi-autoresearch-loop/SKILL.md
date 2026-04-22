---
name: pi-autoresearch-loop
description: "Autonomous experiment loop extension for pi that proposes changes, benchmarks them, commits wins, and reverts losses. Use when setting up continuous optimization for test speed, bundle size, build time, or any measurable metric via autoresearch."
triggers:
  - autoresearch
  - autonomous experiment loop
  - optimize automatically
  - run experiment loop
  - continuous optimization
  - benchmark and improve
  - start autoresearch session
  - keep what works discard what doesnt
---

# pi-autoresearch — Autonomous Experiment Loop

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection

Autonomous experiment loop extension for [pi](https://github.com/antiwork/pi). Continuously proposes changes, benchmarks them, commits wins, reverts losses, and repeats — forever. Works for any measurable target: test speed, bundle size, build time, LLM training loss, Lighthouse scores.

---

## Installation

```bash
pi install https://github.com/davebcn87/pi-autoresearch
```

**Manual install:**

```bash
cp -r extensions/pi-autoresearch ~/.pi/agent/extensions/
cp -r skills/autoresearch-create ~/.pi/agent/skills/
```

Then `/reload` in pi.

---

## Quick Start

```
/skill:autoresearch-create
```

The agent will:
1. Ask about your goal, command, metric, and files in scope (or infer from context)
2. Create a branch
3. Write `autoresearch.md` and `autoresearch.sh`
4. Run the baseline
5. Start looping immediately — no further input needed

---

## Core Concepts

### Two-file persistence model

Every session is fully recoverable from two files:

| File | Purpose |
|------|---------|
| `autoresearch.jsonl` | Append-only log — one JSON line per run (metric, status, commit, description) |
| `autoresearch.md` | Living document — objective, what's been tried, dead ends, key wins |

A fresh agent with zero memory can read these two files and continue exactly where the previous session left off.

### Session files written by the skill

| File | Purpose |
|------|---------|
| `autoresearch.md` | Session document — objective, metrics, files in scope, experiment history |
| `autoresearch.sh` | Benchmark script — pre-checks, runs the workload, outputs `METRIC name=number` lines |
| `autoresearch.checks.sh` | *(optional)* Backpressure checks — tests, types, lint. Failures block `keep` |

---

## Extension Tools

### `init_experiment`

One-time session configuration. Call once at session start.

```typescript
await init_experiment({
  name: "vitest-speed",
  metric: "seconds",
  unit: "s",
  direction: "lower", // "lower" | "higher"
});
```

### `run_experiment`

Runs any shell command, times wall-clock duration, captures stdout/stderr.

```typescript
const result = await run_experiment({
  command: "pnpm test --run",
  timeout_seconds: 120,           // optional, default 300
  checks_timeout_seconds: 300,    // optional, for checks script
});
// result: { exit_code, duration_seconds, stdout, stderr }
```

### `log_experiment`

Records result, auto-commits on `keep`, updates the status widget and dashboard.

```typescript
await log_experiment({
  metric_value: 42.3,
  status: "keep",          // "keep" | "discard" | "crash" | "checks_failed"
  description: "Enable parallel test workers in vitest config",
  commit_message: "perf: parallel vitest workers → 42.3s (-18%)",
});
```

---

## The Autonomous Loop

Once started, the agent runs this cycle indefinitely:

```
propose change → edit files → run_experiment → measure metric
       ↓
  metric improved?
    YES → log_experiment(keep) → auto-commit → update autoresearch.md
    NO  → log_experiment(discard) → git revert → try next idea
       ↓
  repeat forever (until interrupted)
```

**Interrupt anytime** with `Escape`, then ask for a summary of what was tried.

---

## Benchmark Script Format

`autoresearch.sh` must output at least one `METRIC` line:

```bash
#!/bin/bash
set -euo pipefail

# Pre-checks
[ -f package.json ] || { echo "No package.json"; exit 1; }

# Run workload
pnpm test --run

# Output metric — required format
echo "METRIC seconds=$SECONDS"
```

Multiple metrics are supported:

```bash
echo "METRIC duration_seconds=42.3"
echo "METRIC test_count=847"
echo "METRIC memory_mb=512"
```

The primary metric (set in `init_experiment`) drives keep/discard decisions. Others are recorded for analysis.

---

## Backpressure Checks (Optional)

Create `autoresearch.checks.sh` to guard correctness after every passing benchmark:

```bash
#!/bin/bash
set -euo pipefail

pnpm test --run          # full test suite
pnpm typecheck           # TypeScript
pnpm lint                # ESLint / Biome
```

**Behavior:**
- File absent → loop runs exactly as before, no change
- File present → runs automatically after every benchmark that exits 0
- Checks time does **not** count toward the primary metric
- Checks failure → logged as `checks_failed`, changes reverted (same as crash)
- Dashboard shows `checks_failed` separately from `crash` so you can distinguish correctness failures from benchmark errors

---

## UI

### Status Widget

Always visible above the editor:

```
🔬 autoresearch 12 runs 8 kept │ best: 42.3s
```

### Dashboard

Open with `/autoresearch` — full results table with status, metric values, descriptions, and best run highlighted.

- `Ctrl+X` — toggle dashboard
- `Escape` — close dashboard / interrupt loop

---

## Example Domains

```typescript
// Test speed
{
  command: "pnpm test --run",
  metric: "seconds",
  direction: "lower",
  scope: ["vitest.config.ts", "src/**/*.test.ts"],
}

// Bundle size
{
  command: "pnpm build && du -sb dist | cut -f1",
  metric: "bytes",
  direction: "lower",
  scope: ["vite.config.ts", "src/index.ts"],
}

// LLM training loss
{
  command: "uv run train.py --epochs 1",
  metric: "val_bpb",
  direction: "lower",
  scope: ["train.py", "model.py", "config.yaml"],
}

// Build speed
{
  command: "pnpm build",
  metric: "seconds",
  direction: "lower",
  scope: ["tsconfig.json", "vite.config.ts"],
}

// Lighthouse performance
{
  command: "lighthouse http://localhost:3000 --output=json | jq '.categories.performance.score'",
  metric: "score",
  direction: "higher",
  scope: ["src/pages/index.tsx", "public/"],
}
```

---

## autoresearch.md Structure

The skill writes and maintains this file throughout the session:

```markdown
# autoresearch: vitest-speed

## Objective
Reduce test suite wall-clock time. Baseline: 51.7s.

## Metric
- Name: seconds
- Direction: lower is better
- Baseline: 51.7s
- Best so far: 42.3s (run 8)

## Files in scope
- vitest.config.ts
- src/**/*.test.ts

## What's been tried
- [kept] Run 8: Enable parallel workers → 42.3s (-18%)
- [discarded] Run 5: Increase pool size to 16 → 53.1s (+3%)
- [kept] Run 3: Disable coverage in CI → 47.8s (-8%)

## Dead ends
- Increasing pool beyond 8 causes memory pressure, net negative

## Next ideas
- [ ] Try forks pool instead of threads
- [ ] Investigate slow test files with --reporter=verbose
```

---

## autoresearch.jsonl Format

One JSON object per line:

```jsonl
{"run":1,"metric_value":51.7,"status":"keep","description":"baseline","commit":"a1b2c3d","timestamp":"2025-01-15T10:00:00Z"}
{"run":2,"metric_value":49.2,"status":"keep","description":"disable coverage","commit":"e4f5g6h","timestamp":"2025-01-15T10:03:21Z"}
{"run":3,"metric_value":53.1,"status":"discard","description":"increase pool to 16","commit":null,"timestamp":"2025-01-15T10:07:45Z"}
{"run":4,"metric_value":null,"status":"crash","description":"invalid vitest config syntax","commit":null,"timestamp":"2025-01-15T10:09:12Z"}
```

Read the log programmatically:

```typescript
import { readFileSync } from "fs";

const runs = readFileSync("autoresearch.jsonl", "utf-8")
  .trim()
  .split("\n")
  .map((line) => JSON.parse(line));

const kept = runs.filter((r) => r.status === "keep");
const best = kept.reduce((a, b) =>
  a.metric_value < b.metric_value ? a : b
);

console.log(`Best: ${best.metric_value} — ${best.description}`);
```

---

## Resuming a Session

The agent can resume from either file. Recommended resume prompt:

```
Read autoresearch.jsonl and autoresearch.md, then continue the experiment loop.
Don't restart — pick up from run N and keep going.
```

Or use the skill:

```
/skill:autoresearch-create resume
```

---

## Troubleshooting

**Loop not starting after skill runs**
- Check that `autoresearch.sh` is executable: `chmod +x autoresearch.sh`
- Verify the script outputs a `METRIC name=number` line on success
- Run `bash autoresearch.sh` manually to debug

**Widget not showing**
- Run `/reload` in pi to reload the extension
- Confirm the extension is in `~/.pi/agent/extensions/pi-autoresearch/`

**`run_experiment` times out**
- Increase `timeout_seconds` in your `run_experiment` call
- Default is 300s — long benchmarks (LLM training) may need 3600+

**Checks script blocking everything**
- Check `autoresearch.checks.sh` exit codes manually: `bash autoresearch.checks.sh`
- Increase `checks_timeout_seconds` if tests are slow
- Remove the file temporarily to isolate whether the benchmark or checks are failing

**Session lost after context reset**
- The agent needs only `autoresearch.jsonl` + `autoresearch.md` to resume
- Both files are committed to the branch — they survive any context reset
- Use the resume prompt above to continue

**Metric value not captured**
- Ensure the benchmark script exits 0 on success
- The `METRIC` line must be on stdout, not stderr
- Format must be exactly `METRIC name=number` (no spaces around `=`)

---

## License

MIT
