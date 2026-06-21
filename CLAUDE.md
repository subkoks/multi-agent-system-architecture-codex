# Project: multi-agent-system-architecture-claude-cli

Builds a lean, native-first multi-agent + loop layer for the BLACK.TERMINAL Claude Code setup. Authoritative plan: `PLAN.md`. Build steps: `BUILD.md`. Facts/sources: `reference/research-notes.md`.

## Working agreement (auto mode)
- This project runs in **acceptEdits** mode: file authoring is autonomous; non-allowlisted Bash still gates. Work without asking for safe, reversible steps.
- Build on a **feature branch**, never `main`. One logical change per commit.
- **Author here → review → deploy.** Agent/skill files are written in `agents/` and `skills/` first, then deployed to `~/.claude/...` only at the explicit deploy step of a phase. Never auto-deploy into `~/.claude/`.

## Guardrails (Hard Stop — mechanically enforced by .claude/settings.json)
- Never edit governance/mirror files: `~/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, Codex/OpenCode mirrors. Propose changes; the human applies them. (A PreToolUse hook blocks these.)
- No unbounded loops — every loop needs an eval gate or a budget/turn cap.
- GOVERNOR proposes upgrades to `UPGRADE-PROPOSALS.md` (gitignored); it never applies them.

## Design rules (from PLAN.md)
- Native-first: the main session is the orchestrator (NEXUS persona); subagents are specialists; `Workflow` is the fan-out engine; `/loop` + `/schedule` are the loop primitives. **Do not build a parallel framework or a per-project file zoo.**
- Reuse the 12 existing subagents + 42 skills + BSELA. Net-new is only PLANNER, GOVERNOR, `/orchestrate`, `/closed-loop` (BUILDER optional).
- Keep the roster small: add an agent only when it reduces friction more than it adds maintenance.

## Resume
`Read BUILD.md and start the next unchecked phase.` Build begins at Phase 1.
