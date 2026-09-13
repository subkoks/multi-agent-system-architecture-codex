# Codex-native authoring and installation

How this repo maps into Codex CLI, the IDE extension, and the ChatGPT desktop app.

**Status:** Codex-native rebuild (`feat/codex-native-rebuild`). Codex is the canonical runtime. Claude Code and Cursor were retired on 2026-09-13; their files live only in git history and `BUILD.md` Phases 1–E.

## Canonical files vs adapters

| Asset | Canonical source | Codex surface |
|---|---|---|
| Agents | `.codex/agents/*.toml` (canonical: planner, governor, builder, reviewer) | installed copies in `~/.codex/agents/` |
| Skills | `skills/*/SKILL.md` | `.agents/skills/*` discovery symlinks (orchestrate, closed-loop, loop) |
| Policy | `AGENTS.md` | `.codex/config.toml` (sandbox, approvals, thread cap) |

Edit the TOML agents directly — they are the source of truth now.

## Agents

| Agent | Sandbox | Role |
|---|---|---|
| planner | read-only | 3–7 phase plans; never edits |
| governor | workspace-write | auditor; writes ONLY `UPGRADE-PROPOSALS.md` |
| builder | workspace-write | scoped implementer (1–5 files); max 3 gate retries |
| reviewer | read-only | closed-loop review leg; PASS = no Critical/Major |

Models are inherited from the parent session — no role-specific pins (locked decision).

## Skills

Repo-root `.agents/skills/*` symlinks make the three workflow skills discoverable from any CWD in this repo. Progressive disclosure applies: the full `SKILL.md` loads only when the skill is selected.

## Thread cap

`.codex/config.toml` sets `agents.max_concurrent_threads_per_session = 3`.

## Usage

```bash
cd ~/Projects/multi-agent-system-architecture-codex
codex
> spawn planner to plan …          # custom agents via .codex/agents/*.toml
> use reviewer to gate the diff    # closed-loop review leg
> $orchestrate …                   # repo skills via $ or /skills
```

The IDE extension and the desktop app pick up the same project config, agents, and skills when this repo folder is open. This is a documentation-only repo — there is no app to bootstrap, so opening the repo in Codex is the whole setup.

## Local installation (approval required)

```bash
scripts/install-codex-local.sh            # dry-run (default)
scripts/install-codex-local.sh --apply    # install to ~/.codex + ~/.agents
scripts/smoke-test-codex.sh --live        # verify the install
```

The installer copies the four agents to `~/.codex/agents/` and repoints the three managed skill symlinks under `~/.codex/skills/` and `~/.agents/skills/` at this repo. Dry-run by default; every change is recorded in a rollback manifest (`--rollback <manifest>`).

## Drift and rollback

- Codex adapters can drift from the canonical agents; CI contract greps guard the key rules.
- Claude/Cursor are retired — there is nothing to resync, and no legacy deploy script remains.
- Rollback: restore from the installer manifest and revert the feature branch. Desktop app, VS Code extension, CLI profiles, and global config are never touched.
