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
~/.agents/scripts/integrate-cursor-from-claude.sh
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
~/.agents/scripts/integrate-cursor-from-claude.sh   # after Claude changes
~/.claude/skills/scripts/sync-skills.sh             # if skills tree moved
~/.agents/scripts/sync-check.sh                     # drift check
cursor-project-bootstrap <repo>                     # per-project AGENTS.md + overrides
```
