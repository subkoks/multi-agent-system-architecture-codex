# Claude Code Multi-Agent + Loop Architecture — Accepted Plan

**Accepted:** 2026-06-21 · **Owner:** black.terminal · **Build:** Phases 1–4 + C + D complete; **Phase E** (next-level) in `BUILD.md` (2026-07-09).

## Locked decisions

- **Scope:** PLANNER + GOVERNOR + `/orchestrate` + `/closed-loop`. BUILDER = optional Phase 4.
- **GOVERNOR cadence:** weekly `/schedule` cloud routine (survives session end). Adjustable.
- **Native-first:** no parallel framework, no per-project file zoo. Use Tasks, sessions (`-c`/`-r`), memory, BSELA, Workflow.

---

## TL;DR (honest version)

The setup is ~80% built already. The mistake to avoid is constructing a *parallel framework* (a "NEXUS shell," HANDOFF/PROGRESS/TASKS/LOOPS files, role-guard hooks, a folder tree). Claude Code's native primitives already are that framework. What's actually missing is small: a personalized **PLANNER**, a **GOVERNOR** built on the existing **BSELA**, and a **loop convention** with **eval gates** — not loop infrastructure. Realistic effort: 3–5 focused days.

---

## 1. Loops, mapped to native primitives

| Concept (loop infographic) | Native Claude Code primitive | When |
|---|---|---|
| Single-agent loop (Discovery→Plan→Execute→Verify→Iterate→**Eval Gate**) | Base agent loop; bound with `effort` + turn/budget caps | Every task |
| Fleet loop (Orchestrator→Specialists→Subagents) | Main session = orchestrator; `.claude/agents/*.md` = specialists; **Workflow** tool = deterministic fan-out | Multi-part work |
| Open looping (exploratory, unbounded) | `/loop` with **no interval** (self-paced); plan/research sessions | Planning, research |
| Closed looping (bounded, eval each step) | `/loop` + hard **eval gate** (tests + review + types) | Build & QA |
| "Better while you sleep" (recurring) | `/loop` interval (session) or **`/schedule`** (cloud cron) | Audits, doc-watch, PR babysitting |
| "No eval = slop" | Mandatory eval gate on every closed loop (§4) | Non-negotiable |

Key native facts that shaped the design:
- `/loop` runs a recurring prompt **inside the live session** (same context/tools/MCP); dies on session end (safety). Dynamic mode = "run until done."
- `/schedule` = cloud cron routines that survive session end (used by GOVERNOR).
- `Workflow` (already `enableWorkflows: true`) = the real fleet-loop engine: pipelines, verify stages, budget caps, worktree isolation.
- Subagents get own context + scoped tools + own model (route cheap work to Sonnet/Haiku). **Only the main loop orchestrates interactively** — a subagent can't be a persistent "manager daemon."

---

## 2. Already in place (do not duplicate)

- **Subagents (12):** code-reviewer, debugger, doc-writer, hacker, injection-auditor, prompt-systems-lead, solana-reviewer, test-runner, test-writer, verifier, web-researcher, security-auditor.
- **Skills (42):** incl. planner-engineer, atlas-build-app, deep-research, code-review, loop, schedule, handoff, verify, domain engineers.
- **BSELA** (data backbone of the "independent monitor"): 976 sessions, 1,022 errors, 44 lessons, 61 replay records, `bsela_audit` (weekly cost/drift/ADR), `bsela_route` (task→model-role router).
- **Hooks:** auto-format on write, bash/session logging, Stop→BSELA capture, PreToolUse test-output filter.
- Workflow engine on; memory MCP; model `opus` + `effortLevel: xhigh`.

---

## 3. Architecture

```
        YOU
         │  (talk here)
         ▼
┌─────────────────────────────────────────────┐
│  MAIN SESSION = ORCHESTRATOR ("NEXUS" persona)│  ← not a separate bot; interactive
│  plans · routes · delegates · keeps the loop  │     `claude` + /orchestrate convention
└───────┬───────────────────────────┬──────────┘
        │ delegates                  │ fans out (Workflow)
        ▼                            ▼
┌───────────────┐          ┌───────────────────────────────┐
│ PLANNER (NEW) │          │  SPECIALIST SUBAGENTS (exist)  │
│ knows me +    │          │  builder* · reviewer · debugger │
│ my stack      │          │  test-writer/runner · verifier  │
└───────────────┘          │  security/injection/solana ·    │
                           │  web-researcher · prompt-lead   │
                           └───────────────────────────────┘
        ▲                                  │ sessions/errors
        │ proposals (never auto-applies)   ▼ captured by Stop hook
┌───────────────────────────────────────────────────────────┐
│  GOVERNOR ("ATLAS", NEW) — runs on /schedule               │
│  reads: BSELA lessons+errors+audit · official Anthropic/CC │
│  docs · config drift · agent prompt quality                │
│  writes: dated upgrade PROPOSALS for approval              │
└───────────────────────────────────────────────────────────┘
* builder = optional; today the main loop writes code directly.
```

