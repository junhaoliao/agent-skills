# clp-ffi-js Implementation Reference

## Detection

Use this for `y-scope/clp-ffi-js` and packages named `@y-scope/clp-ffi-js`.

## Implementation Notes

- Root taskfile is `taskfile.yaml`.
- Preserve dual Node/browser behavior and WASM lifecycle invariants.
- Keep binary size in mind: disable unused dependency features and avoid
  unnecessary runtime/bundler work.
- C++ throws should use `ClpFfiJsException(__FILENAME__, __LINE__, ...)`.
- Public TypeScript APIs need accurate JSDoc, including meaningful `@throws`
  descriptions.
- Use `bigint` for timestamps that may exceed `Number.MAX_SAFE_INTEGER`.
- Prefer `ArrayBuffer | ArrayBufferView` for binary inputs when practical.

## Validation

Run available auto-fix before manual lint edits:

| Change area | Auto-fix command |
|---|---|
| Broad lint surface | `task lint:fix` |
| TypeScript | `task lint:fix-js` |
| C++ diff | `task lint:fix-cpp-diff` |
| C++ broad | `task lint:fix-cpp-full` |
| YAML/Taskfile | `task lint:fix-yaml` |

Required package build for normal code changes: `task package`.

Required test for runtime/API changes: `task test`. This runs Vitest across the
configured Node and browser projects. If Playwright browsers are missing, run
`task test:init` first and then re-run `task test`.

When a browser project fails or needs live inspection, use `$playwright-cli` to
debug browser state, selectors, screenshots, console logs, network requests, or
Playwright interactions after starting from the normal test command.

For docs changes, run `task docs:serve` and validate rendered output in a
browser.

## PR Description

Follow the main skill's PR-preparation contract. Include exact validation
commands and outputs. Mention browser coverage explicitly when `task test` is
part of the validation.
