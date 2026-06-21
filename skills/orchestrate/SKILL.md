---
name: orchestrate
description: >
  Classify a task and produce a delegation plan: which loop type to use (open/closed/dynamic/Workflow), which existing subagents to invoke, what eval gate to enforce, and how to report. Use when asked to orchestrate, coordinate, delegate, or route a task to specialists. Invoked as /orchestrate <task description>. Does NOT execute — it hands you the routing plan so you can confirm before running.
---

# /orchestrate — Delegation Convention

The main session (NEXUS) is the orchestrator. This skill is how it reasons about routing before acting.

## Step 1 — Classify the task

| Signal | Category |
|---|---|
| "plan", "design", "architect", touches >5 files, multiple valid approaches | **Plan** |
| "build", "implement", "fix", "refactor" + can verify with tests | **Closed-loop build** |
| "research", "explore", "investigate", "what if", no clear deliverable yet | **Open-loop research** |
| Same thing recurring, "every N minutes", "while sleeping", "keep watching" | **Recurring / scheduled** |
| Multiple independent file sets, parallel changes, migration sweep | **Workflow fan-out** |
| Single file, obvious fix, clear path, <30 min work | **Inline (no delegation)** |

## Step 2 — Pick the loop type

```
Inline          → just do it; no subagent needed
Plan            → delegate to `planner` subagent → review → then execute
Closed-loop     → /closed-loop skill: implement → gate(tests+review+types) → iterate or ship
Open-loop       → /loop dynamic (no interval); bound with turn/budget cap
Recurring       → /loop <interval> (session) OR /schedule (cloud cron, survives exit)
Workflow        → Workflow tool with pipeline()/parallel(); use isolation: worktree for parallel file edits
```

Rule: no loop without an eval gate or a hard turn/budget cap. Unbounded = slop.

## Step 3 — Map to specialists

Use existing subagents first. New agent only when it reduces friction more than maintenance.

| Work type | Route to |
|---|---|
| Pre-merge review | `code-reviewer` |
| Root-cause debug | `debugger` |
| Author tests | `test-writer` |
| Run + repair tests | `test-runner` |
| Validate "done" | `verifier` |
| Security audit | `security-auditor` |
| Prompt injection check | `injection-auditor` |
| Solana program review | `solana-reviewer` |
| Cited web research | `web-researcher` |
| Agent/prompt quality | `prompt-systems-lead` |
| Docs | `doc-writer` |
| Model/role tiering | `bsela_route` MCP tool |

Model tiering via `bsela_route`:
```
Call bsela_route with the subtask description → it returns recommended model role.
Haiku → trivial/batch  Sonnet → standard  Opus → planning/hard reasoning
```

## Step 4 — Enforce eval gate (closed loops)

Gate definition (from `/closed-loop`):
- **Tests pass** (vitest/pytest/cargo test — per language)
- **Reviewer finds nothing Critical or Major** (`code-reviewer` subagent)
- **Type-check clean** (tsc --noEmit / mypy / cargo check)
- **Lint clean** (eslint/ruff/clippy)

Gate fail → loop back to implement. Gate pass → ship. Never report "done" with a failing gate.

## Step 5 — Report the delegation plan

Output format:

```
## Delegation plan: <task>

**Category:** <from Step 1>
**Loop type:** <from Step 2>
**Specialists:** <list from Step 3>
**Eval gate:** <what must pass before "done">
**Turn/budget cap:** <N turns or $X budget>
**Hard Stops:** <any items needing explicit approval before start>

### Execution order
1. <first action + who does it>
2. <second action + who does it>
...

### Out of scope
- <things not covered by this delegation>
```

## Decision rules

**Delegate to planner when:** request is ambiguous, >5 files, or multiple valid approaches exist — never plan inline.

**Delegate to Workflow when:** ≥3 independent file sets need parallel processing, or you need adversarial verification (reviewer + skeptic pass on same findings).

**Do inline when:** task is a single clear step, <3 files, no ambiguity, and the gate is trivially checkable.

**Never:**
- Auto-deploy to `~/.claude/` — author-here → review → deploy.
- Edit governance files (`~/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.claude/settings.json`) — propose; human applies.
- Start a closed loop without an eval gate.
- Spawn a new persistent "manager daemon" — the main session is the only orchestrator.

## Usage examples

```
/orchestrate "refactor auth middleware to use JWT instead of sessions"
→ Category: Closed-loop build (touches auth, middleware, tests, types)
→ Loop: /closed-loop → implement → gate(vitest+tsc+code-reviewer) → ship
→ Specialists: code-reviewer (post-implement), security-auditor (auth change)
→ Hard Stop: auth/session changes → sign-off before execute

/orchestrate "investigate why the Solana swap bot is overpaying priority fees"
→ Category: Open-loop research
→ Loop: /loop dynamic, cap 20 turns
→ Specialists: web-researcher (fee market docs), solana-reviewer (bot code)
→ Eval gate: hypothesis confirmed + root cause identified (not "done" = just looked)

/orchestrate "migrate 40 route files from Express to Hono"
→ Category: Workflow fan-out
→ Loop: Workflow pipeline(files, transform, verify) isolation: worktree
→ Specialists: test-runner (per-file verify), code-reviewer (sample check)
→ Budget cap: set in Workflow budget.total
```

## Self-check before handing plan to user

- [ ] Loop type matches task category (no open loop for a build task).
- [ ] Every specialist named exists in `~/.claude/agents/` or is a native primitive.
- [ ] Eval gate is concrete (commands, not "verify it works").
- [ ] Hard Stops are listed before execution order.
- [ ] No new agent proposed without explicit justification.
- [ ] No governance file touched.
