# Spider Project Reference

## Detection

Use only for the normalized remote `y-scope/spider`. The `gh-pages` branch
contains published Helm-repository artifacts; do not use it as a source-review
base unless the task explicitly targets those artifacts.

## Required

- Read the current `README.md`, PR template, root `taskfile.yaml`, relevant
  included Taskfiles, and affected CI workflows.
- Initialize the pinned `tools/yscope-dev-utils` submodule in an isolated review
  worktree before Taskfile validation when absent. Never use `--remote`.
- Keep Rust protobuf output synchronized through
  `task build:spider-proto-rust-codegen` when its source protocol changes.
- Keep C++ TDL parser output synchronized through
  `task build:tdl-generate-parsers` when its grammar changes.
- Reject unexplained manual edits in generated directories.

## Established

Verify these against current peers before making a finding:

- Spider Wolf owns C++/Python surfaces; Spider Huntsman owns Rust surfaces. Do
  not transfer conventions between them without evidence that they are shared.
- Rust workspace dependency versions and package relationships are generally
  centralized at the workspace root.
- Runtime names and configuration vocabulary should remain coherent across
  typed config, binaries, images, Compose, Helm, services, and documentation.
- Tests should assert public behavior, persisted state, protocol results, and
  lifecycle outcomes rather than generated identifiers or resource counts.

## Conditional Review Prompts

- For protocol, task-graph, database, or persisted-state changes, trace every
  client, storage service, scheduler, execution manager, task executor, language
  binding, stored-data path, and mixed-version deployment.
- Trace duplicate delivery, idempotency, retry, cancellation, timeout,
  termination tasks, recovery, and cleanup for state-machine changes.
- For deployment changes, inspect bundled/external database modes, supported
  MySQL/MariaDB behavior, images, defaults, secrets, ports, service discovery,
  readiness, config checksums, and chart/application version semantics together.
- Do not recommend a database-specific health check unless it satisfies every
  database implementation the changed interface promises to support.
- For Helm interfaces, prefer a small documented common-case API only when it has
  a demonstrated user need; avoid speculative generic hooks or new test
  infrastructure detached from current repository practice.
- For generated interfaces, review the source definition plus handwritten
  conversion, validation, ownership, and compatibility layers.

## Validation Routing

Use current Taskfiles as source of truth:

| Surface | Check | `--fix` counterpart |
|---|---|---|
| C++ | `task lint:cpp-check` | `task lint:cpp-fix` |
| CMake | `task lint:cmake-check` | `task lint:cmake-fix` |
| Python | `task lint:py-check` | `task lint:py-fix` |
| Rust | `task lint:check-rust` | `task lint:fix-rust` |
| TOML | `task lint:toml-check` | `task lint:toml-fix` |
| YAML | `task lint:yml-check` | `task lint:yml-fix` |
| Helm | `task lint:check-helm` | `task lint:fix-helm` |

Relevant tests currently include `task test:cpp-unit-tests`,
`task test:cpp-integration`, `task test:spider-py-unit-tests`, and
`task test:rust-unit-tests`. Helm packaging uses `task helm:package`; docs use
`task docs:wolf:site` or `task docs:huntsman:site`. Ensure MariaDB-backed tests,
docs servers, and containers clean up task-created resources.
