# yscope-log-viewer Project Reference

## Detection

Use only for the normalized remote `y-scope/yscope-log-viewer` or package
`yscope-log-viewer`.

## Required

- Read `docs/src/dev-guide/coding-guidelines.md`, current `package.json`, ESLint,
  Stylelint, Jest, Vite, and affected peer code before applying conventions.
- Use current directories and interfaces, including `src/stores`,
  `src/services`, worker services, and decoder ownership.
- Preserve worker/WASM resource disposal and current public URL/query contracts.
- Do not revive old claims about structured-clone `bigint` support or obsolete
  test frameworks.

## Established

Verify these against current peers before making a finding:

- Zustand selectors avoid whole-store subscriptions; `getState()` can provide
  stable non-reactive access when the callback lifecycle makes it appropriate.
- Non-rendering mutable values commonly belong in refs, while rendered values
  belong in state.
- Native `#private` fields and `import type` follow current TypeScript tooling.
- Worker filenames, Vite imports, stores, services, CSS variables, and domain
  terminology follow the current coding guide.
- Resource-owning managers and proxies expose clear replacement/disposal paths.

## Conditional Review Prompts

- Trace file-manager, decoder, WASM object, worker, listener, and store ownership
  across repeated loads, replacement, errors, and component unmount.
- For React callbacks, prove a stale-closure, identity, or render consequence
  before requesting `useCallback`; never ban inline arrows categorically.
- For Zustand changes, distinguish reactive UI state, submitted/snapshotted
  state, and imperative service state before moving behavior.
- For URL/hash changes, trace parse, validation, default filtering, browser
  navigation, programmatic updates, and loop prevention.
- For Monaco or bundle changes, use current bundle evidence before reporting a
  performance regression.
- For decoder changes, trace detection, exact boundary inputs, fallback behavior,
  error propagation, and every supported file type.

## Validation Routing

Use current package scripts:

| Surface | Review check | `--fix` counterpart |
|---|---|---|
| Lint | `npm run lint:check` | `npm run lint:fix` |
| Build | `npm run build` | same after fixes |
| Tests | `npm test` | same after fixes |

The current test runner is Jest. Docs use `task docs:site`; rendered docs can be
checked with the current serve task. For interactive UI behavior, start from the
normal automated commands and use a browser only when live state, selectors,
console output, or network behavior matters.
