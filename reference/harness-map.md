# Harness map — Codex canonical

This repo is the **authoring root** for the BLACK.TERMINAL multi-agent + loop layer. Codex is the canonical runtime; other harnesses consume the same ideas and get no parallel agent tree.

| Surface | Status | Where it lives | Orchestrator | Fan-out | Loops | Deploy path |
|---|---|---|---|---|---|---|
| **Codex** (canonical) | active | repo `.codex/agents`, `.codex/config.toml`; `~/.codex/*` after install | main session + `AGENTS.md` | subagent workflows (cap 3 threads) | `$loop` skill + monitored shell | `scripts/install-codex-local.sh --apply` (approval) |
| **Grok Build** | active (secondary) | `~/.agents/skills` (orchestrate, closed-loop, loop, …) | main session | subagents / Task | `$loop` skill + monitor | skill install; no separate agent zoo |
| Claude Code | retired 2026-09-13 | git history + `BUILD.md` Phases 1–E | — | — | — | removed |
| Cursor | retired 2026-09-13 | git history + `BUILD.md` Phase C | — | — | — | removed |

## Shared rules (all active harnesses)

- Native-first: main session orchestrates; specialists are narrow.
- Closed build work → eval gate (tests + review + types + lint).
- No unbounded loops without a turn/budget cap.
- Governance files (`~/AGENTS.md`, `~/.claude/*`, `~/.cursor/*`, Codex/OpenCode mirrors) are Hard Stop — propose only.
- Author in this repo → review → deploy. Never silent overwrite of live config.

## When to add a harness-specific file

Only when a primitive is genuinely different. Prefer one paragraph in this map over a new skill fork.
