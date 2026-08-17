---
name: junhao-rewrite
description: Use when rewriting or replacing a substantial codebase or subsystem while preserving or explicitly changing observable behavior, curating a clean incremental Git history, coordinating parallel agents or worktrees, building characterization or differential tests, or invoking --improve commit, --improve batch, or --improve auto. Works from Codex, Claude Code, and other shell-capable agents through host-neutral Git and Claude CLI workflows.
---

# Junhao Rewrite

## Objective

Produce a replacement whose behavior and intentional differences are evidenced
and whose published commit stack reads as an intentional implementation plan.
Keep investigation history useful without making temporary agent work, repair
commits, or session boundaries part of the curated history.

Read [references/rewrite-protocol.md](references/rewrite-protocol.md) before
starting a rewrite. When `--improve` is present, also read
[references/improve-review.md](references/improve-review.md).

## Parse the Invocation

Accept at most one review modifier:

- `--improve commit`: audit each curated commit after its own checks pass.
- `--improve batch`: audit the entire curated range as the last acceptance step.
- `--improve auto`: choose commit or subsystem-boundary audits by risk and always
  run a final range audit.
- No `--improve` modifier: perform the same self-review and validation workflow
  without invoking the external Claude reviewer.

Reject an unknown value or multiple `--improve` modifiers. Record the selected
mode, requested deliverable branch, base, behavior reference, scope exclusions,
remote-mutation authority, and deployment authority before changing anything.

Invocation authorizes local rewrite branches, worktrees, and commits needed for
the curated stack. It does not authorize pushes, pull requests, merges, tags on
a remote, releases, deployments, destructive cleanup, or force-updating a
shared branch. Obtain explicit authority for those operations.

## Non-Negotiable Invariants

1. Distinguish the **target base** from the **behavior reference**. The target
   base is the parent of the new commit stack. The behavior reference is the
   frozen runnable implementation used for comparison. They may be different
   commits, branches, layouts, or unrelated histories.
2. Freeze both identities as full commit SHAs in the rewrite ledger. Never use a
   moving branch name as acceptance evidence.
3. Keep the behavior reference unchanged and runnable. Put adapters outside it
   unless a minimal non-behavioral adapter is unavoidable and documented.
4. Use plain `git worktree` commands and explicit paths. Do not depend on Codex
   thread APIs, Claude's `--worktree` flag, host-managed worktree directories,
   or assumptions about which agent product is running.
5. Give one integration controller authority over `rewrite-work` and
   `rewrite-clean`. Delegates work only on assigned temporary branches or
   worktrees and never publish or rewrite shared history.
6. Preserve user-owned dirty changes. Start from isolated clean worktrees and
   never use destructive reset or checkout commands to make a tree look clean.
7. Treat every curated commit as a deliverable: one coherent idea, its owning
   tests, a stated behavior impact, and the checks appropriate at that point.
8. Keep mechanical changes separate from behavioral changes when practical.
   Do not confuse "small" with "fragmented": a coherent larger commit is better
   than several commits that only make sense together.
9. Integrate and curate continuously. Do not accumulate a forest of corrective
   commits, defer dependency reconciliation, or postpone all testing and history
   cleanup until the end.
10. Apply repository instructions such as `AGENTS.md`, `CLAUDE.md`, contribution
    guides, lint-fix ordering, commit style, and pull-request templates. For new
    frameworks or dependencies, verify current official guidance and compatible
    stable versions instead of relying on model memory.

## Phase 1: Recon and Anchors

1. Locate the Git root, common Git directory, remotes, default branch, current
   status, active worktrees, submodules, and repository instruction files.
2. Read the system boundaries end to end: entry points, public contracts,
   persistence, external effects, tests, build and CI, design decisions, and
   operator or migration documentation.
3. Identify exact build, format/fix, lint, typecheck, unit, integration, E2E,
   schema, migration, generation, and packaging commands. Prefer one staged
   commit-check command, but do not invent a broad command that cannot pass at
   early commits.
