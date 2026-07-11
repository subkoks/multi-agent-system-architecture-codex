# Security

This repository holds **agent architecture prompts and shell deploy scripts** — not application secrets, wallets, or production credentials.

## Reporting

- Prefer private disclosure via GitHub security advisories if the repo ever holds sensitive automation, or open an issue with the `security` label for process questions.
- Do **not** paste API keys, tokens, seed phrases, or `.env` contents into issues or PRs.

## Agent / deploy notes

- Deploy scripts copy into `~/.claude/` and may touch Cursor MCP config. Review before running.
- Governance files outside this repo (`~/AGENTS.md`, `~/.claude/settings.json`) are Hard Stop — propose only; never auto-apply from agents.
- Real-money Solana or payment flows are out of scope for this architecture repo; use domain security reviewers in product repos.
