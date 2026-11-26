# Codex harness map

This repository is the authoring root for the BLACK.TERMINAL Codex multi-agent architecture. The main session coordinates the work, and the six specialist agents operate on explicitly assigned scopes.

| Need | Native surface | Repository source |
| --- | --- | --- |
| Project permissions, search and delegation cap | Trusted project configuration | [`.codex/config.toml`](../.codex/config.toml) |
| Independent planning, execution, verification and evidence | Custom subagent definitions | [`.codex/agents/`](../.codex/agents/) |
| Workflow and gate instructions | Discovered project skills | [`skills/`](../skills/) · [`.agents/skills/`](../.agents/skills/) |
| A recurring check inside the current session | Available wait and monitoring tools, with a finite stop condition | [Session loop](../skills/loop/SKILL.md) |
| Optional public developer documentation | OpenAI Docs MCP or official web pages | [Tools and usage](../CODEX.md#models-tools-and-usage) |
| Local roles shared across projects | Explicitly authorized install | [Installation and rollback](../CODEX.md#local-installation-approval-required) |

Codex CLI, the IDE extension and the desktop app share the project layout. Tool availability and permissions depend on the client and parent session. Earlier Claude Code and Cursor setups are recorded in [BUILD.md](../BUILD.md).
