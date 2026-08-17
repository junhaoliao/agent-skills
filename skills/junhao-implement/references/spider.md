# Spider Project Reference

## Detection

Use this for `y-scope/spider` and its Git worktrees. Verify the requested
checkout and target branch: `gh-pages` contains published Helm artifacts and is
not a source-development branch unless the task explicitly targets the chart
repository.

## Implementation Notes

- Use root `taskfile.yaml` commands and keep changes scoped to Spider Wolf
  (C++/Python), Spider Huntsman (Rust), shared protocols, docs, images, or Helm.
- Update generated Rust protobuf or C++ TDL parser files only through their
  generators and verify the generated diff.
- For protocol, persisted-state, database, or deployment-contract changes, map
  all clients, schedulers, execution managers, storage services, task executors,
  language bindings, stored data, and mixed-version behavior before editing.
- Helm sources live in `tools/deployment/spider-helm`; inspect chart versioning,
  defaults, generated packages, and image compatibility together.

## Validation

Run the relevant fixer before its check-mode equivalent:

| Change area | Fixer | Check |
|---|---|---|
| C++ | `task lint:cpp-fix` | `task lint:cpp-check` |
| CMake | `task lint:cmake-fix` | `task lint:cmake-check` |
| Python | `task lint:py-fix` | `task lint:py-check` |
| Rust | `task lint:fix-rust` | `task lint:check-rust` |
| TOML | `task lint:toml-fix` | `task lint:toml-check` |
| YAML | `task lint:yml-fix` | `task lint:yml-check` |
| Helm | `task lint:fix-helm` | `task lint:check-helm` |
| Broad change | `task lint:fix` | `task lint:check` |

Run the tests matching the affected surface:

| Change area | Command |
|---|---|
| C++ unit | `task test:cpp-unit-tests` |
| C++ integration | `task test:cpp-integration` |
| Python | `task test:spider-py-unit-tests` |
| Rust | `task test:rust-unit-tests` |

Use `task build:rust` or `task build:spider-py` for their respective build
surfaces. For generated interfaces, run `task build:spider-proto-rust-codegen`
or `task build:tdl-generate-parsers` and verify the tracked generated directory
has no unexplained diff. For docs, run `task docs:wolf:site` or
`task docs:huntsman:site`. For Helm, run `task lint:check-helm` and
`task helm:package`; validate relevant image changes with
`task docker:build-storage`, `task docker:build-scheduler`, or
`task docker:build-worker`. Ensure MariaDB-backed tests and docs servers clean up
their task-created resources.

## PR Description

Follow the main skill's PR-preparation contract and preserve
`.github/PULL_REQUEST_TEMPLATE.md` exactly. Treat breaking protocol, persisted
state, or deployment changes as breaking in both the title and checklist.
