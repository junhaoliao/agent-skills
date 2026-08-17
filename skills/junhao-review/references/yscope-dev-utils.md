# yscope-dev-utils Project Reference

## Detection

Use only for the normalized remote `y-scope/yscope-dev-utils`.

## Required

- Read the current root `taskfile.yaml`, exported Taskfiles/configs, affected
  tests, and consumer-facing documentation.
- Treat exported Taskfile variables, defaults, generated files, lint configs,
  and composite-action inputs as public contracts for downstream repositories.
- Follow current configured shell and Taskfile options; do not impose a universal
  `set -euo pipefail` or historical boolean naming rule.
- Respect CI's current action pinning and security policy.

## Established

Verify these against current code before using them:

- Taskfiles use current y-scope ordering, quoting, `G_` globals, and checksum
  patterns.
- Reproducible archive helpers account for GNU/BSD tool differences.
- Shared lint configs and reusable actions should minimize consumer duplication.
- Tests exercise exported behavior rather than only internal helper structure.

## Conditional Review Prompts

- Map every downstream caller before renaming a variable, changing a default,
  altering checksum semantics, or tightening a lint rule.
- Verify `0`, empty, unset, boolean, and Sprig `default` behavior explicitly.
- For shell/YAML templates, render or dry-run the expanded command; distinguish
  indentation bugs from quoting bugs.
- For cross-platform helpers, check Linux and macOS command/flag availability and
  reproducibility requirements.
- Validate a representative affected consumer when exported behavior changes,
  but do not demand broad consumer work without a concrete compatibility risk.

## Validation Routing

Use current Taskfiles as source of truth. Relevant commands presently include:

- Broad lint: `task lint:check`.
- Broad tests: `task test`.
- Targeted tests: `task tests:boost`, `task tests:checksum`,
  `task tests:remote`, or `task tests:ystdlib-py`.

Run an available targeted fixer before manual cleanup only under `--fix`.
Report the exact consumer command when downstream validation is needed.
