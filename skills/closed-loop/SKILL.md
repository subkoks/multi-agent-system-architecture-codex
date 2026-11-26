---
name: closed-loop
description: Implement an authorized change and verify it with repository gates and an independent Codex reviewer. Retry within a five-iteration cap.
---

# Closed-loop verification

Read AGENTS.md and the relevant code. Discover the repository's test, typecheck, lint and build commands in its workflows, scripts or documented contributor entry points. Run the commands applicable to the change and record what each verifies. Use tools already present or declared by the repository. Avoid unapproved tooling downloads, including `npx --yes`.

A gate passes when the applicable tests, type checks and lint checks pass and the `reviewer` agent (Codex) finds no Critical or Major issue. Mark irrelevant checks as inapplicable and missing required evidence as blocked. For real-money changes require the applicable authorized domain reviewer as an additional gate.

## Loop protocol

1. Implement the next bounded change and preserve unrelated work.
2. Run the applicable mechanical gates. Diagnose reported failures and fix their cause.
3. Give the independent reviewer the changed paths or commit, scope, checks and available evidence. If the diff changes after review, obtain a review of the updated scope.
4. Finish when the checks and review pass. Otherwise repair the specific failure and repeat. After two failures with the same method, change method.

`MAX_ITERATIONS = 5`. At the cap, report `[BLOCKED]` with the remaining findings and check output. Never report `[DONE]` for a failing gate. Never disable or skip a required check to obtain a pass.

When reporting, list changed files or commits, checks actually run, reviewer verdict and any remaining verification limits. Commits, external actions, governance edits and runtime installation follow AGENTS.md and task authorization.
