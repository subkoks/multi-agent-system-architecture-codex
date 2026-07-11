# Harness map — same architecture, multiple surfaces

This repo is the **authoring root** for the BLACK.TERMINAL multi-agent + loop layer. Claude Code remains the canonical runtime. Other harnesses **consume** the same ideas; they do not get a parallel agent tree.

| Surface | Where it lives | Orchestrator | Fan-out | Loops | Deploy path |
|---|---|---|---|---|---|
| **Claude Code** (canonical) | `~/.claude/agents`, `~/.claude/skills` | NEXUS persona in CLAUDE.md | `Workflow` tool | `/loop`, `/schedule` (cloud) | `scripts/deploy-to-claude-and-cursor.sh` |
| **Cursor** | `~/.cursor/agents`, skills symlink | `cursor-nexus.mdc` | Task parallel subagents | `/loop` / automate | integrate script (after deploy) |
| **Codex CLI** | repo `AGENTS.md` + `.codex/config.toml` | session + AGENTS.md | agent tools per Codex | session discipline | no auto-deploy; read repo |
| **Grok Build** | `~/.agents/skills` (orchestrate, closed-loop, loop, …) | main session | subagents / Task | `/loop` skill + monitor | skill install; no separate agent zoo |

## Shared rules (all harnesses)

- Native-first: main session orchestrates; specialists are narrow.
- Closed build work → eval gate (tests + review + types + lint).
- No unbounded loops without a turn/budget cap.
- Governance files (`~/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.claude/settings.json`) are Hard Stop — propose only.
- Author in this repo → review → deploy. Never silent overwrite of live config.

## What does **not** map 1:1

| Claude Code | Other harnesses |
|---|---|
| `Workflow` JS pipelines | Cursor/Grok: parallel Task/subagents with explicit gates |
| Cloud `/schedule` | Session `/loop` interval, LaunchAgent checklist, or manual governor |
| BSELA Stop hook capture | OpenCode has a dedicated hook; other harnesses may lag — do not invent fake capture |

## When to add a harness-specific file

Only when a primitive is genuinely different (e.g. CURSOR.md). Prefer one paragraph in this map over a new skill fork.
