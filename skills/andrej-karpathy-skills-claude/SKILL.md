```markdown
---
name: andrej-karpathy-skills-claude
description: CLAUDE.md guidelines derived from Andrej Karpathy's LLM coding pitfalls observations — four principles to reduce AI coding mistakes
triggers:
  - install karpathy claude guidelines
  - add karpathy skills to my project
  - improve claude code behavior
  - reduce llm coding mistakes
  - add claude md guidelines
  - setup karpathy coding principles
  - configure claude code best practices
  - prevent ai overcomplicated code
---

# Andrej Karpathy Skills for Claude Code

> Skill by [ara.so](https://ara.so) — Daily 2026 Skills collection.

A single `CLAUDE.md` file that installs four principles into Claude Code (or any AI coding agent) derived from Andrej Karpathy's observations on common LLM coding pitfalls — silent assumptions, overengineering, orthogonal edits, and vague task execution.

## What This Project Does

This repo provides a battle-tested `CLAUDE.md` configuration that addresses four core failure modes Karpathy identified in LLM-assisted coding:

| Problem | Principle Applied |
|---------|------------------|
| Silent wrong assumptions, no clarification | **Think Before Coding** |
| Overengineered, bloated abstractions | **Simplicity First** |
| Touching code unrelated to the task | **Surgical Changes** |
| Vague imperatives with no success criteria | **Goal-Driven Execution** |

## Installation

### Option A: Claude Code Plugin (recommended, all projects)

Run inside Claude Code:

```
/plugin marketplace add forrestchang/andrej-karpathy-skills
/plugin install andrej-karpathy-skills@karpathy-skills
```

This makes the guidelines available across every project without per-repo setup.

### Option B: Per-Project CLAUDE.md

**New project:**
```bash
curl -o CLAUDE.md https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md
```

**Existing project (append to current CLAUDE.md):**
```bash
echo "" >> CLAUDE.md
curl https://raw.githubusercontent.com/forrestchang/andrej-karpathy-skills/main/CLAUDE.md >> CLAUDE.md
```

**Verify installation:**
```bash
cat CLAUDE.md
```

## The Four Principles

### 1. Think Before Coding

Force explicit reasoning before implementation. The agent must:
- State assumptions before writing code
- Present multiple interpretations when ambiguity exists
- Ask rather than guess when uncertain
- Push back if a simpler approach exists

**You'll see this working when** Claude asks clarifying questions before starting, not after producing wrong output.

### 2. Simplicity First

No speculative features, no premature abstractions, no unrequested flexibility.

**The senior engineer test:** Would a senior engineer call this overcomplicated? If yes, rewrite it simpler.

Examples the principle prevents:
- Adding `configurable` options when one hardcoded value was needed
- Wrapping a 3-line function in a class with 5 methods
- Error handling for scenarios that cannot happen in the given context

### 3. Surgical Changes

When editing existing code, touch only what the request requires:

```
✅ Remove imports YOUR changes made unused
✅ Delete functions YOUR changes orphaned
❌ Refactor adjacent code that wasn't broken
❌ Fix formatting in untouched files
❌ Delete pre-existing dead code (mention it instead)
```

**The diff test:** Every changed line must trace directly to the user's request.

### 4. Goal-Driven Execution

Transform imperative tasks into verifiable success criteria:

```
Instead of: "Add input validation"
Write:       "Write tests for invalid inputs, then make them pass"

Instead of: "Fix the bug"
Write:       "Write a test reproducing the bug, then make it pass"

Instead of: "Refactor X"
Write:       "Ensure all tests pass before and after, no behavior change"
```

For multi-step tasks, the agent should produce a plan:
```
1. Add schema validation → verify: unit tests pass
2. Wire to API handler  → verify: integration test passes
3. Update docs          → verify: examples match new API
```

## Adding Project-Specific Rules

The CLAUDE.md is designed to merge with your existing instructions. After installing, append your project context:

```markdown
## Project-Specific Guidelines

