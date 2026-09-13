#!/usr/bin/env bash
# Compact, read-only health checks for this Codex-native repository and its local Codex setup.
#
# Usage:
#   scripts/codex-health.sh [--all|--repo|--local] [--quiet]
#
# Exit codes:
#   0  all requested checks passed (warnings may be present)
#   1  one or more checks failed
#   2  invalid arguments or Codex unavailable for a local check
set -euo pipefail
IFS=$'\n\t'

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO
readonly CODEX_HOME_PATH="${CODEX_HOME:-${HOME}/.codex}"

QUIET=0
CHECK_REPO=1
CHECK_LOCAL=1
FAIL=0
EXIT_CODE=0

log() {
  if [[ "${QUIET}" -eq 0 ]]; then
    printf '%s\n' "$*"
  fi
}

pass() { log "[PASS] $*"; }
warn() { log "[WARN] $*"; }

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  FAIL=1
}

usage() {
  printf '%s\n' \
    'Usage: scripts/codex-health.sh [--all|--repo|--local] [--quiet]' \
    '' \
    'Options:' \
    '  --all       check repository contracts and local Codex health (default)' \
    '  --repo      check repository contracts only' \
    '  --local     check local Codex health only' \
    '  -q, --quiet suppress passing and warning output' \
    '  -h, --help  show this help'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      CHECK_REPO=1
      CHECK_LOCAL=1
      ;;
    --repo)
      CHECK_REPO=1
      CHECK_LOCAL=0
      ;;
    --local)
      CHECK_REPO=0
      CHECK_LOCAL=1
      ;;
    --quiet|-q) QUIET=1 ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf '[ERR ] unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

check_repo() {
  if "${REPO}/scripts/smoke-test-codex.sh" --repo --quiet; then
    pass "repo contract smoke"
  else
    fail "repo contract smoke"
  fi
}

codex_in_repo() {
  (
    cd "${REPO}"
    codex "$@"
  )
}

check_local() {
  if ! command -v codex >/dev/null 2>&1; then
    fail "codex CLI unavailable on PATH"
    EXIT_CODE=2
    return
  fi

  local doctor_status
  if ! doctor_status="$(codex_in_repo doctor --summary --json 2>/dev/null | sed -n 's/.*"overallStatus": "\([^"]*\)".*/\1/p' | head -n 1)"; then
    fail "codex doctor (run 'codex doctor' for detail)"
  elif [[ "${doctor_status}" == "ok" ]]; then
    pass "codex doctor"
  elif [[ "${doctor_status}" == "warn" || "${doctor_status}" == "warning" ]]; then
    warn "codex doctor reported ${doctor_status} (run 'codex doctor' for detail)"
  else
    fail "codex doctor reported ${doctor_status:-an unknown status}"
  fi

  if codex_in_repo --strict-config --version >/dev/null 2>&1; then
    pass "base config strict validation"
  else
    fail "base config strict validation"
  fi

  if [[ ! -d "${CODEX_HOME_PATH}" ]]; then
    warn "no CODEX_HOME directory at ${CODEX_HOME_PATH}; profile checks skipped"
  else
    local profile_path profile_name
    local -a profiles=("${CODEX_HOME_PATH}"/*.config.toml)
    if [[ ! -e "${profiles[0]}" ]]; then
      warn "no profile files in ${CODEX_HOME_PATH}"
    else
      for profile_path in "${profiles[@]}"; do
        profile_name="${profile_path##*/}"
        profile_name="${profile_name%.config.toml}"
        if codex_in_repo --strict-config --profile "${profile_name}" --version >/dev/null 2>&1; then
          pass "profile ${profile_name} strict validation"
        else
          fail "profile ${profile_name} strict validation"
        fi
      done
    fi
  fi

  if codex_in_repo plugin list >/dev/null 2>&1; then
    pass "plugin inventory"
  else
    fail "plugin inventory"
  fi

  if codex_in_repo mcp list >/dev/null 2>&1; then
    pass "MCP inventory (definitions only; servers not started)"
  else
    fail "MCP inventory"
  fi
}

log "=== Codex health ==="
if [[ "${CHECK_REPO}" -eq 1 ]]; then
  check_repo
fi
if [[ "${CHECK_LOCAL}" -eq 1 ]]; then
  check_local
fi

if [[ "${FAIL}" -eq 0 ]]; then
  log "[DONE] Codex health checks passed."
else
  log "[FAIL] One or more Codex health checks failed."
fi
if [[ "${EXIT_CODE}" -ne 0 ]]; then
  exit "${EXIT_CODE}"
fi
exit "${FAIL}"
