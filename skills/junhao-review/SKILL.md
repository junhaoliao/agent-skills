---
name: junhao-review
description: Review pull requests, branches, commits, or local changes in Junhao's repository style with evidence-backed findings, architecture and ownership analysis, exact base/head targeting, thread-aware follow-up review, repo-specific conventions, optional local fixes, and Codex inline annotations. Use when asked to review code, explain a change, check whether prior review comments were addressed, or apply safe review fixes.
---

# Junhao Review

Review the exact requested change, prove findings before presenting them, and
prefer ownership, lifecycle, contract, and maintainability analysis over
low-signal style commentary. A thorough review may have zero findings.

## Invocation

Resolve the target from the invocation or current review context. Ask only when
the target is materially ambiguous.

| Target | Meaning |
|---|---|
| PR URL or number | Review the PR's live base and head object IDs |
| `branch` | Review the current branch against its merge base |
| `<ref>` | Review the named ref without changing the user's checkout |
| `uncommitted` | Review staged, unstaged, and relevant untracked files |

Supported modes:

| Mode | Meaning |
|---|---|
| `--fix` | Apply evidence-backed, unambiguous fixes locally; never stage, commit, or push |
| `--base <ref>` | Override the base for non-PR targets; a PR's actual base always wins |
| `--file [path]` | Write or refresh a local Markdown review artifact |
| `--inline` | Emit host-native inline annotations for actionable changed-line findings |
| `--diagrams` | Include a small diagram only when it materially clarifies the change |

Accept legacy `--no-file` as the default conversation-only behavior. Focus terms
such as `security`, `breaking-changes`, `correctness`, `tests`, `style`, or
`design` reprioritize the review but do not suppress other blocking findings.

## Authority and Baseline

Default to read-only review. At the start, record:

- Git root, normalized remote, and dirty state.
- Target kind, base/head object IDs, merge base, and reviewed paths.
- User constraints, requested non-edits, output mode, and granted mutations.
- Existing review artifact that must be preserved.

`--fix` authorizes only task-owned local edits. Explicit prose authorizes only
the named actions.

Authority is non-transitive. Review helpers remain read-only. Never reset, clean,
overwrite, or include unrelated user changes.

## Resolve the Exact Target

### Pull requests

1. Read the PR's `baseRefName`, `baseRefOid`, `headRefName`, `headRefOid`, body,
   commits, changed files, linked issue, CI state, and review discussions.
2. Treat the base/head object IDs as authoritative; branch names are
   informational. A detached checkout at the exact head is valid.
3. Fetch or inspect those exact objects. If builds, tests, or fixes require a
   materialized checkout, use an existing matching clean worktree or a disposable
   worktree. Do not switch or pull the user's shared checkout merely to review.
4. Compare the exact PR base to its exact head. Do not default a PR to
   `origin/main`, including for stacked PRs.

Read thread-level review state when available, including unresolved, resolved,
and outdated threads. Do not treat a resolved thread as proof that its concern
was fixed.

### Branches and named refs

Resolve the head object without checking it out. Use the user-provided base,
otherwise the repository's default branch, and record the merge base. Inspect
the complete merge-base diff rather than inferring branch scope from `git status`.

### Uncommitted changes

Inspect each surface once:

```bash
git diff
git diff --cached
git ls-files --others --exclude-standard
```

Read relevant bounded untracked files, especially when tracked files import or
reference them. Do not expose secrets or inspect unrelated large/generated files.
Exclude any review artifact created by this invocation from the reviewed change.

Before final output or fixing, re-read the live head. If it moved,
recompute the affected diff, evidence, tests, and line anchors.

## Load Current Repository Evidence

Read the current repository's `AGENTS.md`, `CLAUDE.md`, contribution guides,
manifests, configured linters/formatters, CI, and representative peer code before
applying historical conventions. Normalize the remote to an exact `owner/repo`
slug and read the matching reference:

| Exact repository | Reference |
|---|---|
| `y-scope/clp` | `references/clp.md` |
| `y-scope/clp-ffi-js` | `references/clp-ffi-js.md` |
| `y-scope/clp-plugin-presto-connector` | `references/clp-plugin-presto-connector.md` |
| `y-scope/spider` | `references/spider.md` |
| `y-scope/yscope-docs` | `references/yscope-docs.md` |
| `y-scope/yscope-log-viewer` | `references/yscope-log-viewer.md` |
| `y-scope/yscope-dev-utils` | `references/yscope-dev-utils.md` |

Interpret project guidance by authority:

- **Required:** current repository instructions or configured tooling.
- **Established:** repeated current peer-code convention; verify before using.
- **Conditional:** a risk prompt requiring case-specific evidence.

Current repository evidence overrides every bundled reference. For cross-repo
contracts, inspect the related repository read-only and load its reference only
for the shared interface. If required tooling depends on an absent pinned
submodule, initialize only that submodule in the isolated review worktree; never
use `--remote` unless reviewing a submodule revision update.

## Build the Change Model

Read the full changed files plus relevant callers, callees, tests, configuration,
generated outputs, deployment wiring, documentation, and sibling implementations.
Summarize internally:

- Intent and user-visible outcome.
- Before and after behavior.
- Inputs/producers, transformations or evaluation context, and consumers/outputs.
- State owner, lifecycle, cleanup, and failure paths.
- Trust, credential, persistence, and deployment boundaries.
- Supported variants, defaults, sentinels, compatibility, migration, and rollback.

For persisted formats, schemas, APIs, config contracts, generated interfaces,
images, workflows, or dependencies, inventory every writer, reader, stored-data
path, old/new mixed-version interaction, UI/package/Compose/Helm/CI/docs surface,
and migration path. Classify the change as compatible, migration-required, or
intentionally breaking.

