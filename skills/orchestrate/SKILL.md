---
name: orchestrate
description: Choose a bounded Codex workflow and assign explicit subagent roles, ownership, and verification. Use for planning delegated, researched, or multi-phase work.
---

# Orchestrate a Codex task

Use the main session to classify, route, integrate and report. A routing request produces a plan. Continue into execution when the user has already asked for implementation.

| Work | Route |
| --- | --- |
| Small, clear change | Main session, with the smallest relevant check |
| Multi-phase design | `planner` for risks, file ownership and acceptance |
| Implementation | Main session or `builder` with up to five explicitly owned files |
| Independent verification | `reviewer` for the diff and the reported gate evidence |
| Official documentation and compatibility | `docs-researcher` for a scoped, cited lookup |
| GitHub and release readiness | `repo-operator` for read-only evidence on specific refs |
| Agent/config drift and upgrade proposals | `governor` for one audit pass |
| Recurring or event-gated checks | `$loop` within one session, with a stop condition |

## Codex delegation rules

- **Depth cap by convention.** The main session spawns children. Each child returns its result to the main session without delegating.
- **Thread cap.** Keep at most three open child threads. Start with one child when only one leg benefits from delegation. Reuse related child context when possible.
- **Write isolation.** Assign disjoint file ownership or separate worktrees for writers. Serialize dependencies and overlapping edits.
- **Task spec.** State scope, inputs, allowed tools or writes, output, verifier and stop condition. Send the relevant paths and questions so children can start without duplicating the main session's discovery.
- **Models.** Inherit the selected parent configuration by default. For a narrowly scoped scan, choose a lighter supported model explicitly if authorized. Raise effort for difficult reasoning and review. Check the selected provider and client before requesting an override.
- **Tools.** Start with local evidence and available connectors. Use fresh official sources for changeable facts. Request `bsela_route` once only if the task authorizes BSELA and provides an appropriate tool. Send a sanitized summary. Treat the result as optional evidence for human-approved routing. If unavailable, route from the table.

## Eval gate and stop condition

For implementation use `$closed-loop` with repository checks, the independent `reviewer` and a maximum of five iterations. For research, define the questions, source scope and one-pass result up front. For ongoing checks use the current session and stop at the named event, deadline or iteration cap.

Return the task category, ordered phases, roles and file ownership, applicable checks, and stop condition. Include any Hard Stops that require authorization. External writes, installations and sensitive inputs follow the task's explicit authorization.
