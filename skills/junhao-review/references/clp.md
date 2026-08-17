# CLP Project Reference

## Detection

Use only for the normalized remote `y-scope/clp` and its Git worktrees.

## Required

- Read the current root `taskfile.yaml`, relevant included Taskfiles, affected
  manifests, PR template, CI, and repository documentation before applying a
  convention.
- Initialize the pinned `tools/yscope-dev-utils` submodule in an isolated review
  worktree before Taskfile validation when it is absent. Never use `--remote`.
- Update tracked generated files only through their generator and inspect the
  complete generated diff.
- Use the current package manager declared by the affected component; the WebUI
  currently uses pnpm rather than npm assumptions from older reviews.
- Treat current Python requirements as authoritative; do not apply historical
  language-version restrictions.

## Established

Verify these patterns against current peer code before making a finding:

- Use `flavour` for CLP package variants and IEC units for binary sizes.
- Python logging generally uses lazy `%` formatting.
- WebUI TypeScript commonly uses `import type`, native `#private` members,
  bottom-of-file exports, and selective Zustand subscriptions.
- Keep changes within the component that owns the behavior unless a lower shared
  component has multiple real consumers.
- Use current y-scope Taskfile ordering, quoting, checksum, and documentation
  conventions from the repository's pinned utility submodule and contribution
  guide.

## Conditional Review Prompts

- For job config, persisted data, schemas, APIs, config, or package defaults,
  trace every C++, Rust, Python, WebUI, database, package, Compose, Helm, and docs
  producer/consumer. Check old stored data, mixed versions, migration, and rollback.
- Distinguish bundled/external service selection, service ports, host-published
  ports, connection config, and telemetry/config forwarding. Verify actual
  consumption before demanding Compose/Helm parity.
- Trace editable, submitted, snapshotted, persisted, and displayed values across
  WebUI and backend workflows.
- Preserve the original failure when startup or job execution fails and cleanup
  also fails. Verify timeout and cancellation paths update durable status.
- For Helm, trace parent/subchart values, `global` values, merge rules, `tpl`
  evaluation context, secrets, generated config, chart versions, and image tags.
- For shared serialization, place the codec at the lowest common owner and prove
  round trips for every writer and reader rather than passing opaque contexts
  through unrelated layers.

## Validation Routing

Use the current Taskfiles as source of truth. In read-only review mode, prefer
the relevant check commands:

| Surface | Check | `--fix` counterpart |
|---|---|---|
| TypeScript/WebUI | `task lint:check-js` | `task lint:fix-js` |
| Python | `task lint:check-py` | `task lint:fix-py` |
| Rust | `task lint:check-rust` | `task lint:fix-rust` |
| C++ diff | `task lint:check-cpp-diff` | `task lint:fix-cpp-diff` |
| Broad C++ | `task lint:check-cpp-full` | `task lint:fix-cpp-full` |
| YAML/Taskfile | `task lint:check-yaml` | `task lint:fix-yaml` |
| Broad lint | `task lint:check` | `task lint:fix` |

Relevant tests currently include:

- C++ core: `task tests:integration:core`.
- Package: `task tests:integration:package`.
- Python imports: `task tests:integration:clp-py-project-imports`.
- Rust: `task tests:rust-all`.
- Broad integration: `task tests:integration`.

Normal code changes may require the root `task` build. Package behavior may need
the built package smoke path; always stop task-created services even after a
failure. Docs and WebUI review may require a served-page/browser check after the
normal automated command.
