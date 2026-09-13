#!/usr/bin/env bash
# Codex-native contract smoke: repo authoring state (default) or live install state.
#
# Usage:
#   scripts/smoke-test-codex.sh              # repo checks (default)
#   scripts/smoke-test-codex.sh --repo       # explicit repo checks
#   scripts/smoke-test-codex.sh --live       # repo + ~/.codex / ~/.agents install checks
#   scripts/smoke-test-codex.sh --quiet      # exit code only; print failures
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
QUIET=0
LIVE=0
FAIL=0

log() {
  if [[ "$QUIET" -eq 0 ]]; then
    printf '%s\n' "$*"
  fi
}
pass() { log "[ OK ] $*"; }
fail() { log "[FAIL] $*"; FAIL=1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet|-q) QUIET=1 ;;
    --repo) LIVE=0 ;;
    --live) LIVE=1 ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) printf '[ERR ] unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

log "=== Codex-native smoke test ==="

# --- Agent TOML schema ---
python3 - "${REPO}" <<'PY'
import pathlib, sys, tomllib
repo = pathlib.Path(sys.argv[1])
agents = sorted((repo / ".codex" / "agents").glob("*.toml"))
assert agents, "no .codex/agents/*.toml files"
expected = {"planner", "governor", "builder", "reviewer"}
found = set()
for p in agents:
    d = tomllib.load(open(p, "rb"))
    for k in ("name", "description", "developer_instructions"):
        assert k in d, f"{p}: missing {k}"
    found.add(d["name"])
    if d["name"] in {"planner", "reviewer"}:
        assert d.get("sandbox_mode") == "read-only", f"{p}: expected read-only"
assert found == expected, f"agent set {found} != {expected}"
PY
pass "agent TOML schema + allowlist (4 agents, read-only where required)"

# --- Config thread cap ---
python3 - "${REPO}" <<'PY'
import pathlib, sys, tomllib
cfg = tomllib.load(open(pathlib.Path(sys.argv[1]) / ".codex" / "config.toml", "rb"))
cap = cfg["agents"]["max_concurrent_threads_per_session"]
assert cap == 3, f"expected thread cap 3, got {cap}"
PY
pass "config: agents.max_concurrent_threads_per_session = 3"

# --- Skill discovery symlinks ---
for skill in orchestrate closed-loop loop; do
  link="${REPO}/.agents/skills/${skill}"
  if [[ -L "$link" ]] && [[ -f "${link}/SKILL.md" ]]; then
    pass "discovery link .agents/skills/${skill} resolves"
  else
    fail ".agents/skills/${skill} missing or does not resolve"
  fi
done

# --- Codex workflow contracts ---
require_grep() {
  local path="$1" pattern="$2" label="$3"
  if grep -qE "$pattern" "${REPO}/${path}"; then pass "$label"; else fail "$label"; fi
}
require_grep "skills/orchestrate/SKILL.md" 'Codex notes' "orchestrate: Codex routing"
require_grep "skills/orchestrate/SKILL.md" 'Write isolation' "orchestrate: write isolation"
require_grep "skills/closed-loop/SKILL.md" 'agent \(Codex\)' "closed-loop: Codex reviewer leg"
require_grep "skills/closed-loop/SKILL.md" 'npx --yes' "closed-loop: no npx --yes"
require_grep "skills/loop/SKILL.md" 'Expiry and stop conditions' "loop: expiry/stop rule"
require_grep "AGENTS.md" 'Never exceed three' "AGENTS.md: three-thread cap"

# --- Strict config parse (soft if codex CLI is unavailable) ---
if command -v codex >/dev/null 2>&1; then
  if codex --strict-config -C "$REPO" --help >/dev/null 2>&1; then
    pass "codex --strict-config accepts project"
  else
    fail "codex --strict-config rejected project"
  fi
else
  log "[SKIP] codex CLI not on PATH"
fi

if [[ "$LIVE" -eq 1 ]]; then
  log ""
  log "--- Live install checks ---"
  for name in planner governor builder reviewer; do
    src="${REPO}/.codex/agents/${name}.toml"
    dst="${HOME}/.codex/agents/${name}.toml"
    if [[ -f "$dst" ]] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      pass "agent ${name}.toml matches repo"
    else
      fail "agent ${name}.toml missing or drifted (run scripts/install-codex-local.sh --apply)"
    fi
  done
  for skill in orchestrate closed-loop loop; do
    for base in "${HOME}/.codex/skills" "${HOME}/.agents/skills"; do
      link="${base}/${skill}"
      if [[ -L "$link" ]] && [[ "$(readlink "$link")" == "${REPO}/skills/${skill}" ]] && [[ -f "${link}/SKILL.md" ]]; then
        pass "${base}/${skill} -> repo"
      else
        fail "${base}/${skill} not pointed at repo (run installer --apply)"
      fi
    done
  done
fi

log ""
if [[ "$FAIL" -eq 0 ]]; then
  log "[DONE] Codex-native smoke checks passed."
else
  log "[FAIL] One or more Codex-native checks failed."
fi
exit "$FAIL"
