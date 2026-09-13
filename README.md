# multi-agent-system-architecture-claude-cli

Lean, native-first multi-agent + loop architecture for the BLACK.TERMINAL Claude Code setup.

**Status:** ✅ Claude build complete (2026-06-21, BUILD.md Phases 1–4). ✅ Cursor integrated (~90%) via `integrate-cursor-from-claude.sh` — see [CURSOR.md](./CURSOR.md). ✅ Phase D operational hardening (2026-07-05): smoke test + OpenCode→BSELA hook. ✅ Loop skill in-repo (2026-07-09). ✅ **Phase E** complete (2026-07-11). ✅ **Codex-native rebuild** (2026-09-13): native agents, skill discovery, installer — see [CODEX.md](./CODEX.md).

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
├── BUILD.md       ← phased resume map + Phase E upgrades
├── AGENTS.md      ← repo guidance for Codex / multi-harness agents
├── CODEX.md       ← Codex-native agents, skill discovery, installer
├── agents/        ← planner.md, governor.md, builder.md
├── skills/        ← orchestrate/, closed-loop/, loop/
├── scripts/       ← deploy, integrate-cursor, smoke-test
├── .codex/        ← config.toml + native agent adapters (planner, governor, builder, reviewer)
├── .agents/       ← skills/ discovery symlinks into skills/
├── reference/     ← research-notes, nexus-persona, review-workflow, harness-map
└── .github/       ← validate workflow (paths, frontmatter, shellcheck)
```

## How to resume

**Claude Code:**
```
cd ~/Projects/multi-agent-system-architecture-claude-cli
claude
> Read BUILD.md. Phases 1–4 + C + D complete. Execute Phase E or run governor.
```

**Cursor:** see [CURSOR.md](./CURSOR.md).

Build is phased and reversible. Each agent/skill is authored **here** first, reviewed, then deployed to `~/.claude/...` and synced to `~/.cursor/...` via the integrate script — deployment is deliberate, not automatic.

## Codex CLI

This repo is Codex-native: `AGENTS.md` carries project guidance, `.codex/agents/*.toml` provides four native agent adapters (planner, governor, builder, reviewer), `.agents/skills/*` makes the three workflow skills discoverable, and `.codex/config.toml` caps spawned threads at three. See [CODEX.md](./CODEX.md).

Recommended entrypoint:

```
cd ~/Projects/multi-agent-system-architecture-claude-cli
codex
> Read AGENTS.md, BUILD.md, and PLAN.md before making changes.
```

The Claude Code docs remain the canonical architecture source for this repo. Codex uses the same repo instructions and workspace defaults plus thin adapters — not a separate fork of the workflow.

## Multi-harness

Same architecture, multiple surfaces (Claude Code · Cursor · Codex · Grok): see [reference/harness-map.md](./reference/harness-map.md).

## Governor cadence

GOVERNOR stays **on-demand** (cloud cron cannot reach local BSELA). Habit: before big changes or after a Claude Code upgrade, run governor → review `UPGRADE-PROPOSALS.md` → apply only approved items → `scripts/smoke-test.sh` after deploy.

**Doc-watch (primary):** [Claude Code changelog](https://docs.claude.com/en/docs/claude-code/changelog) — prefer this over `claude.ai/changelog` (often Cloudflare-blocked). Optional: Anthropic news posts for features like dynamic workflows / auto mode.
