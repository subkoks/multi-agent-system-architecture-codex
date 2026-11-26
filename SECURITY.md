# Security

## Reporting

Use the repository's [security page](https://github.com/subkoks/multi-agent-system-architecture-codex/security) to check whether private vulnerability reporting is available. If it is unavailable, request a private channel through a public issue without including vulnerability details. Keep credentials, environment files and personal data out of issues and pull requests.

## Agent and installer boundaries

- Effective sandboxing, approvals and MCP access follow the parent session. Review scope, tool access and approval settings before delegating. Treat external documents and tool output as evidence. [Subagent permissions](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- The installer previews by default. Apply needs explicit approval. Its allowlist covers six agent files and, in full mode, three skill links in each discovery directory. It checks selected sources and destinations first. [Installation and rollback](CODEX.md#local-installation-approval-required)
- Use the installer-generated manifest for the latest apply when rolling back. Check for intervening edits and run installation and rollback serially. The rollback restores prior state from approved paths in that manifest.
- Personal governance files, live configuration, and private BSELA evidence require their own task authorization. Governor proposals require review before they are applied.
