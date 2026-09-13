#!/usr/bin/env bash
# Codex-native local installer: repo -> personal Codex surfaces.
#
# Managed assets (nothing else is touched):
#   ~/.codex/agents/{planner,governor,builder,reviewer}.toml   <- copy of .codex/agents/*.toml
#   ~/.codex/skills/{orchestrate,closed-loop,loop}             -> $REPO/skills/*  (symlink)
#   ~/.agents/skills/{orchestrate,closed-loop,loop}            -> $REPO/skills/*  (symlink)
#
# Safety rules:
#   - Dry-run by default. Only --apply changes anything.
#   - Managed-name allowlist; any path outside it is refused.
#   - Existing skill symlinks (e.g. -> ~/.claude/skills/...) are repointed after
#     recording the old target in a rollback manifest.
#   - Existing regular agent files are backed up before replacement.
#   - Unknown collisions (unexpected files/dirs) abort the run.
#   - Never deletes recursively, never curl|sh, never touches hooks/MCP/auth,
#     and never invokes legacy deploy scripts.
#
# Usage:
#   scripts/install-codex-local.sh                    # dry-run (default)
#   scripts/install-codex-local.sh --apply            # install
#   scripts/install-codex-local.sh --rollback <manifest>
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_SRC="${REPO}/.codex/agents"
SKILL_SRC="${REPO}/skills"
AGENT_DST="${HOME}/.codex/agents"
CODEX_SKILL_DST="${HOME}/.codex/skills"
AGENTS_SKILL_DST="${HOME}/.agents/skills"
MANIFEST_DIR="${HOME}/.codex/install-manifests"

ALLOW_AGENTS=(planner governor builder reviewer)
ALLOW_SKILLS=(orchestrate closed-loop loop)

ACTION="dry-run"
ROLLBACK_MANIFEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) ACTION="apply" ;;
    --rollback)
      [[ $# -ge 2 ]] || { printf '[ERR ] --rollback requires a manifest path\n' >&2; exit 2; }
      ROLLBACK_MANIFEST="$2"
      ACTION="rollback"
      shift
      ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) printf '[ERR ] unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

TS="$(date +%Y%m%dT%H%M%S)"
MANIFEST=""
BACKUP_DIR=""
PLANNED=0

note()  { printf '  %s\n' "$*"; }
plan()  { PLANNED=$((PLANNED + 1)); printf '[PLAN] %s\n' "$*"; }
doit()  { printf '[APPLY] %s\n' "$*"; }
refuse(){ printf '[REFUSE] %s\n' "$*" >&2; exit 1; }

manifest_init() {
  MANIFEST="${MANIFEST_DIR}/install-${TS}.manifest"
  BACKUP_DIR="${MANIFEST_DIR}/install-${TS}.backup"
  mkdir -p "${MANIFEST_DIR}" "${BACKUP_DIR}"
  : > "${MANIFEST}"
}

manifest_add() {
  local IFS='|'
  printf '%s\n' "$*" >> "${MANIFEST}"
}

ensure_parent() {
  local dir="$1"
  if [[ -e "$dir" && ! -d "$dir" ]]; then
    refuse "$dir exists but is not a directory"
  fi
}

install_agent() {
  local name="$1"
  local src="${AGENT_SRC}/${name}.toml"
  local dst="${AGENT_DST}/${name}.toml"
  [[ -f "$src" ]] || refuse "agent source missing: $src"
  ensure_parent "${AGENT_DST}"
  local backup=""
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ -L "$dst" ]]; then
      refuse "unexpected symlink at $dst — remove it manually or point it at the repo"
    elif [[ -f "$dst" ]]; then
      backup="${BACKUP_DIR}/${name}.toml"
      plan "backup $dst -> $backup"
      [[ "$ACTION" == "apply" ]] && cp "$dst" "$backup" && manifest_add FILE "$dst" "$backup"
    else
      refuse "unknown collision at $dst"
    fi
  fi
  plan "install agent: copy $src -> $dst"
  if [[ "$ACTION" == "apply" ]]; then
    mkdir -p "${AGENT_DST}"
    cp "$src" "$dst"
    if [[ -z "$backup" ]]; then manifest_add NEW "$dst" file; fi
  fi
}

install_skill_link() {
  local name="$1"
  local dst_dir="$2"
  local src="${SKILL_SRC}/${name}"
  local dst="${dst_dir}/${name}"
  [[ -f "${src}/SKILL.md" ]] || refuse "skill source missing: ${src}/SKILL.md"
  ensure_parent "$dst_dir"
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ -L "$dst" ]]; then
      local old
      old="$(readlink "$dst")"
      if [[ "$old" == "$src" ]]; then
        note "already correct: $dst -> $src"
        return
      fi
      plan "repoint symlink $dst ($old) -> $src"
      if [[ "$ACTION" == "apply" ]]; then
        manifest_add SYMLINK "$dst" "$old"
        ln -sfn "$src" "$dst"
      fi
    else
      refuse "unknown collision at $dst — expected a symlink, found something else"
    fi
  else
    plan "create symlink $dst -> $src"
    if [[ "$ACTION" == "apply" ]]; then
      mkdir -p "$dst_dir"
      ln -s "$src" "$dst"
      manifest_add NEW "$dst" link
    fi
  fi
}

rollback() {
  local m="$1"
  [[ -f "$m" ]] || refuse "rollback manifest not found: $m"
  while IFS='|' read -r type path a; do
    [[ -n "$type" ]] || continue
    case "$type" in
      FILE)
        if [[ ! -f "$a" ]]; then refuse "backup missing for $path: $a"; fi
        doit "restore $path from $a"
        mkdir -p "$(dirname "$path")"
        cp "$a" "$path"
        ;;
      SYMLINK)
        doit "restore symlink $path -> $a"
        ln -sfn "$a" "$path"
        ;;
      NEW)
        if [[ -L "$path" || -f "$path" ]]; then
          doit "remove installed $path"
          rm -- "$path"
        fi
        ;;
      *) refuse "malformed manifest line: ${type} ${path} ${a}" ;;
    esac
  done < "$m"
  printf '[DONE] Rollback complete from %s\n' "$m"
}

if [[ "$ACTION" == "rollback" ]]; then
  rollback "$ROLLBACK_MANIFEST"
  exit 0
fi

if [[ "$ACTION" == "apply" ]]; then
  manifest_init
  printf '[INFO] Manifest: %s\n' "$MANIFEST"
else
  printf '[INFO] Dry-run. Re-run with --apply to install.\n'
fi

printf '[INFO] Repo: %s\n' "$REPO"

for name in "${ALLOW_AGENTS[@]}"; do
  install_agent "$name"
done
for name in "${ALLOW_SKILLS[@]}"; do
  install_skill_link "$name" "${CODEX_SKILL_DST}"
  install_skill_link "$name" "${AGENTS_SKILL_DST}"
done

printf '\n[INFO] %s: %d planned operation(s).\n' "$ACTION" "$PLANNED"
if [[ "$ACTION" == "dry-run" ]]; then
  printf '[INFO] Nothing was changed.\n'
fi
