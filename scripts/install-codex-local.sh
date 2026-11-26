#!/usr/bin/env bash
# Codex-native local installer: repo -> personal Codex surfaces.
#
# Managed assets (nothing else is touched):
#   ~/.codex/agents/<managed role>.toml  <- copy of that role from .codex/agents/
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
#   scripts/install-codex-local.sh --agents-only      # preserve personal skills
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

ALLOW_AGENTS=(planner governor builder reviewer docs-researcher repo-operator)
ALLOW_SKILLS=(orchestrate closed-loop loop)

ACTION="dry-run"
AGENTS_ONLY=0
ROLLBACK_MANIFEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) ACTION="apply" ;;
    --agents-only) AGENTS_ONLY=1 ;;
    --rollback)
      [[ $# -ge 2 ]] || { printf '[ERR ] --rollback requires a manifest path\n' >&2; exit 2; }
      ROLLBACK_MANIFEST="$2"
      ACTION="rollback"
      shift
      ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) printf '[ERR ] unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

TS="$(date +%Y%m%dT%H%M%S)-$$"
MANIFEST="${MANIFEST_DIR}/install-${TS}.manifest"
BACKUP_DIR="${HOME}/.agents/backups/codex-native-install-${TS}"
PLANNED=0

note()  { printf '  %s\n' "$*"; }
plan()  { PLANNED=$((PLANNED + 1)); printf '[PLAN] %s\n' "$*"; }
doit()  { printf '[APPLY] %s\n' "$*"; }
refuse(){ printf '[REFUSE] %s\n' "$*" >&2; exit 1; }

manifest_init() {
  mkdir -p "${MANIFEST_DIR}" "${BACKUP_DIR}"
  : > "${MANIFEST}"
}

manifest_add() {
  local IFS='|'
  printf '%s\n' "$*" >> "${MANIFEST}"
}

ensure_parent() {
  local dir="$1"
  if [[ -L "$dir" || ( -e "$dir" && ! -d "$dir" ) ]]; then
    refuse "$dir must be a directory and not a symlink"
  fi
}

# Append a sentinel so command substitution preserves the target's trailing newlines.
read_link_with_sentinel() {
  readlink -n "$1" && printf '.'
}

# Validate every selected destination before creating even the manifest. A late
# skill collision must not leave earlier agents or links partially installed.
preflight() {
  local name dst
  [[ "$HOME" != *"|"* && "$HOME" != *$'\n'* ]] || refuse "HOME cannot be represented in a rollback manifest"
  ensure_parent "${HOME}/.codex"
  ensure_parent "${AGENT_DST}"
  ensure_parent "${MANIFEST_DIR}"
  ensure_parent "${HOME}/.agents"
  ensure_parent "${HOME}/.agents/backups"
  [[ ! -e "$MANIFEST" && ! -L "$MANIFEST" ]] || refuse "manifest already exists: $MANIFEST"
  [[ ! -e "$BACKUP_DIR" && ! -L "$BACKUP_DIR" ]] || refuse "backup already exists: $BACKUP_DIR"
  for name in "${ALLOW_AGENTS[@]}"; do
    [[ -f "${AGENT_SRC}/${name}.toml" ]] || refuse "agent source missing: ${AGENT_SRC}/${name}.toml"
    dst="${AGENT_DST}/${name}.toml"
    if [[ -e "$dst" || -L "$dst" ]]; then
      [[ ! -L "$dst" && -f "$dst" ]] || refuse "unknown collision at $dst — expected a regular agent file"
    fi
  done
  if [[ "$AGENTS_ONLY" -eq 0 ]]; then
    ensure_parent "${CODEX_SKILL_DST}"
    ensure_parent "${AGENTS_SKILL_DST}"
    for name in "${ALLOW_SKILLS[@]}"; do
      [[ -f "${SKILL_SRC}/${name}/SKILL.md" ]] || refuse "skill source missing: ${SKILL_SRC}/${name}/SKILL.md"
      for dst in "${CODEX_SKILL_DST}/${name}" "${AGENTS_SKILL_DST}/${name}"; do
        if [[ -L "$dst" ]]; then
          local old_target
          old_target="$(read_link_with_sentinel "$dst")"
          old_target="${old_target%.}"
          [[ "$old_target" != *"|"* && "$old_target" != *$'\n'* ]] ||
            refuse "link target cannot be represented in a rollback manifest: $dst"
        elif [[ -e "$dst" ]]; then
          refuse "unknown collision at $dst — expected a symlink, found something else"
        fi
      done
    done
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
      if [[ "$ACTION" == "apply" ]]; then
        cp "$dst" "$backup"
        manifest_add FILE "$dst" "$backup"
      fi
    else
      refuse "unknown collision at $dst"
    fi
  fi
  plan "install agent: copy $src -> $dst"
  if [[ "$ACTION" == "apply" ]]; then
    mkdir -p "${AGENT_DST}"
    if [[ -z "$backup" ]]; then manifest_add NEW "$dst" file; fi
    cp "$src" "$dst"
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
      old="$(read_link_with_sentinel "$dst")"
      old="${old%.}"
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
      manifest_add NEW "$dst" link
      ln -s "$src" "$dst"
    fi
  fi
}

rollback() {
  local m="$1" stem type path value name kind row seen="|"
  local -a types=() destinations=() values=()
  [[ -f "$m" && ! -L "$m" ]] || refuse "rollback manifest must be a regular file: $m"
  stem="${m##*/}"
  [[ "$stem" =~ ^install-[0-9]{8}T[0-9]{6}(-[0-9]+)?\.manifest$ ]] ||
    refuse "unrecognized rollback manifest name: $stem"
  stem="${stem%.manifest}"

  ensure_parent "${HOME}/.codex"
  ensure_parent "${HOME}/.agents"
  ensure_parent "${AGENT_DST}"
  ensure_parent "${MANIFEST_DIR}"
  ensure_parent "${HOME}/.agents/backups"

  # Check every row before making any changes, then use only the verified rows.
  while IFS= read -r row || [[ -n "$row" ]]; do
    [[ "$row" == *"|"*"|"* && "$row" != *"|"*"|"*"|"* ]] ||
      refuse "malformed rollback manifest row"
    IFS='|' read -r type path value <<< "$row"
    [[ "$seen" != *"|${path}|"* ]] || refuse "duplicate rollback destination: $path"
    seen+="${path}|"

    kind=""
    for name in "${ALLOW_AGENTS[@]}"; do
      if [[ "$path" == "${AGENT_DST}/${name}.toml" ]]; then
        kind="file"
        break
      fi
    done
    if [[ -z "$kind" ]]; then
      for name in "${ALLOW_SKILLS[@]}"; do
        if [[ "$path" == "${CODEX_SKILL_DST}/${name}" || "$path" == "${AGENTS_SKILL_DST}/${name}" ]]; then
          kind="link"
          break
        fi
      done
    fi
    [[ -n "$kind" ]] || refuse "unmanaged rollback destination: $path"
    ensure_parent "${path%/*}"
    if [[ "$kind" == file ]]; then
      [[ ! -L "$path" && ( ! -e "$path" || -f "$path" ) ]] || refuse "agent path changed type: $path"
    else
      [[ ! -e "$path" || -L "$path" ]] || refuse "skill path changed type: $path"
    fi

    case "$type:$kind" in
      FILE:file)
        local backup_dir="${HOME}/.agents/backups/codex-native-${stem}"
        local legacy_dir="${MANIFEST_DIR}/${stem}.backup"
        [[ "$value" == "${backup_dir}/${name}.toml" || "$value" == "${legacy_dir}/${name}.toml" ]] ||
          refuse "unrecognized backup path for $path"
        ensure_parent "${value%/*}"
        [[ -f "$value" && ! -L "$value" ]] || refuse "backup missing for $path: $value"
        ;;
      SYMLINK:link) [[ -n "$value" ]] || refuse "missing previous link target for $path" ;;
      NEW:*) [[ "$value" == "$kind" ]] || refuse "invalid installed path type for $path" ;;
      *) refuse "malformed rollback record for $path" ;;
    esac
    types+=("$type")
    destinations+=("$path")
    values+=("$value")
  done < "$m"
  [[ "$seen" != "|" ]] || refuse "rollback manifest is empty"

  local i
  for ((i = 0; i < ${#types[@]}; i++)); do
    path="${destinations[i]}"
    value="${values[i]}"
    case "${types[i]}" in
      FILE)
        doit "restore $path from $value"
        mkdir -p "${path%/*}"
        cp "$value" "$path"
        ;;
      SYMLINK)
        doit "restore symlink $path -> $value"
        mkdir -p "${path%/*}"
        ln -sfn -- "$value" "$path"
        ;;
      NEW)
        if [[ -L "$path" || -f "$path" ]]; then
          doit "remove installed $path"
          rm -- "$path"
        fi
        ;;
    esac
  done
  printf '[DONE] Rollback complete from %s\n' "$m"
}

if [[ "$ACTION" == "rollback" ]]; then
  rollback "$ROLLBACK_MANIFEST"
  exit 0
fi

preflight

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
if [[ "$AGENTS_ONLY" -eq 0 ]]; then
  for name in "${ALLOW_SKILLS[@]}"; do
    install_skill_link "$name" "${CODEX_SKILL_DST}"
    install_skill_link "$name" "${AGENTS_SKILL_DST}"
  done
else
  note "agents-only: personal skill paths are not managed"
fi

printf '\n[INFO] %s: %d planned operation(s).\n' "$ACTION" "$PLANNED"
if [[ "$ACTION" == "dry-run" ]]; then
  printf '[INFO] Nothing was changed.\n'
fi
