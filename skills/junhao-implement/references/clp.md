# CLP Project Reference

## Detection

Use this for `y-scope/clp` and its Git worktrees.

## Implementation Notes

- Use repo Taskfile commands; root taskfile is `taskfile.yaml`.
- Keep changes component-scoped: webui, core, package, Helm, Rust, Python
  components, docs, or CI.
- Preserve CLP terminology: use `flavour` for package variants, IEC units for
  binary sizes, and established abbreviations such as `NUM` and `MILLIS`.
- Python logging uses lazy `%` formatting. TypeScript uses `import type`,
  bottom-of-file exports, `#private`, and selective Zustand subscriptions.
- CLP has a webui; use `$playwright-cli` when browser state, UI behavior,
  selectors, console logs, or network requests matter during webui validation.
- Taskfiles follow y-scope ordering and quoting rules; render or dry-run changed
  tasks when command expansion matters.
- Before changing persisted job data, schemas, APIs, config contracts, or package
  defaults, map every producer and consumer across the affected C++, Rust,
  Python, WebUI, database, package, Compose, Helm, and documentation surfaces.
  Check existing stored data and mixed-version behavior, then classify the change
  as compatible, migration-required, or breaking. Validate round trips and
  upgrade/rollback steps where relevant.

## Validation

Run every relevant auto-fix command before manually editing lint issues:

| Change area | Auto-fix command |
|---|---|
| TypeScript/webui | `task lint:fix-js` |
| Python | `task lint:fix-py` |
| Rust | `task lint:fix-rust` |
| C++ diff | `task lint:fix-cpp-diff` |
| Broad C++ | `task lint:fix-cpp-full` |
| YAML/Taskfile | `task lint:fix-yaml` |
| Helm | `task lint:fix-helm` |
| Broad change | `task lint:fix` |

Required build for normal code changes: `task`.

Targeted tests:

| Change area | Test command |
|---|---|
| C++ core behavior | `task tests:integration:core` |
| Package behavior | `task tests:integration:package` |
| Python package imports | `task tests:integration:clp-py-project-imports` |
| Rust crates | `task tests:rust-all` |
| Broad integration | `task tests:integration` |

For CLP package changes, run the package smoke path after `task` succeeds:

```bash
cd build/clp-package
./sbin/start-clp.sh
./sbin/compress.sh --timestamp-key timestamp ~/samples/postgresql.jsonl
```

Run `./sbin/stop-clp.sh` afterward, including when the smoke path fails.

For docs changes, run `task docs:serve` and validate the rendered page in a
browser. Stop the server before final delivery.

For webui changes, run the normal webui/build/test commands first, then use
`$playwright-cli` for interactive browser debugging, selector checks, snapshots,
console logs, network requests, or UI validation that needs a live browser.

## PR Description

Follow the main skill's PR-preparation contract.

- Read at least two merged PR bodies by the current user for validation style:
  `gh pr list --author=@me --state=merged --limit=10` and
  `gh pr view <number> --json body`.
- Put the title in a template comment, not as a Markdown heading.
- Use raw GitHub permalinks with the full `git rev-parse HEAD` hash and line
  numbers.
- Do not add sections that are not in the template.
- Validation sections must include exact command output copied from the current
  run.