Use `references/review-principles.md` for a design-focused or cross-cutting
review. Expose a concise change walkthrough before findings in every review,
covering intent, before/after behavior, main flow, tradeoffs, and compatibility.
Scale it to the change; one short paragraph is enough for a simple change. Use a
diagram only when prose is materially less clear.

## Gate Candidate Findings

Retain a finding only when it passes all four gates:

1. **Attribution:** the target introduced or materially worsened it.
2. **Reachability:** a concrete execution, data, lifecycle, or user sequence
   reaches the problem.
3. **Evidence:** current code, a repository contract, focused reproduction,
   exact-head CI, or authoritative version-matched documentation supports it.
4. **Actionability:** the author can reasonably address it in this change.

Try to falsify every candidate. Search for guards, callers, supported policy,
existing tests, counterexamples, and unchanged baseline behavior. For framework,
platform, dependency, container, or orchestration semantics, verify the pinned
version with current official documentation or source and, when practical, a
focused reproduction. Distinguish observed fact, documented fact, and inference.

Omit a disproven concern. Downgrade uncertain intent or policy to a question.
Place valid pre-existing or other-PR concerns in a separate follow-up note rather
than attributing them to the reviewed change.

Prioritize findings in this order:

1. Correctness, data integrity, security, and privacy.
2. Public contracts, persistence, compatibility, migration, and rollback.
3. Lifecycle, concurrency, cancellation, cleanup, and failure semantics.
4. Architecture, ownership, dependency direction, and maintainability.
5. Required tests, builds, generated outputs, and deployment validation.
6. Naming, documentation, and style backed by current repository evidence.

Style may block only when it violates a required gate or changes semantics.

## Architecture and Maintainability Lenses

- Identify one authoritative owner for each contract, default, config value,
  lifecycle state, and generated artifact. Flag competing sources of truth.
- Preserve an established module boundary unless extraction creates cohesive
  ownership, serves multiple real consumers, or enforces an important invariant.
- Prefer the smallest direct design. Do not request one-use wrappers, context
  objects, manager files, generic hooks, dependencies, or test infrastructure
  without demonstrated need.
- Centralize genuinely shared serialization, lifecycle, or policy behavior at
  the lowest common owner rather than threading opaque context through callers.
- Prefer explicit states and discriminators over map ordering, sentinel tricks,
  or implicit first-key conventions. Validate invalid combinations.
- Trace mutable versus snapshotted state and ensure names expose meaningful
  lifecycle differences.
- Make success, failure, interruption, retry, and cleanup paths easy to verify;
  cleanup must not mask the original failure.
- Review public interfaces against every stated supported variant, not only the
  currently pinned implementation.
- Derive names from domain types, sibling APIs, and terminology across code,
  config, deployment, tests, and docs. Do not make taste-only rename findings.
- Require tests to assert observable contracts and failure semantics, not
  generated IDs, incidental helper structure, or speculative exclusions.

## Validate Proportionally

Use project-native commands for the affected surface. In read-only review mode,
run check-only lint, focused tests, builds, rendering, or reproductions; do not
run a fixer that changes the tree. Record command, working directory, exact head,
exit status, and covered surface. A skipped job or narrower pass does not prove a
broader required gate.

Inspect generated-file and lockfile diffs for unrelated churn. For dependency
changes, verify the newest stable mutually compatible versions, engine/peer
ranges, release/security policy, targeted lock regeneration, and frozen install.

## Apply `--fix`

Freeze the pristine target and candidate findings first. Apply without another
selection prompt only fixes that are evidence-backed, task-owned, and free of
unresolved product or architecture choices. Ask before changing public behavior,
APIs, schemas, persistence, migration, security policy, dependency strategy, or
architecture unless the requested intent makes the answer unambiguous.

Snapshot the dirty baseline. Run the repository's targeted auto-fixer before
manual lint cleanup, inspect every resulting change, and keep unrelated files
untouched. Re-run affected validation and review the complete final diff.
Distinguish the upstream target from the locally fixed tree and classify each
finding as `open`, `fixed locally`, `superseded`, or `retracted`.

Never stage, commit, or push under `--fix` alone.

## Delegate by Risk Surface

Delegate only genuinely independent review surfaces, such as persistence,
deployment, security, tests, or dependency policy. Keep coupled producer and
consumer paths together. Give every helper the same immutable base/head IDs,
owned review surface, and read-only constraint.

Helpers return candidate findings with evidence and confidence. The parent
independently verifies every accepted finding on the final head, deduplicates
overlap, and remains the sole writer and fixer.

## Output

Start with the concise change walkthrough, then return findings in impact order.
When Codex inline annotations are available or `--inline` was requested, emit one
annotation per actionable changed-line finding and keep the visible response
useful on its own. Read `references/output.md` before writing a file or inline
annotations.

Every finding must include:

- Stable ID and blocking or non-blocking classification.
- Confidence and exact current-head file/line location when one exists.
- Concrete failure or violated contract, evidence, impact, and remediation.

Use an applyable `suggestion` block only for an exact, syntactically complete,
contiguous replacement with verified indentation. Use prose or an ordinary code
example for cross-file, architectural, removal, or missing-test findings.

Do not manufacture findings, praise, tables, verdicts, diagrams, or title
suggestions. Include them only when useful or requested. If there are no
actionable findings, say so and report material validation limits.

With `--file`, update the branch/PR-stable artifact in place after the final
review, preserving user edits.

## Completion Gate

Before final delivery:

- Recheck that the live head and intended base are unchanged.
- Verify each retained finding and inline anchor against that exact head.
- Remove duplicate, stale, disproven, baseline, or already-addressed findings.
- Report validation passes, failures, skips, and uncertainty accurately.
- Recheck local dirty state and disclose every task-owned mutation.
- Report any artifact path.
