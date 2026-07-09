#!/usr/bin/env bash
# integrate-cursor-from-claude.sh — wire ~/.cursor/ from Claude CLI + agents-md artifacts.
#
# Usage:
#   ~/.agents/scripts/integrate-cursor-from-claude.sh           # full integration
#   ~/.agents/scripts/integrate-cursor-from-claude.sh --dry-run # print actions only
#
# Idempotent. Safe to re-run after Claude skill/agent/hook changes.

set -euo pipefail

DRY_RUN=0
AGENTS_MD="${HOME}/Projects/Current/Active/agents-md"
CLAUDE="${HOME}/.claude"
CURSOR="${HOME}/.cursor"

log() { printf '%s\n' "$*"; }
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] $*"
  else
    "$@"
  fi
}

backup_if_exists() {
  local target="$1"
  if [[ -f "$target" ]]; then
    local backup
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "[dry-run] backup $target -> $backup"
    else
      cp -p "$target" "$backup"
      log "[ OK ] backed up $backup"
    fi
  fi
}

link_or_refresh() {
  local src="$1" dest="$2"
  if [[ -L "$dest" ]]; then
    local actual
    actual="$(readlink "$dest")"
    if [[ "$actual" == "$src" ]]; then
      return 0
    fi
    run rm -f "$dest"
  elif [[ -e "$dest" ]]; then
    log "[SKIP] real entry (not managed): $dest"
    return 0
  fi
  run ln -s "$src" "$dest"
  log "[ OK ] link $dest -> $src"
}

resolve_symlink() {
  local path="$1" target depth=0
  while [[ -L "$path" && "$depth" -lt 10 ]]; do
    target="$(readlink "$path")"
    case "$target" in
      /*) path="$target" ;;
      *) path="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$target" ;;
    esac
    depth=$((depth + 1))
  done
  printf '%s' "$path"
}

convert_claude_rule_to_mdc() {
  local src="$1" dest="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] convert rule $src -> $dest"
    return 0
  fi
  python3 - "$src" "$dest" <<'PY'
import pathlib, re, sys

src, dest = sys.argv[1], sys.argv[2]
text = pathlib.Path(src).read_text()
body = text
front = {}
if text.startswith("---"):
    parts = text.split("---", 2)
    if len(parts) >= 3:
        for line in parts[1].strip().splitlines():
            if ":" not in line:
                continue
            key, val = line.split(":", 1)
            front[key.strip()] = val.strip()
        body = parts[2].lstrip("\n")

paths = []
if "paths" in front:
    raw = front["paths"]
    if raw.startswith("-"):
        paths = [p.strip().strip('"').strip("'") for p in raw.splitlines() if p.strip().startswith("-")]
    else:
        paths = [raw.strip().strip('"').strip("'")]

name = pathlib.Path(src).stem
desc = front.get("description", f"{name} language/style rules from Claude CLI")
globs = paths or [f"**/*.{name}"]

out = ["---", f"description: {desc}", "globs:"]
for g in globs:
    out.append(f"  - \"{g}\"")
out.extend(["alwaysApply: false", "---", ""])
out.append(body.rstrip() + "\n")
pathlib.Path(dest).write_text("\n".join(out))
PY
  log "[ OK ] rule $dest"
}

convert_claude_agent_to_cursor() {
  local src="$1"
  local name dest_dir dest
  name="$(basename "$src" .md)"
  dest_dir="${CURSOR}/agents/${name}"
  dest="${dest_dir}/agent.md"

  if [[ -L "$src" ]]; then
    run mkdir -p "$dest_dir"
    link_or_refresh "$(readlink "$src")" "$dest"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] convert agent $src -> $dest"
    return 0
  fi

  run mkdir -p "$dest_dir"
  python3 - "$src" "$dest" <<'PY'
import pathlib, sys

src, dest = sys.argv[1], sys.argv[2]
text = pathlib.Path(src).read_text()
if not text.startswith("---"):
    pathlib.Path(dest).write_text(text)
    sys.exit(0)

parts = text.split("---", 2)
meta_lines = parts[1].strip().splitlines()
body = parts[2].lstrip("\n") if len(parts) > 2 else ""

keep = {"name", "description", "model", "readonly", "color"}


def is_top_level_key(line: str) -> bool:
    if not line.strip() or line.strip().startswith("#"):
        return False
    if line[:1] in " \t":
        return False
    return ":" in line


def fold_block(lines: list[str], start: int) -> tuple[str, int]:
    chunks: list[str] = []
    i = start
    while i < len(lines):
        if is_top_level_key(lines[i]):
            break
        stripped = lines[i].strip()
        if stripped:
            chunks.append(stripped)
        i += 1
    return " ".join(chunks), i


