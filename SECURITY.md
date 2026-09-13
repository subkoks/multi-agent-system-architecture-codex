# Security

This repository holds **agent architecture prompts and shell deploy scripts** — not application secrets, wallets, or production credentials.

## Reporting

- Prefer private disclosure via GitHub security advisories if the repo ever holds sensitive automation, or open an issue with the `security` label for process questions.
- Do **not** paste API keys, tokens, seed phrases, or `.env` contents into issues or PRs.

## Agent / deploy notes

- `scripts/install-codex-local.sh` is dry-run by default; `--apply` is required to change anything. It copies only the four managed agent files into `~/.codex/agents/` and repoints only the three managed skill symlinks under `~/.codex/skills/` and `~/.agents/skills/`. Unknown collisions abort the run; existing files are backed up and every change is recorded in a rollback manifest. It never deletes recursively, never pipes a remote script into a shell, and never touches hooks, MCP, auth, or any legacy deploy scripts.
- Governance files outside this repo (`~/AGENTS.md`, `~/.claude/*`, `~/.cursor/*`, Codex/OpenCode mirrors) are Hard Stop — propose only; never auto-apply from agents. Claude Code and Cursor are retired; their directories are historical and still must not be modified from this repo.
- Real-money Solana or payment flows are out of scope for this architecture repo; use domain security reviewers in product repos.
