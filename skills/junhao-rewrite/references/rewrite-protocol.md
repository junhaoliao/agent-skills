# Rewrite Protocol Reference

## Contents

1. Git identities and branch model
2. Portable worktree setup
3. Task and commit contracts
4. History curation and validation
5. Behavioral evidence
6. Parallel integration rules
7. Failure lessons encoded by this skill

## 1. Git Identities and Branch Model

Keep these identities distinct:

| Identity | Meaning |
| --- | --- |
| `BASE_SHA` | Exact parent of the new commit stack |
| `REFERENCE_SHA` | Frozen runnable implementation used as a behavior oracle |
| `WORK_BRANCH` | Mutable integration stack; fixups and temporary commits allowed |
| `CLEAN_BRANCH` | Curated delivery stack; every commit independently valid |
| `rewrite-agent/<slice>` | Temporary isolated implementation branch |

The behavior reference may not descend from the target base. Never use
`REFERENCE_SHA` as the rebase base unless it is also deliberately the target
base. Parity compares two trees; history curation operates only on
`BASE_SHA..WORK_BRANCH`.

Record full SHAs, not only names:

```sh
repo_root=$(git rev-parse --show-toplevel)
base_sha=$(git rev-parse --verify '<target-base>^{commit}')
reference_sha=$(git rev-parse --verify '<behavior-reference>^{commit}')
```

Resolve the default branch without assuming `main`:

```sh
default_ref=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD || true)
```

If it is unavailable, inspect remotes and repository documentation. Do not
guess between `main`, `master`, and a release branch.

## 2. Portable Worktree Setup

Use Git directly so the same procedure works under Codex, Claude Code, a shell,
or another agent host.

Choose an explicit worktree root outside the checked-out tree. A sibling path is
usually easiest to inspect and remove later:

```sh
repo_root=$(git rev-parse --show-toplevel)
repo_name=$(basename "$repo_root")
worktree_root=$(dirname "$repo_root")/."$repo_name"-rewrite-worktrees
mkdir -p "$worktree_root"
git worktree list --porcelain
```

Validate that the selected directory does not contain user data before adding
worktrees. Never recursively delete an unresolved or broad path.

Create a detached reference worktree and explicit branches:

```sh
git worktree add --detach "$worktree_root/reference" "$reference_sha"
git branch rewrite-work "$base_sha"
git worktree add "$worktree_root/work" rewrite-work
git branch rewrite-clean "$base_sha"
```

If a branch already exists, inspect its SHA, worktree, reflog, and ownership;
never force-move it during setup. Use user-selected names when provided.

Create an agent slice only after its dependencies are integrated:

```sh
slice=server-auth
slice_base=$(git rev-parse rewrite-work)
git branch "rewrite-agent/$slice" "$slice_base"
git worktree add "$worktree_root/agent-$slice" "rewrite-agent/$slice"
```

Do not use product-owned conventions such as `~/.codex/worktrees`, Claude
`--worktree`, task IDs, or hidden host state. Native host subagents may operate
inside these Git-created paths.

## 3. Task and Commit Contracts

Every planned commit should have a ledger entry like:

