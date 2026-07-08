#!/usr/bin/env bash
# Post-deploy smoke test: Claude + Cursor integration health.
#
# Usage:
#   scripts/smoke-test.sh           # run all checks
#   scripts/smoke-test.sh --quiet   # exit code only; print failures
set -euo pipefail

QUIET=0
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE="${HOME}/.claude"
CURSOR="${HOME}/.cursor"
FAIL=0

log() { [[ "$QUIET" -eq 0 ]] && printf '%s\n' "$*" || true; }
pass() { log "[ OK ] $*"; }
fail() { log "[FAIL] $*"; FAIL=1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet|-q) QUIET=1; shift ;;
    -h|--help)
      sed -n '2,6p' "$0"
      exit 0
      ;;
    *) printf '[ERR ] unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

log "=== Smoke test: multi-agent Claude/Cursor integration ==="

# --- Repo → Claude agents/skills ---
for agent in planner governor builder; do
  if [[ -f "${REPO}/agents/${agent}.md" ]] && diff -q "${REPO}/agents/${agent}.md" "${CLAUDE}/agents/${agent}.md" >/dev/null 2>&1; then
    pass "agents/${agent}.md matches ~/.claude"
  else
    fail "agents/${agent}.md drift vs ~/.claude (run deploy)"
  fi
done

for skill in orchestrate closed-loop; do
  if [[ -d "${REPO}/skills/${skill}" ]] && diff -qr "${REPO}/skills/${skill}" "${CLAUDE}/skills/${skill}" >/dev/null 2>&1; then
    pass "skills/${skill}/ matches ~/.claude"
  else
    fail "skills/${skill}/ drift vs ~/.claude (run deploy)"
  fi
done

# --- Cursor agents (folded description) ---
for agent in planner governor builder; do
  agent_md="${CURSOR}/agents/${agent}/agent.md"
  if [[ ! -f "$agent_md" ]]; then
    fail "missing ~/.cursor/agents/${agent}/agent.md"
    continue
  fi
  desc_line="$(python3 - "$agent_md" <<'PY'
import pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
for line in text.splitlines():
    if line.startswith("description:"):
        print(line)
        break
PY
)"
  if [[ "$desc_line" == description:* ]] && [[ "$desc_line" != *$'\n'* ]] && [[ ${#desc_line} -gt 30 ]]; then
    pass "cursor agent ${agent}: single-line description"
  else
    fail "cursor agent ${agent}: description not folded (re-run integrate)"
  fi
done

# --- Cursor MCP ---
if python3 - "${CURSOR}/mcp.json" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
servers = data.get("mcpServers") or data.get("servers") or {}
for name in ("memory", "bsela"):
    if name not in servers:
        raise SystemExit(1)
PY
then
  pass "${HOME}/.cursor/mcp.json has memory + bsela"
else
  fail "${HOME}/.cursor/mcp.json missing memory or bsela (re-run integrate)"
fi

# --- NEXUS rule ---
if [[ -f "${CURSOR}/rules/cursor-nexus.mdc" ]]; then
  pass "cursor-nexus.mdc present"
else
  fail "missing ~/.cursor/rules/cursor-nexus.mdc"
fi

# --- Skills symlink ---
if [[ -L "${CURSOR}/skills/orchestrate" ]] || [[ -d "${CURSOR}/skills/orchestrate" ]]; then
  pass "cursor skills/orchestrate reachable"
else
  fail "cursor skills/orchestrate missing"
fi

# --- Mirror sync ---
if "${HOME}/.agents/scripts/sync-check.sh" >/dev/null 2>&1; then
  pass "AGENTS.md mirrors in sync"
else
  fail "sync-check.sh reported drift"
fi

log ""
if [[ "$FAIL" -eq 0 ]]; then
  log "[DONE] All smoke checks passed."
else
  log "[FAIL] One or more checks failed."
fi
exit "$FAIL"