out_meta: list[str] = []
i = 0
while i < len(meta_lines):
    line = meta_lines[i]
    if not line.strip() or line.strip().startswith("#"):
        i += 1
        continue
    if not is_top_level_key(line):
        i += 1
        continue

    key, _, val = line.partition(":")
    key = key.strip()
    val = val.strip()

    if key not in keep:
        i += 1
        continue

    if key == "description":
        if val in (">", "|"):
            desc, i = fold_block(meta_lines, i + 1)
            out_meta.append(f"description: {desc}")
            continue
        if val:
            out_meta.append(f"description: {val}")
        i += 1
        continue

    out_meta.append(line.rstrip())
    i += 1

if not any(l.startswith("name:") for l in out_meta):
    name = pathlib.Path(src).stem
    out_meta.insert(0, f"name: {name}")

pathlib.Path(dest).write_text("---\n" + "\n".join(out_meta) + "\n---\n\n" + body.rstrip() + "\n")
PY
  log "[ OK ] agent $dest"
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

log "=== Cursor integration from Claude CLI ==="

# --- rules (agents-md lean/full + language rules from Claude) ---
if [[ -d "$AGENTS_MD" ]]; then
  log "--- rules (agents-md) ---"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] make -C $AGENTS_MD install-cursor-local"
  else
    make -C "$AGENTS_MD" install-cursor-local
  fi
else
  log "[WARN] agents-md not found at $AGENTS_MD — skipping gotcha rules"
fi

run mkdir -p "${CURSOR}/rules"

hard_stop="${CURSOR}/rules/hard-stop.mdc"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[dry-run] write $hard_stop"
else
  backup_if_exists "$hard_stop"
  cat >"$hard_stop" <<'EOF'
---
description: Hard Stop gates — explicit approval required before proceeding.
alwaysApply: true
---

# Hard Stop

Canonical source: `~/AGENTS.md` (Hard Stop section). Never auto-approve:

- Destructive file ops with meaningful data loss risk
- Dangerous git: force push, hard reset, branch deletion, history rewrite
- Secrets, credentials, API keys, private keys, seed phrases, `.env*` reads
- Real-money: production payments, fund transfers, billing / charge APIs
- Database destruction, irreversible migrations, mass deletion, production deploys
- Security-sensitive changes with unclear consequences
- Anything illegal, unsafe, or ethically abusive
EOF
  log "[ OK ] $hard_stop"
fi

nexus_rule="${CURSOR}/rules/cursor-nexus.mdc"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[dry-run] write $nexus_rule"
else
  backup_if_exists "$nexus_rule"
  cat >"$nexus_rule" <<'EOF'
---
description: Cursor NEXUS orchestration — routing, loops, delegation (from Claude CLAUDE.md).
alwaysApply: true
---

# NEXUS — Orchestrator

Global rules: `~/AGENTS.md`. Claude-specific effort/model policy: `~/.claude/CLAUDE.md`.

## Classification

| Signal | Action |
|---|---|
| plan / design / architect, or >5 files, or unclear approach | delegate to `planner` subagent first |
| build/fix with verifiable gate | `/closed-loop` skill |
| research / explore | `/loop` dynamic (turn cap) |
| recurring / while sleeping | `/loop <interval>` or automate skill |
| ≥3 independent parallel file changes | Task tool with parallel subagents |
| single clear step, <3 files | inline |

## Delegation defaults

- Cheap work → Sonnet/Haiku subagents. Planning/hard reasoning → Opus or high-thinking models.
- Pre-merge: `code-reviewer`. Security changes: `security-auditor`. Solana real-money: `solana-reviewer`.

## Loop rules

- Closed loop: tests + reviewer + type-check + lint.
- Open loop: turn cap or budget cap.
- Recurring: `/loop` interval or automate skill (no cloud cron in Cursor).

## Hard stops (orchestrator never auto-decides)

