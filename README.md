# multi-agent-system-architecture-claude-cli

Lean, native-first multi-agent + loop architecture for the BLACK.TERMINAL Claude Code setup.

**Status:** ✅ Claude build complete (2026-06-21, BUILD.md Phases 1–4). ✅ Cursor integrated (~90%) via `integrate-cursor-from-claude.sh` — see [CURSOR.md](./CURSOR.md).

## What this is

A small layer on top of what already exists (12 subagents, 42 skills, BSELA, Workflow engine, hooks). It adds exactly:

1. **PLANNER** agent — personalized, standards-aware plans that know my stack & style.
2. **GOVERNOR (ATLAS)** agent — independent system auditor on top of BSELA; reads lessons/errors/docs/drift → emits dated upgrade *proposals* (never auto-applies).
3. **`/orchestrate`** skill — codifies how the main session delegates + runs eval-gated loops.
4. **`/closed-loop`** skill — one reusable definition of "done" (tests + review + types + lint).
5. **BUILDER** agent — scoped implementer for parallel work (optional Phase 4).

## Why native-first

The main session **is** the orchestrator ("NEXUS" persona). Subagents are specialists. `Workflow` (Claude) / Task parallel (Cursor) is the fan-out engine. `/loop` is the loop primitive. We do **not** build a parallel framework or a file zoo — see PLAN.md §7.

## Layout

```
multi-agent-system-architecture-claude-cli/
├── README.md      ← you are here
├── CURSOR.md      ← Cursor integration + deploy ritual
├── PLAN.md        ← the accepted architecture plan (source of truth)
├── BUILD.md       ← phased resume map: exact files to create + acceptance criteria
├── agents/        ← planner.md, governor.md, builder.md
├── skills/        ← orchestrate/SKILL.md, closed-loop/SKILL.md
└── reference/
    └── research-notes.md  ← loop/subagent facts + sources (no re-research needed)
```

## How to resume

**Claude Code:**
```
cd ~/Projects/multi-agent-system-architecture-claude-cli
claude
> Read BUILD.md. All phases complete — run governor or extend with a new phase.
```

**Cursor:** see [CURSOR.md](./CURSOR.md).

Build is phased and reversible. Each agent/skill is authored **here** first, reviewed, then deployed to `~/.claude/...` and synced to `~/.cursor/...` via the integrate script — deployment is deliberate, not automatic.

## Codex CLI

This repo includes a root `AGENTS.md` and `.codex/config.toml`, so Codex CLI can use the same project guidance in this workspace.

Recommended entrypoint:

```
cd ~/Projects/multi-agent-system-architecture-claude-cli
codex
> Read AGENTS.md, BUILD.md, and PLAN.md before making changes.
```

The Claude Code docs remain the canonical architecture source for this repo. Codex uses the same repo instructions and workspace defaults, not a separate fork of the workflow.