Three honest truths:
1. The "main manager AI" = the interactive session (NEXUS persona in CLAUDE.md + `/orchestrate` skill). Not an always-on daemon — the CLI doesn't work that way.
2. GOVERNOR is the standout idea and is cheap because BSELA already collects the data. It proposes; never silently rewrites governance files.
3. Parallel real-money/file-mutating work uses Workflow + worktree isolation, not hand-rolled coordination.

---

## 4. Agent roster

| Agent | Layer | Role | Status | Model |
|---|---|---|---|---|
| **NEXUS** (persona) | Orchestrator | Talks to me, plans, routes, delegates, runs loops | NEW (persona + `/orchestrate`) | opus/xhigh |
| **PLANNER** | Main | Standards-aware plans that know my stack & style | **NEW** | opus/xhigh |
| **GOVERNOR (ATLAS)** | Main | Independent auditor: BSELA + docs + drift → proposals | **NEW** (on BSELA) | opus/high |
| BUILDER/implementer | Sub | Scoped code execution for parallel worktree tasks | OPTIONAL | sonnet |
| code-reviewer | Sub | Pre-merge correctness/security/perf | ✅ | sonnet |
| debugger | Sub | Root-cause, reproduce-first | ✅ | sonnet/opus |
| test-writer / test-runner / verifier | Sub | Author / run+repair / validate done | ✅ | sonnet/haiku |
| security/injection/solana/hacker | Sub | Security & Solana review | ✅ | sonnet/opus |
| web-researcher | Sub | Cited research in own context | ✅ | sonnet |
| prompt-systems-lead | Sub | Improves other agents' prompts → feeds GOVERNOR | ✅ | opus |

**Net new: 2 agents + 2 skills.** Optional BUILDER. Resist adding more.

---

## 5. Loop strategy (convention per work type)

- **Build/fix → Closed loop + eval gate:** `implement → verify → gate`. Gate = tests pass AND reviewer finds nothing critical AND type-check clean. Fail → loop back. (`/closed-loop` skill or Workflow.)
- **Plan/research/explore → Open loop**, bounded by turns/budget (`effort: high`, capped turns).
- **"Run until done" → `/loop` dynamic** (no interval).
- **Recurring/light → `/loop` interval** (session) or **`/schedule`** (cloud) for GOVERNOR.
- **Parallel multi-file/migration/audit → Workflow** with `isolation: worktree`.

---

## 6. High-leverage ideas (worth doing)

1. **GOVERNOR-on-BSELA loop** — weekly `/schedule`: run `bsela_audit`, read top lessons + recurring error categories, WebFetch Anthropic/Claude Code changelog & docs, diff vs config → emit dated `UPGRADE-PROPOSALS.md`. Approve manually.
2. **Eval-gate as a skill** — one "done" definition every closed loop calls. Kills slop systemically.
3. **Doc-watcher** — GOVERNOR sub-task flags new CC features so the setup never drifts behind releases.
4. **Model-tiering via `bsela_route`** — auto-pick Haiku/Sonnet/Opus per subtask; saves the 5-hour budget.
5. **Personalized PLANNER** seeded from AGENTS.md + memory → plans in my idioms (Solana-first, security-gated, lean-file).

---

## 7. What NOT to build (anti-hype)

- ❌ No "NEXUS daemon" / parallel control system — main session is the orchestrator.
- ❌ No HANDOFF/PROGRESS/TASKS/LOOPS file zoo per project — use native Tasks, sessions, memory.
- ❌ No 13-agent roster — maintenance > leverage.
- ❌ No unbounded loops without eval gate or budget cap.
- ❌ Builder agents never edit governance files (AGENTS.md, settings.json) — GOVERNOR proposes, I approve.

---

## 8. Build order (~3–5 days)

- **Phase 1 (½ day):** `planner` agent (seeded from AGENTS.md + memory) + `/orchestrate` skill + NEXUS persona block in CLAUDE.md. Test on a real task.
- **Phase 2 (1 day):** `/closed-loop` eval-gate skill (tests+review+types). Wire into a sample review Workflow.
- **Phase 3 (1–2 days):** `governor` agent + weekly `/schedule` routine on BSELA + doc-watcher → `UPGRADE-PROPOSALS.md`. Dry-run once.
- **Phase 4 (optional, ½ day):** `builder` agent for worktree-isolated parallel work; enable `bsela_route` model-tiering by default.

Each phase independently shippable and reversible. Detailed file specs + acceptance criteria in `BUILD.md`.

---

## Sources

- [Agent loop (official)](https://code.claude.com/docs/en/agent-sdk/agent-loop)
- [Subagents (official)](https://code.claude.com/docs/en/sub-agents)
- [/loop guide](https://www.mindstudio.ai/blog/what-is-claude-code-loop-command-recurring-tasks)
- [Claude Code 2026 features](https://www.marktechpost.com/2026/06/14/claude-code-guide-2026-25-features-with-examples-demo/)
- [Multi-agent orchestration](https://shipyard.build/blog/claude-code-multi-agent/)
- [Agent Orchestra — Addy Osmani](https://addyosmani.com/blog/code-agent-orchestra/)
- [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)
- [wshobson/agents](https://github.com/wshobson/agents)
- [VoltAgent subagents](https://github.com/VoltAgent/awesome-claude-code-subagents)
