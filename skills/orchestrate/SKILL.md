---
name: orchestrate
description: >
  Classify a task and produce a delegation plan: which loop type to use (closed/open/dynamic), which Codex agents to spawn, what eval gate to enforce, and how to report. Use when asked to orchestrate, coordinate, delegate, or route a task to specialists. Invoked as $orchestrate <task description>. Does NOT execute — it hands you the routing plan so you can confirm before running.
---

# $orchestrate — Delegation Convention

The main session is the orchestrator. This skill is how it reasons about routing before acting.

## Step 1 — Classify the task

| Signal | Category |
|---|---|
| "plan", "design", "architect", touches >5 files, multiple valid approaches | **Plan** |
| "build", "implement", "fix", "refactor" + can verify with tests | **Closed-loop build** |
| "research", "explore", "investigate", "what if", no clear deliverable yet | **Open-loop research** |
| Same thing recurring, "every N minutes", "while sleeping", "keep watching" | **Recurring / scheduled** |
| Multiple independent file sets, parallel changes, migration sweep | **Parallel fan-out** |
| Single file, obvious fix, clear path, <30 min work | **Inline (no delegation)** |

## Step 2 — Pick the loop type

```
Inline          → just do it; no subagent needed
Plan            → delegate to `planner` agent → review → then execute
Closed-loop     → $closed-loop skill: implement → gate(tests + reviewer) → iterate or ship
Open-loop       → $loop dynamic (no interval); bound with turn/budget cap
Recurring       → $loop <interval> (session) or a local LaunchAgent checklist
Parallel        → subagent workflow: spawn one agent per independent point, wait, consolidate
```

Rule: no loop without an eval gate or a hard turn/budget cap. Unbounded = slop.

**Depth cap:** nested delegation is capped at 5 levels — plan delegation trees accordingly.

## Step 3 — Route to a Codex agent

Repo-native agents (`.codex/agents/*.toml`):

| Work type | Route to |
|---|---|
| Plan a big change | `planner` (read-only) |
| Scoped parallel file changes (1–5 files) | `builder` (one per disjoint file set) |
| Pre-merge / gate review | `reviewer` (read-only) |
| System audit / drift / BSELA | `governor` |
| Root-cause debug | main session, or `builder` with a bounded spec |
| Cited web research | main session (webfetch/websearch) |

Call `bsela_route` first for every delegated subtask when the BSELA MCP is available; treat its role/model suggestion as a routing hint. Models are inherited from the parent session unless the task needs a different reasoning effort — repo agents carry no hardcoded model pins.

## Codex delegation rules

- Delegate explicitly: "spawn N agents", "use one agent per point", and say whether to wait for all before continuing.
- **Write isolation:** on a shared checkout, never give two agents overlapping write sets. Parallel writes require worktree isolation or disjoint files; otherwise serialize. Parallel read work (exploration, review, research) is the safe default.
- Cap spawned threads at three (repo `.codex/config.toml` sets `agents.max_concurrent_threads_per_session = 3`).
- The closed-loop gate uses the Codex `reviewer` agent for the review leg (see `$closed-loop`).
- Respect the five-iteration closed-loop cap; no unbounded loops.

## Step 4 — Enforce eval gate (closed loops)

Gate definition (from `$closed-loop`):
- **Tests pass** (repo-defined test commands)
- **Reviewer finds nothing Critical or Major** (`reviewer` agent)
- **Type-check clean** (repo-defined typecheck command)
- **Lint clean** (repo-defined lint command)

Gate fail → loop back to implement. Gate pass → ship. Never report "done" with a failing gate.

## Step 5 — Report the delegation plan

Output format:

```
## Delegation plan: <task>

**Category:** <from Step 1>
**Loop type:** <from Step 2>
**Agents:** <list from Step 3>
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

**Delegate to `planner` when:** request is ambiguous, >5 files, or multiple valid approaches exist — never plan inline.

**Delegate to parallel agents when:** ≥3 independent file sets need processing, or you need adversarial verification. Keep writes isolated.

**Do inline when:** task is a single clear step, <3 files, no ambiguity, and the gate is trivially checkable.

**Never:**
- Auto-deploy to personal dirs — author-here → review → deploy via `scripts/install-codex-local.sh --apply` (approval-gated).
- Edit governance files (`~/AGENTS.md`, `~/.claude/*`, `~/.cursor/*`, Codex/OpenCode mirrors).
- Start a closed loop without an eval gate.
- Spawn a new persistent "manager daemon" — the main session is the only orchestrator.

## Self-check before handing plan to user

- [ ] Loop type matches task category (no open loop for a build task).
- [ ] Every agent named exists in `.codex/agents/` or is built-in.
- [ ] Eval gate is concrete (commands, not "verify it works").
- [ ] Hard Stops are listed before execution order.
- [ ] No new agent proposed without explicit justification.
- [ ] No governance file touched.
