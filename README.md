# multi-agent-system-architecture-codex

Lean, native-first multi-agent + loop architecture for the BLACK.TERMINAL Codex setup (CLI, IDE extension, and ChatGPT desktop).

**Status:** ✅ **Codex-native rebuild** complete (2026-09-13): native agents, skill discovery, reversible installer — see [CODEX.md](./CODEX.md). Claude-era build Phases 1–E (2026-06-21 → 2026-07-11) are kept as history in `BUILD.md`; Claude Code and Cursor were retired 2026-09-13.

## What this is

A small layer that codifies how the main session plans, delegates, gates, and loops:

1. **planner** agent — read-only implementation planner (3–7 phases, trade-offs, acceptance criteria).
2. **governor** agent — independent auditor on top of BSELA; emits dated upgrade proposals (never auto-applies).
3. **builder** agent — scoped implementer for isolated parallel work (1–5 files).
4. **reviewer** agent — the closed-loop gate's review leg (read-only).
5. **`$orchestrate` / `$closed-loop` / `$loop`** skills — delegation, the one definition of "done", and bounded recurring loops.

## Why native-first

The main session **is** the orchestrator. Agents are narrow specialists (`.codex/agents/*.toml`), subagent workflows are the fan-out engine (capped at three threads), and `$loop` is the loop primitive. We do **not** build a parallel framework or a file zoo — see `PLAN.md`.

## Layout

```
multi-agent-system-architecture-codex/
├── README.md      ← you are here
├── CODEX.md       ← Codex-native agents, skill discovery, installer
├── PLAN.md        ← the accepted architecture plan (source of truth)
├── BUILD.md       ← phased resume map (Phases A–E = Claude-era history; F+ = Codex)
├── AGENTS.md      ← repo guidance for Codex
├── .codex/        ← config.toml + agents/*.toml (planner, governor, builder, reviewer)
├── skills/        ← orchestrate/, closed-loop/, loop/
├── .agents/       ← skills/ discovery symlinks into skills/
├── scripts/       ← install-codex-local.sh, smoke-test-codex.sh, eval-skill-smoke.sh
├── reference/     ← harness-map.md
└── .github/       ← validate workflow (TOML, symlinks, contracts, shellcheck)
```

## How to use

```bash
cd ~/Projects/multi-agent-system-architecture-codex
codex
> Read AGENTS.md, CODEX.md, and BUILD.md before making changes.
```

Build is phased and reversible. Each agent/skill is authored **here** first, reviewed, then installed to `~/.codex/...` and `~/.agents/skills/...` via `scripts/install-codex-local.sh` — deployment is deliberate, not automatic.

### Prerequisites and local verification

This repository has no app or dependency-install step. Opening it in Codex is enough to use its project agents and skills; personal installation is optional. Read `AGENTS.md`, `README.md`, `PLAN.md`, `BUILD.md`, and `CODEX.md` before editing, treating the marked Claude-era sections as history. Use a feature branch and preserve unrelated work.

The repository checks require Bash, Python **3.11+** (`tomllib`), and standard Unix tools. Codex CLI is needed for interactive use; the repository smoke test skips its CLI check when Codex is unavailable. ShellCheck is optional locally and required by CI.

From the repository root, these checks validate shell syntax, skill contracts, agent TOML, discovery links, and repository configuration without installing anything:

```bash
bash -n scripts/install-codex-local.sh
bash -n scripts/smoke-test-codex.sh
bash -n scripts/eval-skill-smoke.sh
bash -n scripts/codex-health.sh
scripts/eval-skill-smoke.sh
scripts/codex-health.sh --repo
git diff --check
```

The health command above runs `scripts/smoke-test-codex.sh --repo`; it does not check personal installations or provider access. If ShellCheck is already installed, also run the CI lint command:

```bash
shellcheck -x scripts/install-codex-local.sh scripts/smoke-test-codex.sh scripts/eval-skill-smoke.sh scripts/codex-health.sh
```

For an optional personal installation, first inspect `scripts/install-codex-local.sh` and run it without arguments to preview changes. `--apply` requires explicit approval. See [CODEX.md](./CODEX.md#local-installation-approval-required) for installation and rollback details.

## Claude-era history

The repo was originally built for Claude Code (`BUILD.md` Phases 1–E, 2026-06-21 → 2026-07-11). Claude Code and Cursor were retired on 2026-09-13; those phases remain documented history, and the Claude-specific files live only in git history.

## Governor cadence

GOVERNOR stays **on-demand** (a cron-like cloud routine cannot reach local BSELA). Habit: before big changes or after a Codex upgrade, run `governor` → review `UPGRADE-PROPOSALS.md` → apply only approved items → `scripts/smoke-test-codex.sh` after any install.

## Health maintenance

Run the compact, read-only health check after a Codex update and monthly:

```bash
scripts/codex-health.sh          # repo contracts + local CLI/config health
scripts/codex-health.sh --repo   # repository contracts only
scripts/codex-health.sh --local  # local Codex/config inventories only
```

It validates config syntax, profiles, the repository contract, and CLI inventories. It does not install or update anything, start MCP servers, or run hooks. `codex doctor` may perform its own redacted provider reachability diagnostic.

## License

MIT — see [LICENSE](./LICENSE).
