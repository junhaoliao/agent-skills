# Review Principles

Use this reference for design-focused, architecture-heavy, or cross-cutting
reviews. Treat every item as a reasoning lens, not a source of automatic
findings. Current repository evidence always wins.

## Contract Ownership

- Identify the authoritative owner of every contract, default, configuration
  value, lifecycle state, and generated artifact.
- Prefer changing the owner and consuming it directly over pass-through aliases,
  duplicated constants, parallel config paths, or call-site patches.
- Move behavior into a shared package only when ownership is genuinely shared;
  deduplicating one use is not sufficient.
- Ensure dependency direction points toward the stable owner rather than making
  a lower layer import startup, UI, or deployment code.

Questions to answer:

- Can two representations drift?
- Which component validates the invariant?
- Can a consumer bypass the authoritative path?
- Is generated output changed through its generator?

## Smallest Direct Design

- Compare the proposal with sibling code and applicable current reference
  implementations.
- Keep a helper, option, injection seam, wrapper, manager, or context type only
  when it enforces an invariant, serves multiple live consumers, or separates a
  real ownership/lifecycle boundary.
- Prefer direct arguments and established factories over one-use carrier types.
- Avoid speculative variants, generic hooks, dependencies, and configuration
  without a demonstrated current need.
- Preserve a small guided API for common behavior; retain native/raw escape
  hatches only when advanced users have a real use case.

Do not confuse fewer lines with simpler behavior. Prefer the shape whose success,
failure, interruption, and cleanup paths are easiest to verify.

## Behavior-Preserving Changes

For moves, refactors, dependency migrations, and build-system rewrites:

- Inventory the old behavior before judging the new structure.
- Verify every supported mode and prove content equivalence for files claimed to
  be moved unchanged.
- Separate build, staging/bundling, packaging, and deployment responsibilities.
- Check clean execution, immediate cached rerun, tampered output, and changed
  input when cache behavior changes.
- Treat compilation or lint success as structural evidence, not proof of runtime
  equivalence.

Keep literal renames within their semantic layer. Distinguish display text,
domain terminology, identifiers, filenames, config keys, and public APIs before
propagating a rename.

## Lifecycle and State

Trace state over time:

- Configured, editable, submitted, snapshotted, and persisted values.
- Initialization, partial startup, ready state, mutation, retry, cancellation,
  shutdown, and cleanup.
- Primary failure versus cleanup failure; cleanup must not mask the original
  error.
- Resource ownership and disposal for processes, workers, WASM objects,
  connections, tasks, locks, and telemetry providers.
- Old/new mixed-version state and rollback after persistence changes.

Require names to expose meaningful lifecycle distinctions. Do not collapse an
editable value and an active submitted value merely because their types match.

## Cross-Surface Contracts

For APIs, schemas, persisted formats, protocols, queries, config, dependencies,
images, and deployment contracts, map:

| Surface | Questions |
|---|---|
| Producers | Who writes, serializes, generates, or submits it? |
| Transformation | Which parser, template context, merge rule, encoder, or workflow changes it? |
| Consumers | Who reads, renders, executes, or deploys it? |
| Defaults | What do absent, null, zero, empty, and sentinel values mean? |
| Persistence | Can old data be read? Is migration or rollback required? |
| Variants | Do all supported databases, platforms, architectures, and runtimes work? |
| Operations | Do Compose, Helm, CI, packaging, docs, and upgrade instructions agree? |

Validate actual consumption before demanding superficial parity. A value being
present in two deployment systems does not prove both runtime paths use it.

## Failure and Trust Boundaries

- Preserve the first causal error while attempting best-effort teardown.
- Reject stale artifacts after failed builds when they could be mistaken for
  current output.
- Trace retries, timeouts, backpressure, cancellation, and status/metadata
  updates together.
- Separate runtime credentials from migration or administration privileges.
- Check TLS identity, IAM/OIDC subject scope, secret exposure, retained-resource
  lifecycle, and input validation at each trust boundary.
- Review portable contracts against every supported implementation rather than
  copying a vendor-specific helper.

## Naming and Organization

- Derive names from domain types, sibling APIs, process names, user-facing terms,
  and terminology across code, config, deployment, logs, tests, and docs.
- Omit a qualifier that only describes the normal case unless a contrasting
  variant exists.
- Avoid a file and directory with the same conceptual name when ownership becomes
  ambiguous.
- Keep cohesive implementation colocated. Split only for a public boundary,
  independent lifecycle, independent ownership, or multiple real consumers.
- Recommend a rename only when it removes an evidenced inconsistency or makes an
  invariant/lifecycle distinction clearer.

## Tests and Validation

- Assert observable contracts, important boundaries, and failure semantics.
- Avoid generated logical IDs, incidental call counts, helper structure, exact
  internal sequencing, and speculative negative assertions.
- Reuse the established test surface before creating a new harness, package,
  module, or dependency.
- Reproduce a reported bug at the highest practical layer matching the report.
  A lower-level mechanism is not equivalent to an end-to-end failure unless the
  equivalence is demonstrated.
- Keep a failing required gate visible until the same affected surface passes on
  the final tree.

## External Tools and Dependencies

- Verify behavior against the pinned version, current official documentation or
  source, and a focused reproduction when practical.
- Separate an official recommendation from a runtime requirement.
- Choose the newest stable mutually compatible dependency set, considering
  engine/peer ranges and repository release/security policy.
- Inspect lock changes for unrelated resolution churn and verify with a frozen or
  locked install.
