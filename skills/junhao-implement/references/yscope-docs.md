# yscope-docs Implementation Reference

## Detection

Use this for `y-scope/yscope-docs`.

## Implementation Notes

- Root taskfile is `taskfile.yaml`.
- The publishable docs build combines dev docs and the homepage.
- Sphinx config should use `project_copyright`, not `copyright`.
- Check version-switcher and project-version JSON/config changes against the
  intended deployed paths.
- Equivalent cross-repo docs or Taskfile changes should be compared directly
  against the source repo or commit the user referenced.

## Validation

There is no general lint fixer in this repo. Do not invent one.

Required docs build for normal changes: `task docs:build`.

For visual or navigation changes, run `task docs:serve`, open the served site,
and inspect the affected pages. Stop the server before final delivery.

For homepage-only changes, `task docs:build` already runs the homepage build. If
debugging a homepage failure directly, use commands from `docs/homepage/package.json`.

## PR Description

Follow the main skill's PR-preparation contract. Include exact build or serve
validation output and any manual browser checks performed.
