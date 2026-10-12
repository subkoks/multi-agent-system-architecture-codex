# Codex-native authoring and installation

How this repo maps into Codex CLI, the IDE extension, and the ChatGPT desktop app.

**Status:** Codex-native rebuild (`feat/codex-native-rebuild`). Codex is the canonical runtime. Claude Code and Cursor were retired on 2026-09-13; their files live only in git history and `BUILD.md` Phases 1–E.

## Canonical files vs adapters

| Asset | Canonical source | Codex surface |
|---|---|---|
| Agents | `.codex/agents/*.toml` (canonical: planner, governor, builder, reviewer) | installed copies in `~/.codex/agents/` |
| Skills | `skills/*/SKILL.md` | `.agents/skills/*` discovery symlinks (orchestrate, closed-loop, loop) |
| Policy | `AGENTS.md` | `.codex/config.toml` (permission profile, approvals, thread cap) |

Edit the TOML agents directly — they are the source of truth now.

## Agents

| Agent | Permission default | Role |
|---|---|---|
| planner | `:read-only` | 3–7 phase plans; never edits |
| governor | `:workspace` | one audit pass; writes ONLY `UPGRADE-PROPOSALS.md` |
| builder | `:workspace` | scoped implementer (1–5 files); max 3 gate retries |
| reviewer | `:read-only` | one review pass; PASS = no Critical/Major |

Model, provider, and reasoning effort are inherited from the parent session — no role-specific or project model pins (locked decision). Choose a current model in the user profile or launch command; do not copy old model IDs from the historical PLAN/BUILD sections. Verified on 2026-10-11 with CLI 0.162.1: the installed OpenAI catalog includes `gpt-6.1-sol` and `gpt-6-astra`; the user's normal default is Sol/medium, with Astra/high selected via `codex -p astra`. Availability is provider/account-specific; inheritance also preserves an explicitly selected alternative provider.

The governor checks current official documentation and the installed provider catalog before recommending model changes. BSELA/private-data access requires its own task authorization; unavailable evidence is reported explicitly.

## Permissions

The project explicitly selects `default_permissions = ":workspace"`, `approval_policy = "on-request"`, and `approvals_reviewer = "user"`. This prevents an ordinary launch from inheriting the user's global Full Access/automatic-review defaults. Built-in workspace permissions protect `.git` and `.codex`; necessary writes there may require approval. No machine-specific custom permission profile is required.

Agents use `default_permissions` rather than legacy `sandbox_mode`, because the two permission systems do not compose. Agent roles and output-file limits are behavioral instructions, not filesystem allowlists. Explicit CLI and live parent permission overrides can take precedence when spawning agents; inspect `/status` and `/permissions` in a fresh session rather than treating an agent file as a security boundary. See [permission profiles](https://learn.chatgpt.com/docs/permissions) and [subagent inheritance](https://learn.chatgpt.com/docs/agent-configuration/subagents).

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
scripts/install-codex-local.sh --agents-only # preview agents, preserve personal skills
scripts/install-codex-local.sh --agents-only --apply # install four agents only
scripts/smoke-test-codex.sh --live --agents-only # verify installed agents
```

Use `--agents-only` when `~/.agents/skills/` contains your canonical personal skill directories and `~/.codex/skills/` mirrors them. It copies only the four agents to `~/.codex/agents/`; every personal skill path stays untouched. Repository skills remain available when this repository is open.

Without `--agents-only`, the full installer also repoints the three managed skill symlinks under `~/.codex/skills/` and `~/.agents/skills/` at this repo. Existing skill directories are refused; the full installer does not replace a canonical personal library. It checks all selected sources and collisions before making changes. Run `scripts/smoke-test-codex.sh --live` to verify a full installation.

Dry-run is the default and writes nothing. `--apply` requires explicit approval. Every applied file/link change is recorded in a rollback manifest under `~/.codex/install-manifests/`, with original agent files backed up under `~/.agents/backups/codex-native-install-<timestamp>/`. Use `scripts/install-codex-local.sh --rollback <manifest>` to restore the prior files and links. Existing manifests with older backup locations remain usable. Rollback leaves manifest/backup records and any created parent directories in place.

## Drift and rollback

- Codex adapters can drift from the canonical agents; CI contract greps guard the key rules.
- Claude/Cursor are retired — there is nothing to resync, and no legacy deploy script remains.
- Rollback: restore from the installer manifest and revert the feature branch. Desktop app, VS Code extension, CLI profiles, and global config are never touched.
