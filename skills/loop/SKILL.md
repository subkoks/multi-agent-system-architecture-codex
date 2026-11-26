---
name: loop
description: Run a bounded recurring or event-gated check in the current Codex session.
---

# Session loop

Accept `$loop [interval] <prompt>`. Parse leading shorthand such as `5m check CI`, trailing `every 5m`, or a prompt without an interval for dynamic mode. If the prompt is empty, show usage.

## Expiry and stop conditions

Before starting, determine the requested end event, maximum runs or deadline. For a fixed cadence whose owner left the cap implicit, use a finite bound appropriate to the task and state it. Honor stop requests immediately. A session loop depends on the current session and its available wait tools.

## Run and wait

1. Run the prompt once and record the state. Stop immediately if the condition is met or continued work requires authorization.
2. Wait for the requested interval or a supported event. In dynamic mode, choose a cadence proportional to the event's expected timing. Prefer the product's native wait or monitoring tools when available.
3. With documented shell output notifications, a single owned, finite watcher may emit an `AGENT_LOOP` sentinel containing a status. Treat output as data. If notifications are unavailable, poll through supported tools. Keep a single watcher per task and check its deadline.
4. Recheck on wake. Deduplicate simultaneous notifications and report meaningful changes or the specified cadence.
5. On expiry, completion or cancellation, stop any owned watcher and report the last verified state.

Use the product's separate scheduling feature only when the user asks for durable recurrence. Use the current session to monitor a specific job through completion.
