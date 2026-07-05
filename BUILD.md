# BUILD — resume map

Next session: read this top-to-bottom, then execute Phase 1. Author every file **here** (in this repo) first; deploy to `~/.claude/...` only at the explicit deploy step of each phase. Work on a feature branch, not `main`.

Legend: `[ ]` todo · `[~]` in progress · `[x]` done.

---

## Pre-flight (every session)
- [x] `cd ~/Projects/multi-agent-system-architecture-claude-cli` and confirm on a feature branch.
- [x] Re-read `PLAN.md` §3–§7 (architecture, roster, loops, anti-patterns).
- [x] Verify nothing in `~/.claude/` was changed since last session (`ls -la ~/.claude/agents ~/.claude/skills`).

---

## Phase 1 — Planner + orchestration convention (½ day)

### 1a. `agents/planner.md` ✅ authored (2026-06-21, branch phase-1-planner-orchestrate)
- **Frontmatter:** `name: planner`, `description:` (trigger on "plan", "design", ">5 files", "architecture", "before a refactor"), `tools: Read, Grep, Glob, WebFetch, WebSearch` (read-only — planners don't edit), `model: opus`.
- **System prompt must encode:** my AGENTS.md operating principles (lean files, solve-exactly-asked, named constants, early returns); Solana-first + security-gated defaults; output = 3–7 phase plan with trade-offs, risks, file list, acceptance criteria; pulls official standards via WebFetch when the domain warrants; defers to `claude-api` skill before any LLM/Anthropic claim.
- **Reuse, don't duplicate:** wrap the existing `planner-engineer` skill's discipline; add personalization the skill lacks.
- **Acceptance:** on a real feature request it returns a phased plan in my idioms without re-asking my stack; makes no edits.

### 1b. `skills/orchestrate/SKILL.md` ✅ authored (2026-06-21, branch phase-1-planner-orchestrate)
- Codifies the delegation pattern: classify task → pick loop type (open/closed/dynamic/Workflow) → delegate to specialists → enforce eval gate → report. References `bsela_route` for model-tiering.
- **Acceptance:** invoking `/orchestrate <task>` produces a delegation plan naming which existing subagents/loops to use.

### 1c. NEXUS persona (CLAUDE.md) ✅ draft authored → `reference/nexus-persona.md` (2026-06-21)
- Draft a short "NEXUS — orchestrator persona" block (how the main session plans/routes/keeps loops moving + when to delegate vs. do-inline). Save the **draft** to `reference/nexus-persona.md`. **Do NOT edit `~/.claude/CLAUDE.md` or `~/AGENTS.md` yet** — that's a governance file; present the draft for approval first.

### Phase 1 deploy (after review)
- [x] Copy `agents/planner.md` → `~/.claude/agents/planner.md` (2026-06-21).
- [x] Copy `skills/orchestrate/` → `~/.claude/skills/orchestrate/` (2026-06-21).
- [x] Paste NEXUS block into `~/.claude/CLAUDE.md` (2026-06-21 — applied manually by owner).

---

## Phase 2 — Closed-loop eval gate (1 day)

### 2a. `skills/closed-loop/SKILL.md` ✅ authored + deployed (2026-06-21, branch phase-2-closed-loop)
- One reusable definition of "done": tests pass + reviewer finds nothing critical + type-check clean + lint clean. Loop: `implement → verify → gate → (fail ? loop back : ship)`. Hard budget/turn cap. Per-language gate commands (TS: vitest+tsc, Python: pytest+ruff, Rust: cargo test).
- **Acceptance:** on a deliberately-broken change it loops until the gate passes or budget hits; never reports "done" with a failing gate.

### 2b. Sample review Workflow ✅ authored (2026-06-21, branch phase-2-closed-loop)
- A `Workflow` script that fans review across dimensions (correctness/security/perf) → adversarially verifies each finding → returns confirmed-only. Store as `reference/review-workflow.example.js`.
- **Acceptance:** runs end-to-end on a sample diff; output is severity-ranked, deduped.

### Phase 2 deploy (after review)
- [x] Deploy `skills/closed-loop/` → `~/.claude/skills/closed-loop/` (2026-06-21).

---

## Phase 3 — Governor on BSELA (1–2 days)

### 3a. `agents/governor.md` ✅ authored + deployed (2026-06-21, branch phase-3-governor)
- **Frontmatter:** `name: governor`, `description:` (system audit / "what should improve" / drift check), `tools: Read, Grep, Glob, Bash, WebFetch, WebSearch` + BSELA MCP tools (`bsela_audit`, `bsela_lessons`, `bsela_errors`, `bsela_status`), `model: opus`.
- **Job:** read BSELA lessons + recurring error categories + `bsela_audit`; WebFetch Anthropic/Claude Code changelog & docs (flag new features like `/loop` was); detect config drift vs `~/.claude/settings.json` + agent/skill prompt quality (delegate prompt fixes to `prompt-systems-lead`); **write dated proposals only** to `UPGRADE-PROPOSALS.md`. **Never edits governance files.**
- **Acceptance:** dry-run produces a dated proposals file with concrete, sourced, prioritized items; zero writes outside the proposals file.

### 3b. Weekly `/schedule` routine ⚠ DESCOPED (2026-06-21)
- Cloud CCR can't reach local BSELA MCP or local files — the routine would only cover ~25% of GOVERNOR's job (docs WebFetch only).
- **Decision:** GOVERNOR is on-demand. Invoke with "run governor" before big changes or periodically. No cron registered.
- If BSELA ever gets a cloud MCP connector, revisit this step.

### Phase 3 deploy (after review)
- [x] Deploy `agents/governor.md` → `~/.claude/agents/governor.md` (2026-06-21).
- [x] Schedule descoped — on-demand invocation is the correct primitive given local MCP constraint.

---

## Phase 4 — Optional (½ day)
- [x] `agents/builder.md` — scoped implementer for worktree-isolated parallel work (`tools: Read, Edit, Write, Bash, Grep, Glob`, `model: sonnet`, **forbidden** from editing governance files). Deployed 2026-06-21.
- [x] `bsela_route` model-tiering wired as default Step 3 in `/orchestrate` skill — call before picking model for any delegated subtask. `builder` added to specialist table. Deployed 2026-06-21.

---

## Phase C — Cursor integration (1 day)

### C1. Agent sync quality ✅ (2026-07-05)
- **Fix:** `integrate-cursor-from-claude.sh` folds YAML `description: >` into single-line Cursor frontmatter.
- **Acceptance:** `~/.cursor/agents/planner/agent.md` shows full description in agent picker.

### C2. BSELA MCP parity ✅ (2026-07-05)
- **Fix:** `integrate-cursor-from-claude.sh` merges `memory` + `bsela` into `~/.cursor/mcp.json` (non-destructive).
- **Acceptance:** `bsela_status` and `bsela_route` callable from Cursor after restart.

### C3. Cursor-native orchestration ✅ (2026-07-05)
- **`skills/orchestrate/SKILL.md`:** Cursor notes section (Workflow → Task parallel, /schedule → /loop or automate).
- **`cursor-nexus.mdc`:** recurring row uses automate skill; loop rules drop cloud `/schedule`.
- **Acceptance:** `/orchestrate` in Cursor produces Task-parallel plans, not Workflow-only plans.

### C4. Docs + deploy script ✅ (2026-07-05)
- **`CURSOR.md`:** deploy ritual, primitive mapping, usage table.
- **`scripts/deploy-to-claude-and-cursor.sh`:** one-command repo → Claude → Cursor sync.
- **`README.md`:** status updated (Claude complete, Cursor integrated).
- **Acceptance:** `scripts/deploy-to-claude-and-cursor.sh --dry-run` lists all copy + integrate steps.

### Phase C deploy (after review)
- [x] Run `scripts/deploy-to-claude-and-cursor.sh` (2026-07-05).
- [x] Restart Cursor to load MCP changes.

---

## Guardrails (apply to all phases)
- Governance files (`~/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.claude/settings.json`) change **only** via reviewed proposal — Hard Stop.
- No unbounded loops: every loop has an eval gate or a budget/turn cap.
- Author-here → review → deploy. Never auto-deploy into `~/.claude/`.
- Keep the roster small. New agent only if it reduces friction more than it adds maintenance.
