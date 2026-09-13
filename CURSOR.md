# Cursor integration

How this architecture repo maps into Cursor on this machine.

**Status:** Claude build complete (BUILD.md Phases 1–4). Cursor ~90% integrated via `~/.agents/scripts/integrate-cursor-from-claude.sh`.

## Primitive mapping

| Claude Code | Cursor |
|---|---|
| Main session = NEXUS | `~/.cursor/rules/cursor-nexus.mdc` (alwaysApply) |
| Subagents (`.claude/agents/`) | `~/.cursor/agents/<name>/agent.md` |
| Skills (`.claude/skills/`) | `~/.cursor/skills/` → symlinks to Claude |
| `/loop` | `skills-cursor/loop` (session-local) |
| `/schedule` (cloud cron) | No equivalent — use `/loop` interval or automate skill |
| `Workflow` tool | Task tool with parallel subagents |
| BSELA MCP | `~/.cursor/mcp.json` → `memory` + `bsela` (merged by integrate script) |

## Deploy ritual

Author here first, then sync live editors:

```bash
cd ~/Projects/multi-agent-system-architecture-claude-cli
scripts/deploy-to-claude-and-cursor.sh          # deploy + integrate
scripts/smoke-test.sh                           # verify integration health
# scripts/deploy-to-claude-and-cursor.sh --dry-run  # preview only
~/.agents/scripts/sync-check.sh
# Restart Cursor (MCP + hooks)
```

Manual copy (if you prefer):

```bash
cp agents/{planner,governor,builder}.md ~/.claude/agents/
cp -R skills/{orchestrate,closed-loop} ~/.claude/skills/
scripts/integrate-cursor-from-claude.sh   # or ~/.agents/scripts/… after first deploy
```

## Usage in Cursor

| Intent | Invoke |
|---|---|
| Plan a big change | Task → `planner` or "use planner to plan …" |
| Route a task | `/orchestrate …` |
| Build with eval gate | `/closed-loop …` |
| Research loop | `/loop …` (turn-capped) |
| Parallel work | Task tool with 2–3 subagents in one message |
| System audit | Task → `governor` ("run governor") |
| Pre-merge review | Task → `code-reviewer` |

GOVERNOR is on-demand (same as Claude — cloud cron cannot reach local BSELA).

### Governor cadence (local checklist)

Before a big change, after a CC upgrade, or weekly:

1. Task → `governor` ("run governor" / system audit)
2. Doc-watch: [Claude Code changelog](https://docs.claude.com/en/docs/claude-code/changelog) (primary; `claude.ai/changelog` often blocked)
3. Read `UPGRADE-PROPOSALS.md` (gitignored in this repo) for new open items
4. Apply only what you approve — never auto-apply governance
5. `scripts/smoke-test.sh` after any deploy

**Optional (Max/Team/Enterprise):** try Claude Code *dynamic workflows* for one large migration before inventing new agents — see Anthropic's Opus 4.8 / dynamic-workflows notes.

## Layers

| Layer | Location |
|---|---|
| Global rules | `~/AGENTS.md` |
| Orchestration | `~/.cursor/rules/cursor-nexus.mdc` |
| Subagents | `~/.cursor/agents/` |
| Skills | `~/.cursor/skills/` (symlinks → `~/.claude/skills/`) |
| Hooks | `~/.cursor/hooks.json` |
| Core MCP | `~/.cursor/mcp.json` (`memory`, `bsela`) |
| Project overrides | `.cursor/rules/project-overrides.mdc` (this repo) |

## Maintenance

```bash
~/.agents/scripts/integrate-cursor-from-claude.sh   # synced from this repo on deploy
~/.claude/skills/scripts/sync-skills.sh             # if skills tree moved
~/.agents/scripts/sync-check.sh                     # drift check
cursor-project-bootstrap <repo>                     # per-project AGENTS.md + overrides
```

## Codex coexistence

This repo also carries Codex-native adapters (`.codex/agents/*.toml`) and skill discovery symlinks (`.agents/skills/*`) — see `CODEX.md`. They do not affect Cursor; Cursor keeps consuming the Claude deploy path above.
