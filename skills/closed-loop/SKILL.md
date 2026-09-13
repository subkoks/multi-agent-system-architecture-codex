---
name: closed-loop
description: >
  Closed-loop build skill with a hard eval gate. Use for any build, fix, or refactor where "done" must be verified — not just claimed. Runs: implement → gate(tests + reviewer + type-check + lint) → loop back on failure → ship on pass. Invoke as /closed-loop <task>. Hard cap: 5 gate iterations before reporting [BLOCKED]. Never reports "done" with a failing gate.
---

# /closed-loop — Eval-Gated Build Loop

One reusable definition of "done." Every closed loop calls this gate. No eval = slop.

## Done = ALL four pass

| Gate | What passes |
|---|---|
| **Tests** | Test suite exits 0 with no skipped-due-to-error |
| **Reviewer** | `reviewer` agent (Codex) finds no Critical or Major findings |
| **Type-check** | Type checker exits 0 |
| **Lint** | Linter exits 0 (warnings allowed; errors not) |

If any leg fails → not done. Fix the specific failure. Re-run gate. Repeat until all pass or budget hits.

## Per-language gate commands

Detect language from: `package.json` (TS/JS), `pyproject.toml`/`setup.py` (Python), `Cargo.toml` (Rust). Run ALL that apply for mixed repos.

**Discover repo-defined commands first.** If the repo defines its own test/lint/typecheck commands (package.json `scripts`, `Makefile`, `Justfile`, CI workflow, repo `AGENTS.md`), use those exact commands — not the generic ones below. Never use `npx --yes` or silently download gate tooling; everything the gate runs must already be declared in the repo.

### TypeScript / JavaScript
```bash
# Tests
npx vitest run --reporter=verbose 2>&1 | tail -40

# Type-check
npx tsc --noEmit 2>&1

# Lint
npx eslint . --max-warnings=0 2>&1
```

### Python
```bash
# Tests (stop on first failure)
pytest -x --tb=short 2>&1 | tail -40

# Lint + type
ruff check . 2>&1
mypy . --ignore-missing-imports 2>&1    # only if mypy is configured
```

### Rust
```bash
# Tests
cargo test 2>&1 | tail -40

# Type + lint
cargo check 2>&1
cargo clippy -- -D warnings 2>&1
```

### Next.js / React
```bash
npx vitest run --reporter=verbose 2>&1 | tail -40
npx tsc --noEmit 2>&1
npx eslint . --max-warnings=0 2>&1
npx next build 2>&1 | tail -20    # only if the change could affect the build
```

### Playwright (E2E, run only on explicit request)
```bash
npx playwright test --reporter=line 2>&1 | tail -40
```

## Loop protocol

```
MAX_ITERATIONS = 5   # hard cap — never exceed without explicit user override

iteration = 1
while iteration <= MAX_ITERATIONS:
    1. IMPLEMENT — make or continue the change (inline or via subagent)
    2. GATE — run all applicable commands above; capture output
    3. REVIEW — spawn the `reviewer` agent on the current diff
    4. EVALUATE:
       - all gate commands exit 0?  →  Yes
       - reviewer has no Critical/Major?  →  Yes
       If ALL Yes → SHIP (report [DONE])
       Else → diagnose failure, loop back to IMPLEMENT (iteration += 1)

if iteration > MAX_ITERATIONS:
    report [BLOCKED: gate still failing after 5 iterations]
    show the last gate output + reviewer findings
    stop — do not claim done
```

## Diagnosing failures

Before looping back, read the failure output completely:

- **Test failure:** reproduce the specific failing test case; fix root cause, not just the assertion.
- **Type error:** fix the type at the source — no `as any`, no `// @ts-ignore` unless the type system genuinely can't express it (document why).
- **Lint error:** fix the violation; never disable a rule to make lint pass without explaining why.
- **Reviewer Critical/Major:** treat as a blocking bug — fix before shipping.
- **Same failure twice:** switch strategy. Don't loop on the same approach a third time.

## Hard rules

- **Never** report `[DONE]` with a red gate.
- **Never** silence the gate to make it pass (disable rules, skip tests, `--force`).
- **Never** run more than MAX_ITERATIONS without stopping and reporting [BLOCKED].
- Governance files (`~/AGENTS.md`, `~/.claude/*`, `~/.cursor/*`, Codex/OpenCode mirrors) are off-limits even inside a build loop.
- Real-money flows (Solana transactions, payment APIs) require `solana-reviewer` or `security-auditor` pass before the gate is considered green — add as a 5th gate leg when the change touches these.

## Invocation examples

```
/closed-loop "add JWT middleware to the Express auth routes"
→ detect TS repo → implement JWT middleware → run vitest+tsc+eslint → reviewer → ship or loop

/closed-loop "fix the pytest failures in tests/test_swap.py"
→ detect Python → implement fix → run pytest+ruff → reviewer → ship or loop

/closed-loop "refactor Anchor program to use new account constraints"
→ detect Rust → implement → run cargo test+clippy → reviewer + solana-reviewer → ship or loop
```

## Gate output format (report after each iteration)

```
## Gate — iteration N/5

| Leg | Status | Detail |
|---|---|---|
| Tests | ✅ PASS / ❌ FAIL | N passed, M failed — <first failure> |
| Type-check | ✅ PASS / ❌ FAIL | <first error line> |
| Lint | ✅ PASS / ❌ FAIL | N errors |
| Reviewer | ✅ PASS / ❌ FAIL | N Critical, M Major |

**Gate: PASS → [DONE]** / **FAIL → looping (fixing: <what>)**
```

## Ship report

When gate passes:

```
[DONE] — gate green after N iteration(s).

| Leg | Result |
|---|---|
| Tests | ✅ N passed |
| Type-check | ✅ clean |
| Lint | ✅ clean |
| Reviewer | ✅ no Critical/Major |

Changes committed: <files changed>
Next: PR / deploy / Phase N+1 as applicable.
```
