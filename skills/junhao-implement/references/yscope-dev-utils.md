# yscope-dev-utils Implementation Reference

## Detection

Use this for `y-scope/yscope-dev-utils`.

## Implementation Notes

- Root taskfile is `taskfile.yaml`.
- This repo exports shared Taskfile utilities, lint configs, and GitHub Actions;
  changes can affect downstream repositories.
- Taskfiles must respect y-scope ordering, path quoting, global `G_` variable
  names, and checksum conventions.
- Prefer positive boolean names with safe defaults, such as `IGNORE_ERROR=false`.
- Use GNU tar as `gtar` on macOS when reproducible archive flags are required,
  with a Linux fallback.
- GitHub Actions should use pinned SHAs, not mutable tags.
- Shell scripts should use `set -euo pipefail`, quoted variables, and `cmp -s`
  for silent comparisons.

## Validation

Run available auto-fix before manual lint edits:

| Change area | Auto-fix command |
|---|---|
| Python utilities | `task lint:fix-py` |

There is no YAML auto-fix task. For YAML, Taskfile, action, or broad changes,
run:

```bash
task lint:check
```

Run targeted tests when the touched area is clear:

| Change area | Test command |
|---|---|
| Boost utilities | `task tests:boost` |
| Checksum utilities | `task tests:checksum` |
| Remote utilities | `task tests:remote` |
| Python utility package | `task tests:ystdlib-py` |

Required broad test command:

```bash
task test
```

For exported utility or lint-config changes, validate at least one affected
consumer repo when practical and report the exact consumer command used.

## PR Description

Follow the main skill's PR-preparation contract. Call out downstream validation
for exported behavior changes.
