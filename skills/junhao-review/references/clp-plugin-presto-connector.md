# CLP Presto Connector Project Reference

## Detection

Use only for the normalized remote `y-scope/clp-plugin-presto-connector`.

## Required

- Read the current root `taskfile.yaml`, relevant component Taskfiles, PR
  template, affected workflows, and packaging documentation.
- Initialize the pinned `tools/yscope-dev-utils` submodule in an isolated review
  worktree before Taskfile validation when absent. Never use `--remote`.
- Treat root `G_PRESTO_GIT_TAG` as the authoritative Presto source revision.
  Keep Java Presto dependencies, Velox-derived C++ dependencies, build tooling,
  and cache keys synchronized with it.
- Run `task validate-dep-sync` when the Presto pin, Maven/Velox versions, or
  synchronization tooling changes.
- Do not replace a Presto-derived dependency with the generally latest release
  unless compatibility with the pinned Presto/Velox source is proven.

## Established

Verify these against current code before using them:

- The Java coordinator connector and C++ Velox worker connector are two halves
  of one deployment contract. Config, handles, codecs, types, protocol fields,
  and supported CLP data must agree.
- Some pinned Presto artifacts are source-built because they are unavailable
  from public Maven repositories.
- The Velox connector shares ABI-sensitive headers and libraries with the Presto
  worker; compiler CPU features, dependency versions, symbol visibility, and
  runtime packaging are compatibility surfaces.
- Packaging creates coordinator and worker payloads for multiple package formats
  and architectures through a shared container-side build path.

## Conditional Review Prompts

- For a Presto pin change, map derived Maven and Velox dependencies, generated
  or cached artifacts, build images, workflow paths, and every supported
  architecture.
- For API/protocol changes, trace coordinator serialization, worker
  deserialization, planner/optimizer behavior, handles, defaults, and existing
  stored CLP data.
- For CPU-target changes, prove compatibility with the worker ABI and each
  supported architecture; do not infer x86 flags for Arm or vice versa.
- For packaging, trace the local wrapper, build image, container entry point,
  package specs, runtime libraries, output ownership, OCI tags/manifests, and CI
  artifact checks.
- For CA trust, trace host bundle, transient mount, JVM trust store, environment,
  cleanup, and every image/cache/artifact boundary. Do not persist trust material
  outside its documented lifetime.
- Verify GitHub permissions, package-version policy, Docker/BuildKit behavior,
  and other external semantics through current authoritative evidence rather
  than memory.

## Validation Routing

Use current Taskfiles as source of truth. Relevant tasks currently include:

- YAML/Python lint: `task lint:check` or targeted `task lint:check-py`.
- Dependency synchronization: `task validate-dep-sync`.
- Java connector: `task presto-connector:build` and
  `task presto-connector:test`.
- Velox connector: `task velox-connector:build`.
- Packaging: `task package`.
- Integration: the current `integration-tests` task selected by the affected
  surface.

Connector/package builds may compile large upstream dependencies. Report exact
resource or environment limits when full validation is impractical.