4. Resolve and record:
   - `BASE_SHA`: parent of the rewrite stack;
   - `REFERENCE_SHA`: frozen observable-behavior oracle;
   - `WORK_BRANCH`: mutable integration stack;
   - `CLEAN_BRANCH`: curated deliverable stack.
5. Inspect the reference with coverage and representative executions where
   possible. Record facts, decisions, uncertainties, and unavailable evidence
   separately.

Stop before implementation if the target base, behavior reference, or requested
scope cannot be resolved safely.

## Phase 2: Define Behavior and the Commit Stack

Classify rewrite artifacts before creating them:

```text
Durable, committed when they remain useful after the rewrite:
  rewrite/behavior-map.yaml
  rewrite/behavior-differences.yaml
  parity tests, validation scripts, and approved compatibility decisions

Process-only, private Git metadata by default:
  $(git rev-parse --git-common-dir)/junhao-rewrite/commit-plan.md
  $(git rev-parse --git-common-dir)/junhao-rewrite/task-ledger.md
  $(git rev-parse --git-common-dir)/junhao-rewrite/rewrite-log.md
  reviewer finding dispositions and session IDs
```

Record the chosen fate of every artifact in the ledger. Commit process-only
artifacts only when the user explicitly wants rewrite history in the repository;
place them in a clearly internal location, not audience-facing product docs.
This keeps fresh-worktree acceptance reproducible without making untracked
process files violate the clean-status gate.

Build the behavior map from public inputs, outputs, persisted state, files,
events, external calls, error categories, rollback, recovery, authorization,
concurrency, configuration, and migrations. Classify each observed mismatch as
matching, intentionally changed, no longer applicable, or unresolved. Never
normalize a mismatch merely to make parity pass.

Plan semantic, end-to-end commits in dependency order. Each planned commit must
state:

- stable task ID and imperative commit title;
- observable behavior impact;
- base/dependencies and integration order;
- paths and contracts owned, plus explicit exclusions;
- characterization and implementation tests;
- exact validation and expected stage-appropriate result;
- parallel-safety and likely conflict surfaces;
- rollback boundary and any intentional-difference registry entry.

Use a dependency DAG, not a calendar, unless the user asks for scheduling.
Maximize parallelism only among genuinely independent tasks. Do not split a
single framework contract, generated configuration, or dependency decision
across agents merely to increase concurrency.

## Phase 3: Set Up Portable Worktrees

Follow the commands and collision checks in
[references/rewrite-protocol.md](references/rewrite-protocol.md). Create:

- a detached worktree at `REFERENCE_SHA` for behavioral comparison;
- one worktree for the mutable integration branch;
- temporary `rewrite-agent/<slice>` branches and worktrees for independent
  dependency-ready slices;
- the clean branch only as a curated checkpoint, never as an agent workspace.

Keep a task ledger containing the worktree path, branch, exact starting SHA,
dependencies, owned paths, validation commands, and integration status. A host
agent may use native subagents, but their prompts must carry this complete
contract because subagents do not reliably inherit skill or conversation state.

## Phase 4: Implement Behavioral Slices

For each slice:

1. Characterize the relevant reference behavior before replacing it.
2. Decide and register intentional differences before coding against them.
3. Add a focused failing test first when a practical test surface exists.
4. Implement the narrowest complete end-to-end behavior. Avoid speculative
   compatibility, broad abstraction, and unrelated cleanup.
5. Include tests with the behavior they establish; do not create later
   "add tests" repair commits for behavior already published in the stack.
6. Run the repository's formatter or lint auto-fix before the corresponding
   lint check, then run the task's targeted and contract-level gates.
7. Review the uncommitted diff for scope, generated changes, dependency drift,
   secret exposure, and unintended public behavior before committing.
8. Commit a new planned architectural step normally. Correct an earlier planned
   step with `git commit --fixup=<owning-sha>` and record the intended owner.
9. Update the behavior evidence and rewrite journal with facts not already clear
   from code, tests, or the curated commit message.

Delegates must report the exact commit SHA, target planned commit or fixup owner,
files changed, commands and exit statuses, assumptions, unresolved issues, and
whether any external or remote mutation occurred.

## Phase 5: Integrate and Curate Continuously

