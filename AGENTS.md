# AGENTS.md

Repo-specific instructions for Codex CLI and other agents working in this project.

## Scope

- Read `README.md`, `PLAN.md`, `BUILD.md`, and `CODEX.md`, plus the relevant files under `.codex/agents/` and `skills/` before editing.
- This repo is a lean agent-architecture repo, not an app shell. Keep changes small and purpose-built.
- Prefer editing existing files over creating new ones unless the task clearly needs a new file.
- Work on a feature branch. Keep one logical change per commit.

## Operating rules

- Author here first, then review, then deploy only when the task explicitly asks for deployment (`scripts/install-codex-local.sh --apply`).
- Codex is the canonical agent surface: `.codex/agents/*.toml` are the agents, `skills/*/SKILL.md` is the shared workflow source, and `.agents/skills/*` are the discovery symlinks.
- Claude Code and Cursor are retired. Do not add new Claude/Cursor surfaces; the Claude-era phases in `BUILD.md` and the removed files in git history are history only.
- Do not edit governance or mirror files outside this repo (`~/AGENTS.md`, `~/.claude/*`, `~/.cursor/*`, Codex/OpenCode mirrors).
- Avoid unbounded loops. Every loop needs a concrete evaluation gate or a hard cap.
- Keep docs accurate and concise. If a rule changes, update the source of truth rather than duplicating it elsewhere.

## Codex workflow rules

- `.codex/config.toml` carries repo-local defaults (sandbox, approvals, and a thread cap of three).
- Delegate explicitly. Never exceed three concurrently spawned threads.
- Parallel read work is safe. Parallel writes require worktree isolation or disjoint files; otherwise serialize.
- Closed-loop builds use the `reviewer` agent for the review leg. The five-iteration cap still applies.
- Discover repo-defined test/lint/typecheck commands before any generic command. Never use `npx --yes` or silently download gate tooling.
- Every loop needs an eval gate, a turn/budget cap, or an explicit stop condition.
- If a task crosses into runtime mirrors or governance files under the home directory, stop and surface it as out of scope.
