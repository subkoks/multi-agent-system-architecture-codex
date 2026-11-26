#!/usr/bin/env bash
# Codex-native contract smoke: repo authoring state (default) or live install state.
#
# Usage:
#   scripts/smoke-test-codex.sh              # repo checks (default)
#   scripts/smoke-test-codex.sh --repo       # explicit repo checks
#   scripts/smoke-test-codex.sh --live       # repo + ~/.codex / ~/.agents install checks
#   scripts/smoke-test-codex.sh --live --agents-only # repo + installed agents only
#   scripts/smoke-test-codex.sh --quiet      # exit code only; print failures
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
QUIET=0
LIVE=0
AGENTS_ONLY=0
FAIL=0
AGENT_NAMES=(planner governor builder reviewer docs-researcher repo-operator)

log() {
  if [[ "$QUIET" -eq 0 ]]; then
    printf '%s\n' "$*"
  fi
}
pass() { log "[ OK ] $*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; FAIL=1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet|-q) QUIET=1 ;;
    --repo) LIVE=0 ;;
    --live) LIVE=1 ;;
    --agents-only) AGENTS_ONLY=1 ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) printf '[ERR ] unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "$AGENTS_ONLY" -eq 1 && "$LIVE" -eq 0 ]]; then
  printf '[ERR ] --agents-only requires --live\n' >&2
  exit 2
fi

log "=== Codex-native smoke test ==="

# --- Agent TOML schema ---
python3 -I - "${REPO}" "${AGENT_NAMES[@]}" <<'PY'
import pathlib, sys, tomllib
repo = pathlib.Path(sys.argv[1])
agents = sorted((repo / ".codex" / "agents").glob("*.toml"))
assert agents, "no .codex/agents/*.toml files"
expected = set(sys.argv[2:])
read_only = {"planner", "reviewer", "docs-researcher", "repo-operator"}
found = set()
for p in agents:
    with p.open("rb") as agent_file:
        d = tomllib.load(agent_file)
    for k in ("name", "description", "developer_instructions"):
        assert isinstance(d.get(k), str) and d[k].strip(), f"{p}: invalid {k}"
    assert d["name"] == p.stem, f"{p}: agent name must match filename"
    found.add(d["name"])
    if d["name"] in read_only:
        assert d["features"]["memories"] is False, f"{p}: disable memories"
        assert d["features"]["request_permissions_tool"] is False, f"{p}: disable permission requests"
        assert d["skills"]["include_instructions"] is False, f"{p}: omit automatic skill instructions"
    if d["name"] == "docs-researcher":
        assert d["features"]["shell_tool"] is False, f"{p}: disable shell"
    for key in ("sandbox_mode", "sandbox_workspace_write", "default_permissions", "approval_policy",
                "model", "model_reasoning_effort", "model_provider", "model_catalog_json", "mcp_servers"):
        assert key not in d, f"{p}: {key} overrides permission profiles or inherited model selection"
assert found == expected, f"agent set {found} != {expected}"
PY
pass "agent TOML schema, roster and role defaults"

# --- Project permissions, model inheritance, and thread cap ---
python3 -I - "${REPO}" <<'PY'
import pathlib, sys, tomllib
cfg = tomllib.load(open(pathlib.Path(sys.argv[1]) / ".codex" / "config.toml", "rb"))
assert cfg.get("default_permissions") == ":workspace", "expected workspace permissions"
assert cfg.get("approval_policy") == "on-request", "expected on-request approvals"
assert cfg.get("approvals_reviewer") == "user", "expected human approval reviewer"
assert cfg.get("allow_login_shell") is False, "expected non-login shell commands"
assert cfg.get("web_search") == "cached", "expected cached web search"
assert not cfg.get("mcp_servers"), "repository must run without a default MCP dependency"
for key in ("sandbox_mode", "sandbox_workspace_write", "model", "model_reasoning_effort", "model_provider", "model_catalog_json"):
    assert key not in cfg, f"project {key} overrides permission profiles or inherited model selection"
for key in ("default_subagent_model", "default_subagent_reasoning_effort"):
    assert key not in cfg.get("agents", {}), f"agents.{key} overrides parent model selection"
cap = cfg["agents"]["max_concurrent_threads_per_session"]
assert cap == 3, f"expected thread cap 3, got {cap}"
PY
pass "config: workspace permissions, human approvals, inherited models, three-thread cap"

# --- Skill discovery symlinks ---
for skill in orchestrate closed-loop loop; do
  link="${REPO}/.agents/skills/${skill}"
  if [[ -L "$link" && "$(readlink "$link")" == "../../skills/${skill}" && -f "${link}/SKILL.md" ]]; then
    pass "discovery link .agents/skills/${skill} resolves"
  else
    fail ".agents/skills/${skill} missing or does not resolve to the canonical skill"
  fi
done

# --- Claude/Cursor retirement: legacy surfaces must be gone ---
for legacy in CLAUDE.md CURSOR.md \
  agents/planner.md agents/governor.md agents/builder.md \
  scripts/deploy-to-claude-and-cursor.sh scripts/integrate-cursor-from-claude.sh scripts/smoke-test.sh \
  .claude/settings.json .cursor/rules/project-overrides.mdc; do
  if [[ -e "${REPO}/${legacy}" || -L "${REPO}/${legacy}" ]]; then
    fail "legacy Claude/Cursor surface still present: ${legacy}"
  else
    pass "legacy surface removed: ${legacy}"
  fi
done

# --- Codex workflow contracts ---
require_grep() {
  local path="$1" pattern="$2" label="$3"
  if grep -qE "$pattern" "${REPO}/${path}"; then pass "$label"; else fail "$label"; fi
}
require_grep "skills/orchestrate/SKILL.md" 'Codex delegation rules' "orchestrate: Codex routing"
require_grep "skills/orchestrate/SKILL.md" 'Write isolation' "orchestrate: write isolation"
require_grep "skills/closed-loop/SKILL.md" 'agent \(Codex\)' "closed-loop: Codex reviewer leg"
require_grep "skills/closed-loop/SKILL.md" 'npx --yes' "closed-loop: no npx --yes"
require_grep "skills/loop/SKILL.md" 'Expiry and stop conditions' "loop: expiry/stop rule"
require_grep "AGENTS.md" 'Never exceed three' "AGENTS.md: three-thread cap"

if [[ "$LIVE" -eq 1 ]]; then
  log ""
  log "--- Live install checks ---"
  for name in "${AGENT_NAMES[@]}"; do
    src="${REPO}/.codex/agents/${name}.toml"
    dst="${HOME}/.codex/agents/${name}.toml"
    if [[ -f "$dst" ]] && diff -q "$src" "$dst" >/dev/null 2>&1; then
      pass "agent ${name}.toml matches repo"
    else
      fail "agent ${name}.toml missing or drifted (run scripts/install-codex-local.sh --agents-only --apply)"
    fi
  done
  if [[ "$AGENTS_ONLY" -eq 0 ]]; then
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
fi

log ""
if [[ "$FAIL" -eq 0 ]]; then
  log "[DONE] Codex-native smoke checks passed."
else
  log "[FAIL] One or more Codex-native checks failed."
fi
exit "$FAIL"
