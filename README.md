# claude-agent-system

Lean, native-first multi-agent + loop architecture for the BLACK.TERMINAL Claude Code setup.

**Status:** ✅ Plan accepted (2026-06-21). 🔨 Build starts **next session** — nothing is wired into the live setup yet.

## What this is

A small layer on top of what already exists (12 subagents, 42 skills, BSELA, Workflow engine, hooks). It adds exactly:

1. **PLANNER** agent — personalized, standards-aware plans that know my stack & style.
2. **GOVERNOR (ATLAS)** agent — independent system auditor on top of BSELA; reads lessons/errors/docs/drift → emits dated upgrade *proposals* (never auto-applies).
3. **`/orchestrate`** skill — codifies how the main session delegates + runs eval-gated loops.
4. **`/closed-loop`** skill — one reusable definition of "done" (tests + review + types + lint).

Optional later: **BUILDER** agent for worktree-isolated parallel implementation.

## Why native-first

The main `claude` session **is** the orchestrator ("NEXUS" persona). Subagents are specialists. `Workflow` is the fan-out engine. `/loop` + `/schedule` are the loop primitives. We do **not** build a parallel framework or a file zoo — see PLAN.md §7.

## Layout

```
claude-agent-system/
├── README.md      ← you are here
├── PLAN.md        ← the accepted architecture plan (source of truth)
├── BUILD.md       ← phased resume map: exact files to create + acceptance criteria
├── agents/        ← target: planner.md, governor.md, (later) builder.md
├── skills/        ← target: orchestrate/SKILL.md, closed-loop/SKILL.md
└── reference/
    └── research-notes.md  ← loop/subagent facts + sources (no re-research needed)
```

## How to resume (next session)

```
cd ~/Projects/claude-agent-system
claude
> Read BUILD.md and start Phase 1.
```

Build is phased and reversible. Each agent/skill is authored **here** first, reviewed, then deployed to `~/.claude/agents/` and `~/.claude/skills/` (symlink or copy) — deployment is a deliberate step, not automatic.
