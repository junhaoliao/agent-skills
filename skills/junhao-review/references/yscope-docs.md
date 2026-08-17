# yscope-docs Project Reference

## Detection

Use only for the normalized remote `y-scope/yscope-docs`.

## Required

- Read the current root `taskfile.yaml`, `taskfiles/docs.yaml`, Sphinx config,
  `conf/projects.json`, Next.js homepage manifests, and affected deployment CI.
- Treat the publishable site as a composition of developer docs, the homepage,
  and downloaded/versioned project documentation.
- Keep project versions, refs, download paths, routes, symlinks, and deployed URLs
  coherent.
- Use current Sphinx/theme/Next.js documentation for framework-specific claims.

## Established

Verify these against current files before making a finding:

- Sphinx config uses `project_copyright`.
- The root docs build owns assembly of all publishable surfaces.
- Equivalent cross-repo docs or Taskfile changes should be compared directly
  against the named source revision rather than remembered convention.

## Conditional Review Prompts

- For project-version changes, verify the referenced tag/branch exists, the
  downloaded output matches the expected layout, and old versions remain
  reachable when promised.
- Check route and symlink collisions across homepage, developer docs, and
  project docs.
- For navigation/theme changes, inspect the rendered site at the affected route;
  successful source compilation alone is insufficient.
- For Taskfile concurrency or download changes, trace partial failure, cleanup,
  repeatability, and cache/output ownership.

## Validation Routing

Use current Taskfiles as source of truth:

- Full publishable build: `task docs:build`.
- Local rendered validation: `task docs:serve`.
- Targeted developer docs or homepage tasks may be used for diagnosis, but a
  narrower pass does not replace the full build when assembly changed.

Stop task-created servers after review. Record project-download/network limits
when they prevent the full build.