Integrate only dependency-ready slices. Before integration, confirm that the
slice still starts from its recorded base and that later work has not changed
its contracts. After integration, run targeted tests plus affected cross-slice
contract tests.

Resolve conflicts by semantic ownership. Never choose all of one side because
it is convenient. Re-run the owning slice's tests after every conflict
resolution.

At subsystem boundaries:

1. Preserve the current stack with a uniquely named local backup ref.
2. Autosquash fixups headlessly, then reconstruct any commits that require
   reordering, splitting, or rewording on a disposable curation branch. Do not
   open an interactive editor from an agent or headless shell.
3. Compare pre- and post-curation ranges with `git range-diff`.
4. Prove every curated commit on a disposable validation branch/worktree.
5. Reconcile the task-to-commit ledger. Corrective commits should normally
   disappear into their conceptual owners rather than remain as permanent
   evidence of review timing.

If repeated fixups cross several commits, conflicts recur, or the stack no
longer explains the architecture, replay the affected subsystem from its last
clean checkpoint instead of forcing more patches onto a broken history.

## Phase 6: Run `--improve` Reviews

Use `scripts/improve-review.sh` from this skill to guarantee the reviewer model
`claude-fable-5[1m]`, `xhigh` effort, a read-only permission mode, and a
resumable session. The main agent—not the reviewer—owns implementation.

For every scheduled review:

1. Run the first `/improve` audit and retain its session ID.
2. Open and verify every cited finding yourself. Classify it as accepted,
   rejected with evidence, pre-existing, or out of scope.
3. Address accepted findings in the conceptual owning commit, not in an
   unrelated tail cleanup commit.
4. Re-run affected format/fix, tests, build, parity, and per-commit checks.
5. Write the vetted finding ledger to a non-secret process-only file, then
   resume the same Claude session with `--dispositions <file>` so it can
   challenge rejected findings while re-auditing the updated exact scope.
6. Repeat until the reviewer reports no actionable accepted finding. Never
   treat reviewer agreement as a substitute for local validation.

Mode-specific cadence:

- `commit`: create a new reviewer session for every curated commit; resume that
  session after fixes until the commit is clean.
- `batch`: run after history curation, per-commit validation, and fresh-worktree
  final gates. If it causes code changes, repeat validation and same-session
  review, then run one fresh independent batch session for confirmation.
- `auto`: use commit cadence for security, auth, permissions, persistence,
  migrations, concurrency, public contracts, dependency foundations, external
  side effects, or unusually broad diffs. Use subsystem-boundary batches for
  low-risk scaffolding, mechanical changes, docs, and narrow tests. Always run
  the final `batch` sequence, including a fresh confirmation when fixes were
  made.

If `claude` or the requested model is unavailable, stop the review gate and
report it. Do not silently substitute a model, lower the effort, or claim the
external audit passed.

## Phase 7: Acceptance

From a fresh worktree at the exact clean-branch tip, require evidence that:

- the reference and target base SHAs match the ledger;
- every curated commit passes its stage-appropriate check;
- the final tree passes all required clean-worktree gates;
- critical reference behavior is characterized and compared;
- every mismatch is fixed, approved in the difference registry, or explicitly
  marked no longer applicable;
- error, rollback, recovery, authorization, concurrency, persistence, and
  external-effect paths are covered proportionately to risk;
- `git range-diff` shows no accidentally dropped or displaced behavior;
- the task/commit/evidence ledger is reverse-complete and contains no stale
  branches, claims, paths, or validation results;
- final-audience docs describe the delivered system, not the rewrite process;
- `git status --short` is clean and no unapproved remote or external mutation
  occurred;
- the selected `--improve` gate, if any, converged successfully.

Do not call a final-tree test pass proof of a clean rewrite when intermediate
commits, parity coverage, or the patch-series review remain unverified.

## Handoff

Report the base and reference SHAs, clean branch and tip, commit count and
semantic slices, behavior/parity summary, intentional differences, per-commit
and final validation, `--improve` sessions and dispositions, unresolved risks,
dirty/untracked files, and every remote or external mutation. Do not push or
open a pull request unless explicitly authorized.
