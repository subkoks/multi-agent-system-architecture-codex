// review-workflow.example.js
// Fan-out code review across correctness/security/perf dimensions,
// adversarially verify each finding, return confirmed-only severity-ranked output.
//
// Usage: invoke via the Workflow tool with this script.
// Pass args: { target: "path/to/file.ts or git diff range" } — defaults to working-tree diff.

export const meta = {
  name: "review-changes",
  description:
    "Fan-out review across correctness/security/perf; adversarially verify each finding; return confirmed-only severity-ranked list",
  phases: [
    {
      title: "Review",
      detail: "Three parallel dimension reviewers scan the diff",
    },
    {
      title: "Verify",
      detail:
        "Each finding adversarially challenged by two independent skeptics",
    },
    {
      title: "Synthesize",
      detail: "Dedup, severity-rank, format final report",
    },
  ],
};

// ── Schemas ──────────────────────────────────────────────────────────────────

const FINDINGS_SCHEMA = {
  type: "object",
  required: ["findings"],
  properties: {
    findings: {
      type: "array",
      items: {
        type: "object",
        required: [
          "id",
          "severity",
          "dimension",
          "file",
          "line",
          "title",
          "verbatim",
          "fix",
        ],
        properties: {
          id: {
            type: "string",
            description: 'Short slug, e.g. "auth-bypass-1"',
          },
          severity: {
            type: "string",
            enum: ["Critical", "Major", "Minor", "Nit"],
          },
          dimension: {
            type: "string",
            enum: ["correctness", "security", "perf"],
          },
          file: { type: "string" },
          line: { type: "number" },
          title: { type: "string", description: "One-line issue description" },
          verbatim: {
            type: "string",
            description: "The offending code, quoted exactly",
          },
          fix: {
            type: "string",
            description:
              "Concrete fix (patched snippet or precise instruction)",
          },
        },
      },
    },
  },
};

const VERDICT_SCHEMA = {
  type: "object",
  required: ["id", "isReal", "confidence", "reason"],
  properties: {
    id: { type: "string" },
    isReal: {
      type: "boolean",
      description: "true = confirmed real bug/issue; false = refuted",
    },
    confidence: { type: "string", enum: ["high", "medium", "low"] },
    reason: {
      type: "string",
      description: "One sentence: why confirmed or refuted",
    },
  },
};

// ── Helpers ───────────────────────────────────────────────────────────────────

const target =
  args && args.target
    ? args.target
    : "working-tree diff (git diff + git diff --staged)";

const DIMENSIONS = [
  {
    key: "correctness",
    prompt: `You are a senior code reviewer focused ONLY on correctness bugs.
Target: ${target}

Establish the diff with \`git diff\` and \`git diff --staged\`. Read the changed lines plus enclosing functions, callers, and types.

Look for: logic errors, off-by-one, wrong conditionals, unhandled null/undefined/error paths, async/await mistakes, race conditions, resource leaks, incorrect state transitions.

Do NOT flag style issues, security, or performance — those are handled by other reviewers.

For each finding: quote the offending code verbatim, give a concrete fix (patched snippet), calibrate severity (Critical/Major/Minor/Nit) to real impact. If the change is clean, return an empty findings array.`,
  },
  {
    key: "security",
    prompt: `You are a senior security-focused code reviewer.
Target: ${target}

Establish the diff with \`git diff\` and \`git diff --staged\`. Read the changed lines plus enclosing functions, callers, and types.

Look for: unvalidated input at API/MCP/CLI boundaries, injection (SQL/command/template/prompt), authz/authn gaps, IDOR, secret handling in code or logs, unsafe deserialization, Solana account validation gaps, signing flow issues.

Trace untrusted input to its source before flagging. Note uncertainty explicitly — never invent certainty. For each finding: verbatim code + concrete fix. Return empty findings array if clean.`,
  },
  {
    key: "perf",
    prompt: `You are a senior performance-focused code reviewer.
Target: ${target}

Establish the diff with \`git diff\` and \`git diff --staged\`. Read the changed lines plus enclosing functions, callers, and types.

Look for: N+1 queries, unbounded loops/allocations, missing indexes on hot paths, needless re-renders, synchronous blocking in async paths, unnecessary serialization, missing pagination on large result sets.

Only flag issues where the performance impact is real and reachable from the changed code path. For each finding: verbatim code + concrete fix. Return empty findings array if clean.`,
  },
];

// ── Phase: Review → Verify (pipeline — no barrier) ───────────────────────────

phase("Review");

