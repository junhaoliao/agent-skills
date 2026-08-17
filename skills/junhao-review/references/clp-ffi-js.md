# clp-ffi-js Project Reference

## Detection

Use only for the normalized remote `y-scope/clp-ffi-js` or the package
`clp-ffi-js`.

## Required

- Read the current `taskfile.yaml`, `package.json`, CMake configuration, public
  exports, CI, and affected tests before applying conventions.
- Preserve both Node and worker/browser package exports and the corresponding
  WASM artifact-loading behavior.
- Treat C++ exception choice, public JSDoc, and supported binary input types as
  contracts established by the current API and peer implementation; do not
  impose an old universal rule.
- Keep tracked generated/package output synchronized through current build tasks.

## Established

Verify these against current code before using them:

- WASM object ownership and explicit disposal are important at the JS/C++
  boundary.
- Public timestamps that can exceed `Number.MAX_SAFE_INTEGER` use `bigint`.
- Type-only imports and native `#private` fields follow current TypeScript tooling.
- Binary size matters, but remove a dependency feature only after proving that no
  configured environment uses it.

## Conditional Review Prompts

- Trace module factory initialization, promise caching, rejection, retry,
  replacement, and disposal before reporting a lifecycle defect.
- For SFA/IR changes, trace buffer ownership, offsets/lengths, exception
  translation, decoder close behavior, and every public Node/worker consumer.
- For Emscripten/CMake changes, verify list/quoting semantics, stage-specific
  options, exported symbols, custom `locateFile` behavior, and generated JS/WASM
  names through a build rather than memory.
- For public API changes, check both environment exports, declarations,
  documentation, compatibility, and all configured test projects.
- Distinguish a credible reachable exception path from speculative defensive
  handling before requesting retry or rollback machinery.

## Validation Routing

Use current Taskfiles as source of truth:

| Surface | Check | `--fix` counterpart |
|---|---|---|
| Broad lint | `task lint:check` | `task lint:fix` |
| TypeScript | `task lint:check-js` | `task lint:fix-js` |
| C++ diff | `task lint:check-cpp-diff` | `task lint:fix-cpp-diff` |
| Broad C++ | `task lint:check-cpp-full` | `task lint:fix-cpp-full` |

Use `task package` for package/build changes and `task test` for runtime or API
changes. The test task exercises configured Node and browser projects; initialize
the required browsers with the repository task only when absent. Use the current
docs task for public documentation changes.