```markdown
## RW-012 — Add persisted deployment requests

- Title: `feat(deployments): persist deployment requests`
- Behavior: preserves request validation; intentionally changes retry identity
- Base: RW-006, RW-009
- Owns: `server/deployments/**`, deployment persistence tests
- Excludes: scheduler execution, UI, cloud provider calls
- Reference scenarios: DEP-CREATE-01..08
- Tests: named unit and integration cases
- Gates: exact commands with expected stage result
- Parallel safety: conflicts with RW-013 on the deployment schema
- Rollback: remove new route and collection/index together
```

Agent handoffs must include:

```text
Task ID and intended commit title
Branch, worktree, and exact starting SHA
Dependencies already integrated
Owned paths and explicit exclusions
Reference behaviors and approved differences
Commands to run, including lint auto-fix ordering
Permission boundary: local only; no push, PR, merge, release, or deployment
Required output: commit/fixup SHA, diff summary, validation exits, assumptions,
unresolved issues, and external mutations
```

Session boundaries and agent boundaries are not commit boundaries. One agent may
produce multiple planned commits; several agents' hunks may belong in one
curated commit if they implement one inseparable contract.

## 4. History Curation and Validation

Use fixups for corrections to earlier conceptual owners:

```sh
git commit --fixup=<owning-commit-sha>
```

Before rewriting history, save a uniquely named local backup ref:

```sh
backup="rewrite-backup-$(date -u +%Y%m%dT%H%M%SZ)"
git branch "$backup" rewrite-work
```

Autosquash from the target base, not the behavior reference. Supply a no-op
sequence editor so the command is headless and behaves the same from Codex,
Claude Code, CI, or a terminal without an editor:

```sh
git switch rewrite-work
GIT_SEQUENCE_EDITOR=: GIT_EDITOR=: git rebase -i --autosquash "$base_sha"
```

This folds correctly named fixup commits without prompting. Do not try to encode
complex reordering, splitting, or rewording in an ad-hoc `sed` sequence-editor
command. Instead, reconstruct the affected portion on a disposable curation
branch from `BASE_SHA` or the last clean subsystem checkpoint:

```sh
git branch rewrite-curation "$base_sha"
git worktree add "$worktree_root/curation" rewrite-curation
```

In the curation worktree, cherry-pick already coherent commits in the planned
order. For a commit that must be split, use `git cherry-pick --no-commit`, stage
one semantic portion at a time, run its checks, and commit it with its intended
message. Abort and return to the saved backup ref if ownership or behavior is
unclear. Never run an interactive editor in an unattended agent workflow.

The curated result must:

- order commits by real dependency;
- fold each fixup into its conceptual owner;
- move tests into the behavior commit they validate;
- separate pure moves/renames from behavior when it improves reviewability;
- split commits with unrelated rollback or review boundaries;
- combine fragments that cannot build or be understood alone;
- make every message explain behavior impact.

Compare the old and curated series:

```sh
git range-diff "$base_sha..$backup" "$base_sha..rewrite-work"
```

Validate every commit on a disposable branch or worktree so a failure does not
strand the authoritative integration branch. One approach:

```sh
validation_branch="rewrite-validation-$(date -u +%Y%m%dT%H%M%SZ)"
git branch "$validation_branch" rewrite-work
git worktree add "$worktree_root/validation" "$validation_branch"
```

Then, in the validation worktree:

```sh
git rebase --exec './scripts/check-commit.sh' "$base_sha"
```

Use the repository's real stage-aware command instead of the example when
early commits intentionally do not contain all final packages. After success,
point `rewrite-clean` at the exact curated tip only if the branch is local and
not checked out elsewhere. Never force-update a shared or published branch.

Run final gates from a separate fresh worktree at the clean tip with locked
dependencies and caches disabled where practical. Record actual exit statuses
and exact relevant diagnostics; a narrow pass cannot override a broad failure.

### Artifact lifecycle

Keep durable compatibility evidence in the curated repository when future
maintenance depends on it: behavior maps, approved differences, parity tests,
and validation scripts. Give their introduction an explicit planned commit.

Keep mutable process state in the common Git directory by default:

```sh
rewrite_state=$(git rev-parse --path-format=absolute --git-common-dir)/junhao-rewrite
mkdir -p "$rewrite_state"
```

The commit plan, task ledger, rewrite journal, reviewer dispositions, and session
IDs live there unless the user explicitly asks to preserve rewrite history in
the repository. If preserved, use a clearly internal path and define whether it
remains in the final tree. Never put internal lineage into user or operator docs.

## 5. Behavioral Evidence

The behavior map should inventory scenarios rather than old source files:

```yaml
areas:
  - id: task-creation
    boundary: HTTP API
    scenarios:
      - id: valid-title
        risk: normal
      - id: duplicate-title
        risk: persistence-concurrency
      - id: persistence-failure
        risk: rollback
```

The intentional-difference registry should be centralized:

```yaml
differences:
  - id: task-title-whitespace
    area: task-creation
    reference_behavior: Preserves surrounding whitespace
    rewrite_behavior: Trims before validation
    reason: Prevent visually duplicate tasks
    compatibility_impact: Existing clients observe normalized titles
    migration_required: false
    approved: true
    tests:
      - task-create-whitespace-new-contract
```

Compare public results and relevant state:

- return value, status, exit code, and error category;
- database, filesystem, and cache state;
- emitted events and messages;
- external calls and idempotency keys;
- rollback and partial-failure behavior;
- restart, retry, ordering, and concurrency outcomes.

Normalize only unspecified nondeterminism such as generated IDs, timestamps,
temporary paths, or unordered sets. Review normalization like production code.

## 6. Parallel Integration Rules

Schedule only dependency-ready work. Two tasks are parallel-safe when they do
not share a contract decision, generated artifact, lockfile ownership, schema,
central configuration, or the same high-churn files.

Use one explicit owner for cross-cutting surfaces such as:

- dependency versions and lockfiles;
- root workspace/build orchestration;
- public API schemas and generated clients;
- persistence schemas and migrations;
- authentication and authorization policy;
- shared UI registry configuration;
- release and deployment workflows.

Integrate small batches continuously. After each batch:

1. verify recorded starting SHAs and dependencies;
2. inspect every diff and commit message;
3. integrate in dependency order;
4. run targeted and cross-contract tests;
5. update the task/commit/evidence ledger;
6. curate fixups before dispatching work that depends on changed commit IDs.

If commit IDs change after autosquash, update all active task contracts or pause
dispatch until agents are rebased onto the new exact integration tip.

## 7. Failure Lessons Encoded by This Skill

The following rules come from a large rewrite that eventually passed extensive
gates but accumulated 144 commits, numerous corrective commits, overlapping
agent work, dependency-order mistakes, stale documentation claims, and
unintended pull-request publication:

1. **Centralize publication authority.** A delegate may prepare a local commit
   or PR description, but never infer permission to push or open a PR from the
   rewrite request or from another agent's publication.
2. **Own dependency foundations once.** Framework templates, component systems,
   runtime versions, lockfiles, and generated configuration must land through
   one dependency-ordered task. Parallel branches must consume that decision,
   not independently choose versions.
3. **Prefer semantic review units over maximal branch count.** "One thing" means
   one independently understandable behavior or architectural contract, not one
   file, test, or configuration fragment.
4. **Continuously compile the patch stack.** Review findings should become
   fixups and be autosquashed promptly. A final ledger full of "corrective"
   commits proves late review, not clean incremental history.
5. **Keep internal and audience documentation separate.** Rewrite lineage,
   parity sources, branch SHAs, and agent decisions belong in the rewrite log.
   Product design and user docs must describe the delivered system directly.
6. **Make current-state claims executable.** Status tables, task mappings,
   architectural diagrams, and docs must be checked against code and tests.
   Never mark work done because a branch or agent reported it.
7. **Audit contracts across every representation.** A lifecycle or API decision
   can appear in code, schema, diagrams, prose, task criteria, guides, and
   tests. Search all representations after a decision changes.
8. **Do not optimize parallelism past integration capacity.** Account for
   review, conflicts, shared contracts, and curation. Dispatching every apparent
   leaf at once increases stale bases and corrective work.
9. **Use current official manuals for new foundations.** Later discovery of an
   incompatible template, UI primitive, or dependency combination can invalidate
   several otherwise clean branches.
10. **Review before and after integration.** Self-review uncommitted work,
    validate the integrated batch, and use an independent final audit. No single
    review perspective is sufficient.
