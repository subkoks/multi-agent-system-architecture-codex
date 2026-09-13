#!/usr/bin/env bash
# Contract smoke for repo-owned skills — fails if required headings/rules disappear.
#
# Usage:
#   scripts/eval-skill-smoke.sh
#   scripts/eval-skill-smoke.sh --quiet
set -euo pipefail

QUIET=0
REPO="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

log() {
  if [[ "$QUIET" -eq 0 ]]; then
    printf '%s\n' "$*"
  fi
}
pass() { log "[ OK ] $*"; }
fail() { log "[FAIL] $*"; FAIL=1; }

require_file() {
  local path="$1"
  if [[ -f "${REPO}/${path}" ]]; then
    pass "exists ${path}"
  else
    fail "missing ${path}"
  fi
}

require_grep() {
  local path="$1" pattern="$2" label="$3"
  if [[ -f "${REPO}/${path}" ]] && grep -qE "${pattern}" "${REPO}/${path}"; then
    pass "${label}"
  else
    fail "${label} (pattern: ${pattern})"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet|-q) QUIET=1; shift ;;
    -h|--help)
      sed -n '2,7p' "$0"
      exit 0
      ;;
    *) printf '[ERR ] unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

log "=== Skill contract smoke ==="

require_file "skills/orchestrate/SKILL.md"
require_file "skills/closed-loop/SKILL.md"
require_file "skills/loop/SKILL.md"

# orchestrate contracts
require_grep "skills/orchestrate/SKILL.md" 'Depth cap' "orchestrate: depth cap"
require_grep "skills/orchestrate/SKILL.md" 'bsela_route' "orchestrate: bsela_route"
require_grep "skills/orchestrate/SKILL.md" 'Hard Stops|Hard Stop' "orchestrate: Hard Stops"
require_grep "skills/orchestrate/SKILL.md" 'Eval gate' "orchestrate: eval gate"

# closed-loop contracts
require_grep "skills/closed-loop/SKILL.md" 'MAX_ITERATIONS' "closed-loop: MAX_ITERATIONS"
require_grep "skills/closed-loop/SKILL.md" 'reviewer' "closed-loop: reviewer leg"
require_grep "skills/closed-loop/SKILL.md" 'Never.*report.*DONE|Never reports' "closed-loop: never claim done on red gate"
require_grep "skills/closed-loop/SKILL.md" 'governance|AGENTS.md' "closed-loop: governance off-limits"

# loop contracts
require_grep "skills/loop/SKILL.md" 'dynamic' "loop: dynamic mode"
require_grep "skills/loop/SKILL.md" 'AGENT_LOOP' "loop: sentinel pattern"

# Codex-native contracts (Codex rebuild)
require_grep "skills/orchestrate/SKILL.md" 'Codex delegation rules' "orchestrate: Codex delegation"
require_grep "skills/orchestrate/SKILL.md" 'Write isolation' "orchestrate: Codex write isolation"
require_grep "skills/closed-loop/SKILL.md" 'agent \(Codex\)' "closed-loop: Codex reviewer leg"
require_grep "skills/closed-loop/SKILL.md" 'npx --yes' "closed-loop: no npx --yes"
require_grep "skills/loop/SKILL.md" 'Expiry and stop conditions' "loop: expiry/stop rule"

log ""
if [[ "$FAIL" -eq 0 ]]; then
  log "[DONE] Skill contracts intact."
else
  log "[FAIL] One or more skill contracts broken."
fi
exit "$FAIL"