- Governance files (`~/AGENTS.md`, `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `~/.cursor/hooks.json`): propose → human applies.
- Real-money, destructive git, secrets: Hard Stop.
EOF
  log "[ OK ] $nexus_rule"
fi

log "--- language rules (Claude -> Cursor .mdc) ---"
for rule in "$CLAUDE"/rules/*.md; do
  [[ -f "$rule" ]] || continue
  base="$(basename "$rule" .md)"
  convert_claude_rule_to_mdc "$rule" "${CURSOR}/rules/${base}.mdc"
done

# --- skills: Cursor mirrors Claude tree; repo-owned skills stay repo-canonical ---
log "--- skills (symlink ~/.cursor/skills -> ~/.claude/skills) ---"
run mkdir -p "${CURSOR}/skills"
while IFS= read -r skill_dir; do
  base="$(basename "$skill_dir")"
  case "$base" in
    _*|scripts|.DS_Store) continue ;;
  esac
  [[ -d "$skill_dir" ]] || continue
  skill_target="$(resolve_symlink "$skill_dir")"
  if [[ "$skill_target" == "${CURSOR}/skills/${base}" ]]; then
    skill_target="$skill_dir"
  fi
  link_or_refresh "$skill_target" "${CURSOR}/skills/${base}"
done < <(find "$CLAUDE/skills" -mindepth 1 -maxdepth 1 2>/dev/null | sort)

# --- agents ---
log "--- agents (Claude -> ~/.cursor/agents/<name>/agent.md) ---"
run mkdir -p "${CURSOR}/agents"
for agent in "$CLAUDE"/agents/*.md; do
  [[ -e "$agent" ]] || continue
  convert_claude_agent_to_cursor "$agent"
done

# --- hooks ---
log "--- hooks ---"
run mkdir -p "${CURSOR}/hooks" "${CURSOR}/ai-tracking"

write_hook() {
  local path="$1"
  shift
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] write $path"
    return 0
  fi
  cat >"$path" "$@"
  run chmod +x "$path"
  log "[ OK ] $path"
}

write_hook "${CURSOR}/hooks/block-secrets.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
path=$(echo "$input" | jq -r '.path // .file_path // empty')
case "$path" in
  *.env|*.env.*|*/id_rsa|*/.ssh/id_*|*wallet*.json|*keystore*|*.pem|*.p12|*.key)
    echo "blocked: secret-bearing path: $path" >&2
    exit 1
    ;;
esac
exit 0
EOF

write_hook "${CURSOR}/hooks/redact-prompt-secrets.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // empty')
[[ -z "$prompt" ]] && exit 0
redacted=$(printf '%s' "$prompt" \
  | sed -E 's/sk-[a-zA-Z0-9]{20,}/[REDACTED-OPENAI]/g' \
  | sed -E 's/(ghp|gho|ghu|ghs|ghr)_[a-zA-Z0-9]{30,}/[REDACTED-GH]/g' \
  | sed -E 's/AKIA[0-9A-Z]{16}/[REDACTED-AWS]/g')
if [[ "$redacted" != "$prompt" ]]; then
  jq -n --arg p "$redacted" '{prompt: $p}'
fi
exit 0
EOF

write_hook "${CURSOR}/hooks/block-destructive-shell.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
cmd=$(echo "$input" | jq -r '.command // empty')
case "$cmd" in
  *"push --force"*|*"push -f "*|*"push -f"*)
    echo "blocked: force push requires explicit confirmation (Hard Stop)" >&2
    exit 1
    ;;
  *"rm -rf /"*|*"rm -rf  /"*)
    echo "blocked: rm -rf against root" >&2
    exit 1
    ;;
esac
exit 0
EOF

write_hook "${CURSOR}/hooks/format-after-edit.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
path=$(echo "$input" | jq -r '.path // .file_path // empty')
[[ -z "$path" || ! -f "$path" ]] && exit 0
case "$path" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json)
    command -v npx >/dev/null && npx --yes prettier --write --log-level silent "$path" 2>/dev/null || true
    ;;
  *.py)
    command -v ruff >/dev/null && ruff format --quiet "$path" 2>/dev/null || true
    ;;
  *.go)
    command -v gofmt >/dev/null && gofmt -w "$path" 2>/dev/null || true
    ;;
  *.rs)
    command -v rustfmt >/dev/null && rustfmt "$path" 2>/dev/null || true
    ;;
esac
exit 0
EOF

write_hook "${CURSOR}/hooks/audit-mcp.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
ts=$(date '+%Y-%m-%dT%H:%M:%S')
printf '[%s] %s\n' "$ts" "$input" >> "${HOME}/.cursor/ai-tracking/mcp.log" 2>/dev/null || true
exit 0
EOF

write_hook "${CURSOR}/hooks/filter-test-output.sh" <<'EOF'
#!/usr/bin/env bash
# preToolUse(Shell) hook for Cursor: shrink verbose test/build output to failures
# plus a short tail while preserving the real exit code.
set -euo pipefail

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // .command // ""')

[[ -z "$cmd" ]] && exit 0

if ! printf '%s' "$cmd" | grep -qE '^(npm (test|run test)|pnpm( run)? test|yarn test|npx vitest|vitest|jest|pytest|python -m pytest|go test|cargo (test|build)|tsc|ruff check)( |$)'; then
  exit 0
fi

if printf '%s' "$cmd" | grep -qE '[|><]|&&|;'; then
  exit 0
fi

wrapped="t=\$(mktemp); { ${cmd} ; } >\"\$t\" 2>&1; ec=\$?; \
grep -inE -A3 '(fail|error|assert|panic|traceback|exception|FAILED|✗|✖|×)' \"\$t\" | head -200; \
echo '--- last 8 lines ---'; tail -8 \"\$t\"; rm -f \"\$t\"; exit \$ec"

jq -nc --arg c "$wrapped" '{permission:"allow",updated_input:{command:$c}}'
EOF

hooks_json="${CURSOR}/hooks.json"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[dry-run] write $hooks_json"
else
  backup_if_exists "$hooks_json"
  cat >"$hooks_json" <<'EOF'
{
  "version": 1,
  "hooks": {
    "beforeReadFile": [
      { "command": "./hooks/block-secrets.sh" }
    ],
    "beforeSubmitPrompt": [
      { "command": "./hooks/redact-prompt-secrets.sh" }
    ],
    "preToolUse": [
      {
        "command": "./hooks/filter-test-output.sh",
        "matcher": "Shell"
      }
    ],
    "beforeShellExecution": [
      { "command": "./hooks/block-destructive-shell.sh" }
    ],
    "afterFileEdit": [
      { "command": "./hooks/format-after-edit.sh" }
    ],
    "beforeMCPExecution": [
      { "command": "./hooks/audit-mcp.sh" }
    ],
    "stop": [
      {
        "command": "osascript -e 'display notification \"Cursor — done\" with title \"Cursor\" sound name \"Glass\"' 2>/dev/null || true"
      }
    ],
    "sessionStart": [
      {
        "command": "echo \"[$(date '+%Y-%m-%d %H:%M:%S')] Session started in $(pwd)\" >> ~/.cursor/ai-tracking/sessions.log 2>/dev/null || true"
      }
    ]
  }
}
EOF
  log "[ OK ] $hooks_json"
fi

# --- MCP: merge core servers (memory + bsela) without clobbering extras ---
log "--- mcp (merge core memory + bsela) ---"
BSELA_MCP="${HOME}/Projects/Current/Active/BEST-Self-Enhancement-Learning-AI/mcp/dist/server.js"
mcp_json="${CURSOR}/mcp.json"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[dry-run] merge core MCP into $mcp_json"
else
  backup_if_exists "$mcp_json"
  python3 - "$mcp_json" "$BSELA_MCP" <<'PY'
import json, pathlib, sys

dest, bsela_path = sys.argv[1], sys.argv[2]
path = pathlib.Path(dest)
existing = {}
if path.is_file():
    try:
        existing = json.loads(path.read_text())
    except json.JSONDecodeError:
        existing = {}

core = {
    "memory": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-memory"],
    },
    "bsela": {
        "command": "node",
        "args": [bsela_path],
    },
}

servers = existing.setdefault("mcpServers", {})
for name, cfg in core.items():
    servers[name] = cfg

path.write_text(json.dumps(existing, indent=2) + "\n")
print(f"merged core MCP: {', '.join(core)}")
PY
  log "[ OK ] $mcp_json"
fi

# --- status line + cli config ---
log "--- cli-config + statusline ---"
if [[ "$DRY_RUN" -eq 1 ]]; then
  log "[dry-run] write statusline.sh + cli-config.json"
else
  run cp "${CLAUDE}/statusline-command.sh" "${CURSOR}/statusline.sh"
  run chmod +x "${CURSOR}/statusline.sh"
  backup_if_exists "${CURSOR}/cli-config.json"
  cat >"${CURSOR}/cli-config.json" <<'EOF'
{
  "approvalMode": "allowlist",
  "permissions": {
    "allow": [
      "Shell(git status*)",
      "Shell(git diff*)",
      "Shell(git log*)",
      "Shell(git show*)",
      "Shell(git branch*)",
      "Shell(ls*)",
      "Shell(gh *)",
      "Shell(make *)",
      "Shell(pnpm *)",
      "Shell(npx *)"
    ],
    "deny": []
  },
  "statusLine": {
    "type": "command",
    "command": "~/.cursor/statusline.sh",
    "padding": 2,
    "updateIntervalMs": 300,
    "timeoutMs": 2000
  },
  "attribution": {
    "attributeCommitsToAgent": true,
    "attributePRsToAgent": true
  }
}
EOF
  log "[ OK ] ${CURSOR}/cli-config.json"
fi

log ""
log "[DONE] Cursor integrated from Claude CLI."
log "  rules:    ${CURSOR}/rules/"
log "  skills:   ${CURSOR}/skills/ (-> ${CLAUDE}/skills/)"
log "  agents:   ${CURSOR}/agents/"
log "  hooks:    ${CURSOR}/hooks.json"
log "  mcp:      ${CURSOR}/mcp.json (core: memory + bsela merged)"
log "  loops:    /loop and /closed-loop skills available via skills tree"
log ""
log "Restart Cursor to load hooks/MCP changes. Re-run this script after Claude agent/skill updates."