const results = await pipeline(
  DIMENSIONS,

  // Stage 1: dimension reviewer
  (dim) =>
    agent(dim.prompt, {
      label: `review:${dim.key}`,
      phase: "Review",
      schema: FINDINGS_SCHEMA,
      model: "claude-sonnet-4-6",
      effort: "high",
    }),

  // Stage 2: adversarial verify — two independent skeptics per finding
  // Runs as soon as stage 1 completes for each dimension (no cross-dim barrier)
  (review, dim) => {
    if (!review || !review.findings || review.findings.length === 0) return [];

    return parallel(
      review.findings.map((finding) => async () => {
        const verdicts = await parallel([
          () =>
            agent(
              `You are an adversarial code reviewer. Your job is to REFUTE the following finding if you can.
Be skeptical. Challenge the evidence. Look for: dead code paths, unreachable conditions, already-handled edge cases, framework guarantees that make this a non-issue.
Default to isReal=false if you are uncertain.

Finding (${finding.dimension}): ${finding.title}
File: ${finding.file}:${finding.line}
Verbatim: \`\`\`\n${finding.verbatim}\n\`\`\`
Proposed fix: ${finding.fix}

Verdict: is this a real issue? Be direct.`,
              {
                label: `verify:${finding.id}:skeptic-1`,
                phase: "Verify",
                schema: {
                  ...VERDICT_SCHEMA,
                  properties: {
                    ...VERDICT_SCHEMA.properties,
                    id: { type: "string", default: finding.id },
                  },
                },
                model: "claude-sonnet-4-6",
                effort: "high",
              },
            ),
          () =>
            agent(
              `You are a second independent adversarial reviewer. Challenge this finding from a different angle than a typical reviewer would.
Focus on: is the code actually reachable? Does the framework/runtime prevent this? Is the severity overblown?
Default to isReal=false if you are uncertain.

Finding (${finding.dimension}): ${finding.title}
File: ${finding.file}:${finding.line}
Verbatim: \`\`\`\n${finding.verbatim}\n\`\`\`

Verdict: is this a real issue?`,
              {
                label: `verify:${finding.id}:skeptic-2`,
                phase: "Verify",
                schema: {
                  ...VERDICT_SCHEMA,
                  properties: {
                    ...VERDICT_SCHEMA.properties,
                    id: { type: "string", default: finding.id },
                  },
                },
                model: "claude-sonnet-4-6",
                effort: "high",
              },
            ),
        ]);

        const valid = verdicts.filter(Boolean);
        // Confirmed = majority of skeptics say isReal (≥1 of 2 says real AND at least one is high/medium confidence)
        const confirmed = valid.filter((v) => v.isReal);
        const highConf = valid.filter(
          (v) => v.isReal && v.confidence !== "low",
        );

        if (confirmed.length >= 1 && highConf.length >= 1) {
          return {
            ...finding,
            verified: true,
            verifierReason: confirmed[0].reason,
          };
        }
        return null;
      }),
    );
  },
);

// ── Phase: Synthesize ─────────────────────────────────────────────────────────

phase("Synthesize");

const SEVERITY_ORDER = { Critical: 0, Major: 1, Minor: 2, Nit: 3 };

// Flatten, filter nulls, dedup by file+line+title
const allConfirmed = results
  .flat(2)
  .filter(Boolean)
  .filter((f) => f && f.verified);

const seen = new Set();
const deduped = allConfirmed.filter((f) => {
  const key = `${f.file}:${f.line}:${f.title}`;
  if (seen.has(key)) return false;
  seen.add(key);
  return true;
});

deduped.sort(
  (a, b) =>
    (SEVERITY_ORDER[a.severity] ?? 9) - (SEVERITY_ORDER[b.severity] ?? 9),
);

log(
  `Confirmed findings: ${deduped.length} (from ${DIMENSIONS.length} review dimensions, adversarially verified)`,
);

// Return structured output for the orchestrator
return {
  summary: {
    total: deduped.length,
    bySeverity: {
      Critical: deduped.filter((f) => f.severity === "Critical").length,
      Major: deduped.filter((f) => f.severity === "Major").length,
      Minor: deduped.filter((f) => f.severity === "Minor").length,
      Nit: deduped.filter((f) => f.severity === "Nit").length,
    },
  },
  verdict: deduped.some((f) => f.severity === "Critical")
    ? "block merge"
    : deduped.some((f) => f.severity === "Major")
      ? "fix Majors first"
      : "good to merge",
  findings: deduped,
};
