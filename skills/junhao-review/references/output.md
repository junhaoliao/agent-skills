# Review Output

Read this reference before writing a review artifact or emitting inline
annotations.

## Conversation Output

Start every review with a concise walkthrough of intent, before/after behavior,
main flow, tradeoffs, and compatibility. Scale it to the change; one short
paragraph is enough for a simple change. Then present actionable findings in
impact order. A zero-finding review is valid; state residual risk and validation
limits without inventing suggestions.

Classify each item as a blocking defect, non-blocking improvement, design
question, informational note, or pre-existing follow-up. Include:

- Stable finding ID.
- Exact reviewed head and current file/line when applicable.
- Attribution and concrete reachable failure or violated contract.
- Evidence and confidence.
- Impact and scoped remediation.

Do not force positive observations, summary tables, verdicts, or PR titles.
Include them only when requested or materially useful.

## Codex Inline Annotations

When the host supports Codex inline review comments, use one directive per
actionable changed-line finding and keep the visible Markdown self-contained.
Follow the host's current directive schema. A typical directive is:

```text
::code-comment{title="[P1] Preserve the original error" body="Cleanup can throw here and replace the startup failure, so callers lose the causal error. Capture and report cleanup failure without replacing the original exception." file="path/to/file.py" start=42 end=45 priority=1}
```

Use the shortest useful changed-line range. Do not emit a directive for
cross-file context, a question without a requested change, a baseline issue, or
a finding that cannot be anchored to the reviewed diff.

## Code Examples and Suggestions

Use a GitHub `suggestion` fence only when all of these are true:

- The target is one contiguous changed-line range.
- The replacement is exact, syntactically complete, and correctly indented.
- No ellipsis, placeholder, or coordinated change in another file is required.
- The suggestion was rechecked against the final live head.

Use an ordinary language-tagged code fence for examples, alternatives,
multi-file work, missing tests, architectural changes, or code outside the diff.
Explain which parts are illustrative. Never fabricate an applyable replacement
merely to satisfy a format.

## Markdown Artifacts

With `--file`, default to `review-<pr-number>.md`,
`review-<branch-slug>.md`, or `review-uncommitted.md` when the user did not provide
a path. Keep the file untracked unless explicitly asked otherwise.

At minimum include:

```markdown
# Review: <target>

- Repository: `<owner/repo>`
- Base: `<ref> @ <full OID>`
- Head: `<ref> @ <full OID>`
- Working tree: `<clean or baseline summary>`
- Generated: `<timestamp>`

## Findings

### F1 — <classification>: <title>

- Location: `path:line`
- Confidence: high | medium | low
- Evidence: ...
- Impact: ...
- Remediation: ...

## Validation

- `<command>` — passed | failed | skipped: <result or reason>
```

After `--fix`, add statuses such as `fixed locally`, `open`, `superseded`, or
`retracted`, and distinguish the upstream target from the locally fixed tree.
Refresh the artifact only after final validation and re-review.

If an artifact already belongs to the same PR/branch, read it first and update it
in place while preserving user-authored content. Do not overwrite an unrelated
file; choose another name.

## Follow-Up Reviews

Map every prior user-authored thread or stable finding ID to one state:

- Addressed.
- Partially addressed.
- Unaddressed.
- Regressed.
- Outdated because the code moved.
- Retracted because the premise was wrong.

Review the new commit delta for regressions, but also verify the complete current
contract. Do not duplicate a still-live comment or equate GitHub's `resolved`
flag with correctness.
