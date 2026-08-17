# yscope-log-viewer Implementation Reference

## Detection

Use this for `y-scope/yscope-log-viewer` and packages named
`yscope-log-viewer`.

## Implementation Notes

- Prefer Zustand store selectors: `useStore((state) => state.value)`.
- Use `getState()` for stable action access inside callbacks/effects.
- Keep non-rendering values in refs, not state.
- Wrap prop handlers in `useCallback`; move helpers with no React dependency to
  module scope.
- Use native `#private` fields and `import type` for type-only imports.
- Worker files use `.worker.ts`; terminate old workers before creating new ones.
- Use CSS files and variables for static styles; avoid inline styles for layout.
- Preserve domain terms such as `prettified`, `logEventNum`, `beginLineNum`,
  `queryString`, `pageNum`, and `numPages`.

## Validation

Run available auto-fix before manual lint edits:

```bash
npm run lint:fix
```

Required build for normal code changes:

```bash
npm run build
```

Required tests for logic or component behavior changes:

```bash
npm test
```

For browser-backed UI behavior, use `$playwright-cli` when snapshots, selector
checks, console logs, network requests, or live interaction are needed. Keep
`npm test` and `npm run build` as the required automated validation.

For docs changes, use the repo Taskfile:

```bash
task docs:site
```

For rendered docs validation, run `task docs:serve`, inspect affected pages, and
stop the server before final delivery.

## PR Description

Follow the main skill's PR-preparation contract. Include exact command output
and, for UI changes, the browser and user interactions validated.
