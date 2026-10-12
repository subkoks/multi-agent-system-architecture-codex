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

## Phase D — Operational hardening (optional, ½ day)

### D1. Post-deploy smoke test ✅ (2026-07-05)
- **`scripts/smoke-test.sh`:** repo↔Claude drift, Cursor agent descriptions, MCP parity, NEXUS rule, sync-check.
- **Acceptance:** exits 0 after deploy; fails loudly on drift.

### D2. OpenCode → BSELA session ingestion ✅ (2026-07-05)
- **Scope:** `bsela hook opencode-stop` exports OpenCode SQLite → JSONL → ingest; guarded call in `~/.config/opencode/blackterminal-plugin.ts` on `session.idle`.
- **Branch:** `feat/opencode-stop-hook` in BSELA repo.
- **Acceptance:** OpenCode session idle → one row in BSELA (`source=opencode`); dedup on unchanged export hash.

### D3. Pending lesson triage ✅ (2026-07-05)
- **Scope:** Review 4 pending BSELA lessons (npm-before-tsc, path naming, placeholder syntax, large-file diff chunking). Approve/reject/externalize.
- **Acceptance:** `bsela_lessons status=pending` → 0 or documented carry-over with owner sign-off.
- **Result:** All 4 rejected — hyphens rule contradicted stack conventions; others redundant/vague vs AGENTS.md + closed-loop.

### Phase D deploy (after review)
- [x] `scripts/smoke-test.sh` authored (2026-07-05).
- [x] D2 OpenCode hook implemented in BSELA (`feat/opencode-stop-hook`); plugin wired.
- [x] D3 lesson triage complete — 0 pending.

---

## Phase E — Next-level upgrades (2026-07-09 audit)

**Trigger:** post Phase D + loop skill integration; system CLEAN (BSELA alerts `[]`, smoke green, CI green). Goal: tighten drift surfaces, multi-harness notes, CI depth — **without** a parallel framework.

### E0. Hygiene (this PR) ✅ authored 2026-07-09
- [x] Align `agents/builder.md` model pin to `claude-sonnet-5` (matches `orchestrate` + live peers; drop stale `claude-sonnet-4-6`).
- [x] Align `reference/review-workflow.example.js` model IDs to current tier map.
- [x] CI: require `skills/loop/SKILL.md`; agent frontmatter + builder model pin; shellcheck on scripts.
- [x] Docs: README layout (loop + scripts + CI); research-notes snapshot (Fable 5 + current BSELA counts); CLAUDE.md resume; `reference/harness-map.md`.
- [x] `minimumVersion` proposal only (live CC is 2.1.205; settings floor still 2.1.183) — **do not** edit `~/.claude/settings.json` from this repo; surface in UPGRADE-PROPOSALS.

**Verify:** `bash -n scripts/*.sh`; `scripts/smoke-test.sh`; CI validate green after PR.

### E1. Model-tier consistency ✅ authored 2026-07-09
- [x] Audit repo-owned agent model IDs: planner/governor `claude-opus-4-8`, builder `claude-sonnet-5`.
- [x] Live `~/.claude/agents/*` drift (bare `sonnet`, auditors on sonnet-4-6) left as **UPGRADE-PROPOSALS** only.
- [x] `skills/orchestrate` role table includes Fable main-loop row + current implementer pins.

**Verify:** `rg '^model:' agents/` clean; `scripts/eval-skill-smoke.sh`.

### E2. CI + GitHub hygiene ✅ authored 2026-07-09
- [x] Expand validate workflow: shellcheck, frontmatter, loop skill, skill contracts, SECURITY.md / harness-map.
- [x] Repo topics set via GitHub API.
- [x] Free-private protection gap documented (no fake branch protection).
- [x] Issue template `upgrade-proposal.md` + `SECURITY.md`.

**Verify:** CI validate green on PR; topics non-empty.

### E3. Multi-harness parity notes ✅ authored 2026-07-09
- [x] `reference/harness-map.md` + README section (Claude · Cursor · Codex · Grok).
- Zero new agents.

### E4. Governor local cadence ✅ docs 2026-07-09
- [x] Checklist in `CURSOR.md` + README (on-demand habit; no LaunchAgent auto-apply).
- Cloud `/schedule` remains descoped.

### E5. Eval harness for skills ✅ authored 2026-07-09
- [x] `scripts/eval-skill-smoke.sh` — contract greps for orchestrate/closed-loop/loop + agent model pins.
- [x] Wired into CI validate.

**Verify:** `scripts/eval-skill-smoke.sh` exits 0.

### Phase E deploy (after review)
- [x] Merged #10 → `scripts/deploy-to-claude-and-cursor.sh` (2026-07-11; builder + orchestrate model map).
- [x] `scripts/smoke-test.sh` green post-deploy.
- [x] Owner applied `minimumVersion` floor bump in settings.json: `2.1.183` → `2.1.205` (2026-07-11; Hard Stop approved).
- [x] Issue #9 closed; live agent model pins applied at source (2026-07-11).

### Explicitly NOT Phase E (anti-hype)
- ❌ New orchestrator agent / NEXUS daemon
- ❌ Per-project HANDOFF/PROGRESS file zoo
- ❌ Cloud GOVERNOR cron without BSELA connector
- ❌ Auto-merge bots or secret-scanning theater on free private without Pro

