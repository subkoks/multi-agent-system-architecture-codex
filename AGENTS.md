# AGENTS.md

Repo-specific instructions for Codex CLI and other agents working in this project.

## Scope

- Read `README.md`, `PLAN.md`, `BUILD.md`, and the relevant files under `agents/`, `skills/`, and `reference/` before editing.
- This repo is a lean agent-architecture repo, not an app shell. Keep changes small and purpose-built.
- Prefer editing existing files over creating new ones unless the task clearly needs a new file.
- Work on a feature branch. Keep one logical change per commit.

## Operating rules

- Author here first, then review, then deploy only when the task explicitly asks for deployment.
- Keep the native-first architecture intact. Reuse the existing planner, governor, orchestrate, and closed-loop conventions instead of inventing parallel ones.
- Do not edit governance or mirror files outside this repo.
- Avoid unbounded loops. Every loop needs a concrete evaluation gate or a hard cap.
- Keep docs accurate and concise. If a rule changes, update the source of truth rather than duplicating it elsewhere.

## Codex CLI notes

- Codex CLI should treat this file as the primary repo guidance.
- `.codex/config.toml` can carry repo-local Codex defaults for this workspace.
- If a task crosses into runtime mirrors or governance files under the home directory, stop and surface it as out of scope.
