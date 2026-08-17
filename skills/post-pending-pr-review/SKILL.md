---
name: post-pending-pr-review
description: >
  Prepare, create, or update an unsubmitted GitHub PENDING pull-request review
  with concise diff-safe inline comments and applyable suggestions while
  preserving existing comments and user edits. Use for requests to post,
  prepare, regenerate, merge, or update a pending PR review on the live head.
---

# Post a pending PR review

Create or update a GitHub review without submitting it. Use the bundled helper
for snapshotting, validation, guarded mutation, and verification; do not rewrite
that transaction as ad hoc shell.

## User invocation

Prepare without posting:

```text
$post-pending-pr-review https://github.com/owner/repo/pull/123
```

Post immediately as an unsubmitted draft:

```text
$post-pending-pr-review https://github.com/owner/repo/pull/123 --run
```

Treat natural-language authorization such as "post it" as `--run`. Invoking the
skill without posting authorization means prepare, summarize, and wait. Never
submit the review.

Resolve the target in this order:

1. Explicit PR URL or number and `--repo owner/repo`.
2. One unambiguous PR already established in the conversation.
3. The PR associated with the current branch.
4. Ask when more than one target is plausible.

## Dependencies

Require Bash, `gh`, and `jq`; do not require Python. Require `gh` authentication
with pull-request write access. Infer a GitHub Enterprise hostname from an
explicit URL when applicable.

Set the helper path from this skill's directory:

```bash
HELPER="<skill-directory>/scripts/pending-review.sh"
```

## Invariants

- Treat GitHub as the source of truth for the PR head and pending review.
- Preserve applicable user-edited body text and comments exactly.
- Do not restore comments the user deleted unless the request reintroduces them.
- Never delete another user's review.
- Never post against a head or pending-review snapshot that changed.
- Omit `event`; `PENDING` is a response state, not an event value.
- Validate every inline target before mutating GitHub.
- Keep all working files outside the repository and remove them afterward.

## Workflow

### 1. Snapshot live GitHub state

Create a temporary working directory and snapshot the live head, final file
patches, authenticated viewer, and the viewer's complete pending review:

```bash
REVIEW_WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pending-review-work.XXXXXX")"
trap 'rm -rf -- "$REVIEW_WORK_DIR"' EXIT HUP INT TERM

bash "$HELPER" snapshot \
  --repo "owner/repo" \
  --pr "123" \
  --output "$REVIEW_WORK_DIR/snapshot.json"
```

Add `--hostname <host>` for GitHub Enterprise. The helper paginates files,
reviews, comments, and GraphQL review threads and records a canonical pending-
review fingerprint.

Use `files[].patch` from the snapshot for final base-to-head mapping. Do not use
per-commit patches. If a required patch is absent or truncated, do not guess an
inline target.

Fetch raw RIGHT-side content only for relevant non-removed files:

```bash
gh api \
  -H 'Accept: application/vnd.github.raw+json' \
  "repos/owner/repo/contents/path/to/file?ref=refs/pull/123/head"
```

Recheck every earlier finding against this live content.

### 2. Merge the pending review

Read `snapshot.json` before composing the new payload. Begin with the applicable
existing `pending.body` and `pending.comments`, then merge the new findings.

- Preserve current wording by default.
- Remove a finding only when fixed, intentionally deleted, superseded, or
  explicitly excluded by the request.
- If the current content conflicts materially with the request and intent is
  unclear, ask before overwriting it.
- Match prior generated artifacts against GitHub to recognize user edits and
  deletions; never rebuild from stale local text.

### 3. Compose one finding per concern

Classify each finding:

- **Inline suggestion:** the smallest replaceable RIGHT-side range is within one
  final diff hunk.
- **Inline comment:** a semantically relevant changed line can host the concern,
  but an applyable replacement is not appropriate.
- **Review-body item:** the target is outside the diff, crosses hunks, or needs
  coordinated changes in several locations.

When the user requests everything inline, a file-wide concern may use a nearby
semantically relevant changed line as an ordinary comment and clearly state its
scope. Never attach a `suggestion` fence to an unrelated line. If no honest
inline anchor exists, keep the item in the review body and explain why.

Keep independent correctness, security, portability, performance,
documentation, and style concerns separate. Do not create overlapping
suggestions. Use lowercase first letters, no emoji, and fewer than 500 prose
characters when practical.

### 4. Build and validate the payload

Write a JSON payload in the temporary directory:

```json
{
  "commit_id": "<snapshot head_sha>",
  "body": "review summary or coordinated out-of-diff findings",
  "comments": [
    {
      "path": "path/to/file",
      "line": 42,
      "side": "RIGHT",
      "body": "concise rationale with one applyable suggestion"
    }
  ]
}
```

Put the `suggestion` fence and replacement inside the comment body. For a
multi-line range, also set `start_line` and `start_side: "RIGHT"`. Both ends
must be in one final hunk. The suggestion must replace exactly the selected
range. Use ordinary code fences, never `suggestion`, in the review body.

Validate before any GitHub mutation:

```bash
bash "$HELPER" validate \
  --snapshot "$REVIEW_WORK_DIR/snapshot.json" \
  --payload "$REVIEW_WORK_DIR/payload.json"
```

Validation rejects stale heads, missing patches, removed RIGHT-side files,
out-of-hunk ranges, malformed multi-line ranges, review-body suggestions, and
overlapping inline suggestions. Move unresolvable items to the review body and
validate again.

### 5. Pause or post

Without `--run`, report the head SHA, pending-review preservation status, review
body summary, inline-comment count, and validation result. Do not leave a helper
or payload in the repository. On later authorization, take a fresh snapshot and
merge again.

With posting authorization, apply the validated payload:

```bash
bash "$HELPER" apply \
  --snapshot "$REVIEW_WORK_DIR/snapshot.json" \
  --payload "$REVIEW_WORK_DIR/payload.json" \
  --run
```

The helper:

1. Rechecks the authenticated user and live head.
2. Recomputes the pending-review fingerprint and aborts before mutation if the
   body or any comment changed.
3. Updates body/comment text in place when locations are unchanged.
4. Replaces the pending review only when comment topology changed.
5. Attempts to restore the original pending review if replacement creation
   fails after deletion.
6. Re-reads GraphQL thread data because REST often returns null line fields for
   pending comments.
7. Requires the final review to be owned by the snapshot viewer, remain
   `PENDING`, target the expected head, and exactly match the validated body and
   comments.

If the helper reports changed state, take a new snapshot, merge the latest user
state, revalidate, and retry. Do not bypass the guard.

### 6. Report the result

Report the review URL, state, head SHA, mutation type, and comment count. State
explicitly that the review was not submitted.

## Anti-patterns

- Generating another one-off posting script instead of using the helper.
- Using `gh api --jq --arg`; pipe to standalone `jq` when variables are needed.
- Redirecting plain paginated JSON arrays into one file without slurping them.
- Fetching RIGHT-side contents for removed files.
- Posting stale findings after the PR head changed.
- Rebuilding from a local artifact without reading the live pending review.
- Restoring comments the user deleted or overwriting edited wording.
- Deleting all pending review IDs without verifying ownership and uniqueness.
- Setting `event: "PENDING"` or submitting the review.
- Treating null REST line fields as failed posting without GraphQL verification.
- Leaving `pr-review.sh`, payloads, snapshots, or other generated artifacts in
  the repository.
