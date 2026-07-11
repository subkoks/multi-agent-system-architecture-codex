# Research notes — loops, subagents, orchestration (2026-06-21)

Captured so next session doesn't re-research. Source links at bottom.

## The agent loop (official)
Cycle: receive prompt → evaluate/respond → execute tools → repeat (one "turn" = one round trip with tool calls) → return result when a turn has no tool calls.
- Caps: `max_turns` (tool-use turns only), `max_budget_usd`. Hitting them → `error_max_turns` / `error_max_budget_usd`.
- `effort`: low / medium / high / xhigh / max. xhigh recommended on Opus 4.7+/Fable 5. (Live default here as of 2026-07-09: **claude-fable-5** + **effort high**; scale with cc-profile for routine work.)
- Permission modes: default / acceptEdits / plan / dontAsk / auto (TS) / bypassPermissions.
- Context accumulates across turns; auto-compaction summarizes old history (`compact_boundary`). Persistent rules belong in CLAUDE.md (re-injected every request), not the first prompt.
- Subagents = fresh context, own system prompt, scoped tools, own model; only their final summary returns to parent (context-saving).

## `/loop` (native, ~March 2026)
- Schedules a recurring prompt **inside the live session** — same context/tools/MCP, remembers prior iterations.
- Natural language ("every 5 min, check the build") or `--interval` / `--expires`.
- Session-scoped: ends when the session ends (safety).
- No-interval = dynamic/self-paced mode ("run until done").
- Use for: status polling, "keep going until work is done," recurring light checks.

## `/schedule` vs `/loop`
- `/loop` = in-session, dies with session, in-memory cron + dynamic self-pacing.
- `/schedule` = cloud routines on cron, **survive session end**. Right tool for GOVERNOR's weekly patrol.

## Workflow tool (enabled here)
- Deterministic JS orchestration: `agent()`, `parallel()` (barrier), `pipeline()` (no barrier — default), `phase()`, `log()`, `budget`.
- Patterns: adversarial verify, judge panel, loop-until-dry, multi-modal sweep, completeness critic.
- `isolation: 'worktree'` for parallel file-mutating agents.
- This is the real "fleet loop" engine — prefer over hand-rolled coordination.

## Loop infographic distilled (@shannholmberg)
- Single-agent loop: Discovery → Planning → Execution → Verification → Iteration → **Eval Gate** (meets standard? no → back to Discovery; yes → ship).
- Fleet loop: Orchestrator owns the goal → Specialists own steps → Subagents do narrow work → eval gate prevents slop.
- Open looping = exploratory, model picks path, unbounded, breakthrough ideas, burns tokens.
- Closed looping = bounded, defined steps, eval each step, internal budget — "the one that pays off today."
- Core lesson: **Loop = eval + leverage. No eval = slop.** Let the system get better while you sleep.

## Subagents (official)
- `.claude/agents/*.md` with frontmatter: `name`, `description` (drives delegation), `tools` (scoped), `model` (route cheap → Haiku/Sonnet).
- Main agent delegates by matching `description`. Subagents work in single session.
- Background agents (agent-view) = many parallel independent sessions, monitored from one place.
- Agent teams = sessions that communicate with each other.
- Best practice: specialization > generalization; structured I/O schemas; explicit caps ("use at most N agents"); context is the scarce resource.

## Community references (mine for patterns, don't copy wholesale)
- VoltAgent/awesome-claude-code-subagents (100+ subagents)
- wshobson/agents (multi-harness plugin marketplace)
- hesreallyhim/awesome-claude-code (orchestrators, hooks, statuslines)
- rshah515/claude-code-subagents (project-manager / tech-lead / incident-commander roles)
- Orchestrators: tutti, amux, agent-orchestrator, claude-flow. Technique: "Ralph Wiggum" loop.

## Existing setup snapshot

### 2026-06-21 (initial)
- BSELA: 976 sessions, 1,022 errors, 44 lessons, 61 replay records. Tools: bsela_audit, bsela_route, bsela_lessons, bsela_errors, bsela_status, bsela_sessions.
- 12 subagents, 42 skills, hooks (format/log/Stop→BSELA/test-filter), Workflow on, opus+xhigh.

### 2026-07-09 (Phase E audit)
- BSELA: **1,198** sessions (67 quarantined), **1,497** errors, **45** lessons (0 pending/proposed), 61 replay records.
- `bsela_audit` 30d: alerts `[]`, lesson drift 0.0, ADRs 11 OK, quarantine_rate ~13%.
- Main model: `claude-fable-5` + `effortLevel: high`; `enableWorkflows: true`; `minimumVersion: "2.1.183"` (installed CC **2.1.205** — floor bump is a proposal only).
- Architecture repo: Phases 1–4 + Cursor Phase C + Phase D + loop skill; smoke-test green.
- GitHub: private free — branch protection/rulesets not available; squash + delete_branch_on_merge already on.

## Sources
- https://code.claude.com/docs/en/agent-sdk/agent-loop
- https://code.claude.com/docs/en/sub-agents
- https://www.mindstudio.ai/blog/what-is-claude-code-loop-command-recurring-tasks
- https://www.marktechpost.com/2026/06/14/claude-code-guide-2026-25-features-with-examples-demo/
- https://shipyard.build/blog/claude-code-multi-agent/
- https://addyosmani.com/blog/code-agent-orchestra/
- https://github.com/hesreallyhim/awesome-claude-code
- https://github.com/wshobson/agents
- https://github.com/VoltAgent/awesome-claude-code-subagents
