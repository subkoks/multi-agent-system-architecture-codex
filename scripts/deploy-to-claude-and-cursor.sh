#!/usr/bin/env bash
# Deploy agents/skills from this repo to ~/.claude/ and sync Cursor.
#
# Usage:
#   scripts/deploy-to-claude-and-cursor.sh           # deploy + integrate
#   scripts/deploy-to-claude-and-cursor.sh --dry-run # print actions only
#
# Author-here → review → deploy. Never auto-deploy without running from this repo.
set -euo pipefail

DRY_RUN=0
REPO="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE="${HOME}/.claude"
INTEGRATE="${REPO}/scripts/integrate-cursor-from-claude.sh"
if [[ ! -x "$INTEGRATE" ]]; then
  INTEGRATE="${HOME}/.agents/scripts/integrate-cursor-from-claude.sh"
fi

log() { printf '%s\n' "$*"; }
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *) log "[ERR ] unknown option: $1"; exit 2 ;;
  esac
done

log "=== Deploy: ${REPO} → Claude → Cursor ==="

for agent in "${REPO}"/agents/*.md; do
  [[ -f "$agent" ]] || continue
  base="$(basename "$agent")"
  [[ "$base" == ".gitkeep" ]] && continue
  run cp "$agent" "${CLAUDE}/agents/${base}"
  log "[ OK ] agents/${base} → ~/.claude/agents/"
done

for skill_dir in "${REPO}"/skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  base="$(basename "$skill_dir")"
  [[ "$base" == ".gitkeep" ]] && continue
  run rm -rf "${CLAUDE}/skills/${base}"
  run cp -R "$skill_dir" "${CLAUDE}/skills/${base}"
  log "[ OK ] skills/${base}/ → ~/.claude/skills/"
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[dry-run] ${INTEGRATE} --dry-run"
  run "$INTEGRATE" --dry-run
else
  run "$INTEGRATE"
fi

if [[ -x "${REPO}/scripts/integrate-cursor-from-claude.sh" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] sync integrate script -> ~/.agents/scripts/"
  else
    run mkdir -p "${HOME}/.agents/scripts"
    run cp "${REPO}/scripts/integrate-cursor-from-claude.sh" "${HOME}/.agents/scripts/integrate-cursor-from-claude.sh"
    run chmod +x "${HOME}/.agents/scripts/integrate-cursor-from-claude.sh"
    log "[ OK ] synced integrate-cursor-from-claude.sh -> ~/.agents/scripts/"
  fi
fi

# Repo-owned security skills must stay Cursor-canonical (avoid cursor<->claude loops).
for repo_install in \
  "${HOME}/Projects/blackterminal-security/install.sh" \
  "${HOME}/Projects/prompt-injection-security/install.sh"; do
  if [[ -x "$repo_install" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "[dry-run] $repo_install"
    else
      "$repo_install"
    fi
  fi
done

log ""
log "[DONE] Deploy complete. Restart Cursor if MCP or hooks changed."