---

## Phase F — Codex-native rebuild (2026-09-13, `feat/codex-native-rebuild`)

**Trigger:** Codex CLI (0.154.0), the IDE extension, and the desktop app are now first-class consumers of this repo. Goal: native Codex discovery plus a reversible local installer — without replacing the Claude/Cursor architecture. Details: `CODEX.md`.

- [x] F1. **Codex-native discovery** — `.codex/agents/{planner,governor,builder,reviewer}.toml` adapters; `.agents/skills/{orchestrate,closed-loop,loop}` symlinks into `skills/`; `agents.max_concurrent_threads_per_session = 3` in `.codex/config.toml`; narrow `.gitignore` exceptions for `.codex/agents/*.toml`.
- [x] F2. **Codex-aware workflows** — Codex routing + write-isolation notes in `/orchestrate`; `reviewer` adapter leg, repo-first gate commands, no `npx --yes` in `/closed-loop`; expiry/stop rule in `/loop`; delegation + thread-cap rules in `AGENTS.md`.
- [x] F3. **Installer + validation** — `scripts/install-codex-local.sh` (dry-run default, managed allowlist, backups, rollback manifest), `scripts/smoke-test-codex.sh` (`--repo`/`--live`), CI TOML/symlink/schema checks + installer dry-run, `SECURITY.md` notes. Apply/rollback proven against a fake `HOME`.
- [x] F4. **Docs** — `CODEX.md`; README, PLAN, CLAUDE, CURSOR, harness-map reconciled.
- [ ] F5. **Historical local-install proposal — superseded by Phase H.** The original installer/editor steps were not executed; use the current Codex-only procedure below.

Deploy note: the F2 skill edits drift vs `~/.claude` until `scripts/deploy-to-claude-and-cursor.sh` next runs (that deploy is outside rebuild scope).

**Verify:** `scripts/eval-skill-smoke.sh`, `scripts/smoke-test-codex.sh --repo`, `scripts/install-codex-local.sh` (dry-run), `git diff --check`, CI validate green.

---

## Phase G — Codex canonical + Claude/Cursor retirement (2026-09-13, `feat/codex-native-rebuild`)

**Trigger:** owner stopped using Claude Code and Cursor; Codex (CLI + IDE extension + desktop) is the primary surface. Repo renamed `multi-agent-system-architecture-codex`.

- [x] G1. **Docs pivoted to Codex** — README, AGENTS.md, CODEX.md, and the harness map rewritten Codex-first; PLAN.md retitled with a supersede note; Phase F kept.
- [x] G2. **Claude/Cursor surfaces removed** — `agents/*.md`, `CLAUDE.md`, `CURSOR.md`, `.claude/settings.json`, `.cursor/rules/*`, `scripts/deploy-to-claude-and-cursor.sh`, `scripts/integrate-cursor-from-claude.sh`, `scripts/smoke-test.sh`, `reference/{nexus-persona,research-notes,review-workflow.example.js}`. Git history preserves them.
- [x] G3. **Skills rewritten Codex-first** — `$orchestrate` rewritten (Codex delegation rules, no Claude model tiers), `$closed-loop` reviewer leg now the Codex `reviewer` agent; eval contracts and CI updated to match.
- [x] G4. **Single installer** — `scripts/install-codex-local.sh` is the only deploy path; `scripts/smoke-test-codex.sh` the only smoke suite; CI asserts legacy surfaces are absent.

**Verify:** `scripts/eval-skill-smoke.sh --quiet`, `scripts/smoke-test-codex.sh --repo --quiet`, `scripts/install-codex-local.sh` (dry-run), `git diff --check`, CI validate green.

---

## Phase H — Canonical personal library compatibility (2026-10-12)

- [x] H1. **Repository agents modernized** — current permission profiles; inherit the parent model/provider/effort; merged in PR16.
- [x] H2. **Quiet failure diagnostics** — failures stay visible in CI; offline regression and native Goal/reviewer passed; merged in PR17.
- [x] H3. **Scoped installer authored and reviewed** — `--agents-only` preserves canonical `~/.agents/skills/` directories and Codex skill mirrors. All selected collisions are checked before writes; backups use `~/.agents/backups/`. Offline apply/rollback, full-mode compatibility, collision refusal, ShellCheck, repository gates, and independent review pass.
- [ ] H4. **Live installation (explicit approval)** — run `scripts/install-codex-local.sh --agents-only --apply`, retain its manifest, then `scripts/smoke-test-codex.sh --live --agents-only`. Creates governor/builder and replaces planner/reviewer under `~/.codex/agents/`; does not deploy skills or change global configuration.
- [ ] H5. **Fresh-session acceptance** — confirm installed agent discovery and inherited model selection in a new Codex session. Offline fixtures do not establish live deployment.

See `CODEX.md` for the current installation and rollback procedure.

---

## Guardrails (apply to all phases)
- Governance files (`~/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.claude/settings.json`) change **only** via reviewed proposal — Hard Stop.
- No unbounded loops: every loop has an eval gate or a budget/turn cap.
- Author-here → review → deploy. Never auto-deploy into `~/.claude/`.
- Keep the roster small. New agent only if it reduces friction more than it adds maintenance.