- Use TypeScript strict mode everywhere
- All new API endpoints require an integration test in `tests/api/`
- Follow error handling patterns established in `src/utils/errors.ts`
- Database migrations go in `db/migrations/` with timestamp prefix
- Never mutate `req` or `res` objects directly — use the wrapper helpers
```

## Real Usage Examples

### Triggering Think Before Coding

When a request is ambiguous, the agent should respond:

```
I see two interpretations of "add caching":
A) In-memory cache per process (fast, no infra)
B) Redis cache shared across instances (persistent, needs Redis)

Which do you want? Or is there a third option I'm missing?
```

### Triggering Simplicity First

Bad (what the principle prevents):
```python
class ValidationStrategy(ABC):
    @abstractmethod
    def validate(self, value: Any) -> ValidationResult: ...

class EmailValidationStrategy(ValidationStrategy):
    def validate(self, value: Any) -> ValidationResult:
        # 40 more lines...
```

Good (what the principle produces):
```python
def is_valid_email(value: str) -> bool:
    return "@" in value and "." in value.split("@")[-1]
```

### Triggering Surgical Changes

Given task: "Fix the off-by-one error in `calculate_total()`"

```python
# BEFORE
def calculate_total(items):
    total = 0
    for i in range(len(items) - 1):  # bug: misses last item
        total += items[i].price
    return total

# AFTER (surgical — only the bug is fixed)
def calculate_total(items):
    total = 0
    for i in range(len(items)):  # fixed
        total += items[i].price
    return total
```

The agent should NOT also rename variables, reformat, or switch to `sum()` unless asked.

### Triggering Goal-Driven Execution

```markdown
## Task

Refactor the authentication middleware.

## Success Criteria

1. All existing auth tests in `tests/test_auth.py` pass unchanged
2. No new public API surface (same function signatures)
3. `mypy --strict` reports no new errors
4. Response time for `/api/health` unchanged (< 5ms)
```

## Common Patterns

### Pattern: Clarify Before Long Tasks

For tasks estimated over 30 minutes, the agent should surface assumptions first:

```
Before I start, confirming my understanding:
- Scope: only the `UserService` class, not `AuthService`
- Test coverage: existing tests must still pass
- Breaking changes: none (same public interface)

Does this match your intent?
```

### Pattern: Mention, Don't Fix

When the agent spots unrelated issues:

```
Note: I noticed `utils/legacy_parser.py` appears unused — not touching 
it as it's outside this task's scope, but flagging for your awareness.
```

### Pattern: Plan Then Execute

For multi-file changes:

```
Plan:
1. Update `schema.py` with new field → verify: `python -m pytest tests/test_schema.py`
2. Add migration file → verify: `alembic upgrade head` succeeds
3. Update API handler → verify: `python -m pytest tests/test_api.py`
4. Update OpenAPI spec → verify: spec validates against handler

Proceeding with step 1...
```

## Troubleshooting

### Guidelines not being followed

**Check:** Is the CLAUDE.md in the project root (where Claude Code is launched)?
```bash
ls -la CLAUDE.md
```

**Check:** Did the plugin install correctly?
```
/plugin list
```

**Check:** For existing CLAUDE.md files, did the append work?
```bash
grep -n "Think Before Coding" CLAUDE.md
```

### Agent still making unrequested changes

Add an explicit project-specific rule in your CLAUDE.md:

```markdown
## Hard Rules

- NEVER modify files not mentioned in the task
- NEVER change formatting or style in untouched files
- ALWAYS confirm scope before editing more than 3 files
```

### Agent not asking clarifying questions

Prompt engineering tip — rephrase tasks to invite questions:

```
Before implementing: "Add rate limiting — ask me any clarifying 
questions before writing code."
```

### Conflicting with existing CLAUDE.md rules

The Karpathy guidelines are additive. If conflicts arise, put project-specific rules after the appended content — later rules take precedence in most agents.

## Knowing It's Working

✅ Diffs contain only requested changes  
✅ Clarifying questions appear before implementation  
✅ Code is simple the first time, not after rewrites  
✅ PRs have no drive-by refactoring  
✅ Agent states its plan before multi-step tasks  

## Tradeoff

These guidelines bias toward **caution over speed**. For trivial one-liners, full rigor isn't needed. The value is on non-trivial work where silent wrong assumptions or overengineering create costly rework.
```
