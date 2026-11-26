# Codex configuration and operations

Codex CLI, the IDE extension and the desktop app use the repository's native agent and skill layout. Open a trusted checkout to adopt the project settings. Use the [optional personal installer](#local-installation-approval-required) to make the roles available elsewhere.

## Canonical files and discovery

| Surface | Repository source | Purpose |
| --- | --- | --- |
| Project configuration | [`.codex/config.toml`](.codex/config.toml) | Permissions, approvals, search mode and child-thread cap |
| Custom agents | [`.codex/agents/`](.codex/agents/) | Six specialist role definitions |
| Skills | [`skills/`](skills/) · [`.agents/skills/`](.agents/skills/) | Workflow sources and project discovery links |
| Local verification | [`scripts/`](scripts/) | Offline contract checks, isolated CLI startup probe and personal install checks |

The main session delegates directly, serializes dependent work and assigns disjoint files or worktrees to parallel writers. Three open child threads is the maximum. Children return their evidence to the main session.

## Agent scopes and permissions

| Role | Assigned scope |
| --- | --- |
| `planner` | Read the project and return a phased plan. |
| `builder` | Write only the files named in the assignment and run the specified checks. |
| `reviewer` | Review the current diff and report a verdict and verification gaps. |
| `docs-researcher` | Use existing docs and web tools for public, cited research. |
| `repo-operator` | Read GitHub evidence for the specified repository and refs. |
| `governor` | Audit the system and return proposals, or append to `UPGRADE-PROPOSALS.md` when allowed to write. |

The project requests workspace permissions and human review for approvals. It uses non-login shells by default. Supply toolchain paths in the launch environment when your tools normally depend on login-shell startup.

Agent instructions define the assigned scope. Effective sandboxing and approvals follow the parent turn, including explicit launch and live changes. Use the parent's permission controls before delegation if the task requires enforced read-only access. Narrow role instructions and feature flags reduce scope but cannot guarantee that every inherited tool is disabled. The researcher disables shell use. Planner, reviewer, researcher and operator opt out of memories, permission-request tooling and automatic skill instructions. [Permissions](https://learn.chatgpt.com/docs/permissions) · [Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)

## Models, tools and usage

The repository leaves model, provider, reasoning effort and speed tier to the selected session. Keep the same provider throughout delegated work. Check the model picker or provider catalog before requesting an override. A user profile or explicit request can supply a different child model or effort.

| Task | Starting choice when supported |
| --- | --- |
| Routine implementation and review | GPT-6.2 Sol at medium reasoning, inherited by default |
| Narrow evidence collection | GPT-6 Luna at high reasoning, explicitly selected for a scoped scan |
| Architecture and high-risk review | GPT-6.2 Astra at high reasoning when the extra depth is warranted |

Use standard speed for routine work. Prefer one targeted child over a broad fan-out and give it exact paths, questions and output limits. Keep expensive review focused on decisions the cheaper evidence pass could leave unresolved. Evaluate model changes with the same task, commit, gates and speed tier. Compare elapsed time, available token or credit usage, and rework required to reach the gate. Record unavailable usage explicitly. With non-interactive JSON output, check which turns and child usage are included before comparing totals. [OpenAI models](https://learn.chatgpt.com/docs/models) · [Codex pricing](https://learn.chatgpt.com/docs/pricing)

Cached web search is the project default. Use `codex --search` on a research session that needs current sources. For OpenAI-specific research, use the OpenAI Developers plugin's documentation workflow when available, or configure the public, read-only Docs MCP for a single CLI launch:

```bash
codex --search -c 'mcp_servers.openaiDeveloperDocs={url="https://developers.openai.com/mcp"}'
```

Use official pages directly when the MCP is unavailable. Keep private repository details out of public queries. A BSELA integration is optional. Route on repository evidence unless the task explicitly authorizes the relevant BSELA data and an appropriate tool is available. Use authorized, sanitized evidence for routing or proposals. [OpenAI Docs MCP](https://developers.openai.com/learn/docs-mcp)

## Maintenance

Run `scripts/codex-health.sh --repo` for the offline repository smoke check and `python3 scripts/check-codex-config.py` with a current Codex CLI to verify native project configuration loading. CI runs the offline contract and regression checks. The isolated startup probe loads only the project configuration and does not start an agent or test roles on a live provider.

`scripts/codex-health.sh --local` checks the current CLI environment with Codex Doctor, strict base startup configuration and plugin and MCP inventories. It lists available profile filenames. Doctor may perform its own redacted provider diagnostics. Running the command with no scope runs both repository and local checks.

After a CLI upgrade, use the governor to check current official docs, role availability and drift. A live verification of a new role should use a fresh session, a single harmless task and the parent's intended permissions. Record which roles, tools and client surfaces were exercised and any gaps in that evidence.

## Local installation (approval required)

```bash
scripts/install-codex-local.sh --agents-only          # preview the six copies
scripts/install-codex-local.sh --agents-only --apply  # install after approval
scripts/smoke-test-codex.sh --live --agents-only      # compare installed agent files
```

Use `--agents-only` when `~/.agents/skills/` contains canonical personal skill directories. The full installer also manages the three skill links under `~/.codex/skills/` and `~/.agents/skills/`. It refuses directory collisions for skill links and checks the selected sources and destinations before writing. The installer applies to the documented paths under your home directory.

Every apply records a manifest under `~/.codex/install-manifests/`. Backups live under `~/.agents/backups/`. If restoring, use the genuine manifest for the latest install and inspect any intervening changes to the managed paths first. Rollback validates the complete manifest before restoring its recorded files and links. Older manifests with the original backup layout are supported.

```bash
scripts/install-codex-local.sh --rollback /absolute/path/to/install-TIMESTAMP-PID.manifest
```
