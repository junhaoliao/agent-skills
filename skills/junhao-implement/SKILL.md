---
name: junhao-implement
description: Use when implementing fixes or features in Junhao's local repos, especially when project-specific conventions, validation commands, mandatory repo-root PR description prep, or pre-delivery verification are needed.
---

# Junhao Implement

## Overview

Implement narrowly, validate with the repo's real commands, and deliver a clear
status report. This skill is self-contained: all implementation and completion
checks live here or in the project reference files.

## Submission

Work locally by default. Treat `--submit` as shorthand to stage only task-owned
changes, commit with the proposed title, push the task branch without force, and
create or update the PR from the repo-root description. It does not authorize
deployment, merging, releases, tags, default-branch pushes, or scope expansion.
Submission applies only to the current task and Git root; delegates do not
inherit it unless explicitly invoked with `--submit` within the user's grant.
Explicit prose still authorizes only the named actions. Stop if the branch or
task-owned changes cannot be isolated safely.

## Project Selection

Start by identifying the repo from `git remote get-url origin`, the current
working directory, and root manifests such as `taskfile.yaml`, `Taskfile.yml`,
`package.json`, `pyproject.toml`, and `Cargo.toml`.

Load exactly one matching project reference before editing:

| Repo signal | Reference |
|---|---|
| `y-scope/clp` | `references/clp.md` |
| `y-scope/clp-ffi-js` | `references/clp-ffi-js.md` |
| `y-scope/spider` | `references/spider.md` |
| `y-scope/yscope-docs` | `references/yscope-docs.md` |
| `y-scope/yscope-log-viewer` | `references/yscope-log-viewer.md` |
| `y-scope/yscope-dev-utils` | `references/yscope-dev-utils.md` |

If no reference matches, use the generic fallback in this file and infer local
commands from manifests. If multiple references match, prefer the current
checkout unless the user named a different repo.

## Workflow

1. Re-read the request and record the submission mode, Git root, constraints,
   requested non-edits, and affected components. Update this ledger after
   steering messages.
2. Inspect current state with `git status --short`. Do not revert unrelated
   changes. If an issue or PR is referenced, fetch it with `gh` before choosing
   the approach. If `.gitmodules` exists, initialize the required pinned
   submodules before project commands with
   `git submodule update --init --recursive` (restrict paths when useful). Never
   use `--remote` unless the task requires updating a submodule revision.
3. Read the implementation path end to end: caller, callee, tests, config, docs,
   and peer files that establish naming and structure.
4. Before changing a persisted format, schema, API, config contract, generated
   interface, image, or workflow artifact, map its producers, consumers, stored
   data, defaults, cross-version behavior, deployment/docs surfaces, and
   migration path. Classify it as compatible, migration-required, or breaking.
5. When correctness depends on external platform behavior, verify it with
   current official documentation or source and, when practical, a focused
   reproduction or relevant CI log. Distinguish fact, observation, and inference.
6. For dependency changes, use the latest stable compatible release verified
   from current official sources. Check runtime, engine, and peer constraints;
   document why if latest cannot be used. Update locks narrowly, inspect unrelated
   churn, and finish with the repository's frozen or locked install.
7. For behavior changes, add or update a focused automated test first when a
   practical test surface exists. Run it and confirm it fails for the expected
   reason before implementation. For docs, config-only, generated, or genuinely
   impractical test cases, record the exception and choose targeted validation.
8. Implement the smallest change that satisfies the request. Avoid unrelated
   refactors, speculative options, broad abstractions, or changes to user-owned
   dirty files.
9. Run the completion gate below before reporting success.

## Completion Gate

Before saying work is done:

- Confirm the implementation still matches the original request and did not add
  scope creep.
- Read back every created or edited file that matters to the change.
- Run the project reference's available auto-fix commands first. Do not run a
  lint check before an available auto-fix command for the same surface.
- Review remaining lint issues after auto-fix. Fix only issues caused by this
  change unless the user asked for broader cleanup.
- Run the required build command and relevant tests from the project reference.
- Track each validation command's working directory, covered surface, exit
  status, and whether it is targeted or required. Rerun affected gates after the
  final edit or auto-fix, and distinguish expected, baseline, and unresolved
  failures. A narrower pass does not override a failing required gate.
- For browser-backed tests or browser validation, use `$playwright-cli` for
  interactive inspection, debugging, test generation, or healing. Run the
  project's normal test command first; use `$playwright-cli` when browser state,
  UI behavior, selectors, screenshots, console logs, network requests, or
  Playwright debugging are needed.
- Check docs, generated artifacts, schemas, config keys, and cross-file
  references when the change affects them.
- Write the repo-root PR-description Markdown file according to the PR
  preparation contract below.
- With `--submit`, submit only after required validation and PR preparation are
  complete; then verify the commit SHA, pushed branch, PR URL, target branch, and
  PR head SHA.
- Report failed or skipped validation explicitly with the reason. Never describe
  a failing build, test, or lint command as passing.

## PR Preparation

Always prepare a PR description for every implementation performed with this
skill, whether or not the user explicitly asks for PR prep. Write it to a
Markdown file in the repo root; never only print the PR description in chat.

Use the target branch's pull-request template whenever one is available. Check
`.github/pull_request_template.md` and `.github/PULL_REQUEST_TEMPLATE.md`
case-sensitively; if both exist, prefer the lowercase path. If no template
exists, use concise sections for description, validation, and reviewer notes.
Preserve the template's headings, order, checklist text, comments, and links;
before submission, compare the completed draft against the template.

PR-description preparation is mandatory, but publication is not. Keep the draft
untracked unless explicitly asked to commit it. With `--submit`, stage only the
task-owned implementation and make the publication workflow consume this exact
file; never substitute a `/tmp` or separately handwritten body.

Do not hard-wrap prose in PR descriptions; keep each Markdown paragraph on a single line.

Always include a proposed PR title in Conventional Commit form:
`type(scope): imperative description`, using `type(scope)!:` for a breaking
change. Before choosing it, inspect recent history with
`git log origin/main --oneline -100`; if `origin/main` is missing, inspect the
repo's default branch history and mention that fallback.

Name the Markdown file from the proposed title, not `pr_description.md`. Use
`pr-<type>-<scope>-<slug>.md`, omitting `<scope>` when there is none. Slug rules:
lowercase ASCII, hyphen-separated, punctuation/backticks removed, six meaningful
words or fewer. Example: `fix(webui): Preserve search filters` becomes
`pr-fix-webui-preserve-search-filters.md`. Update an existing draft for the same
branch and change; add a numeric suffix only when the existing file is unrelated.

When a PR description includes validation output, record the actual command,
exit status, and exact output or a clearly labeled exact excerpt. Do not suppress
diagnostics to manufacture a pass, and redact secrets. In the final response,
report the proposed title, PR-description path, final validation status, and any
remote mutations.

## Generic Fallback

Use this only when no project reference matches:

- Node.js: detect the package manager from `packageManager` and then the lockfile.
  Use its scripts and workspace filters; run its lint fixer or manager-native
  `eslint --fix` for touched files, then its build and relevant test commands.
- Python: run `uv ruff check --fix` and `uv ruff format` when the project uses
  uv/ruff; then targeted tests.
- CMake/C++: run the formatter/linter task if present, then
  `cmake --build build` or the repo's task wrapper.
- Shell: run `shellcheck` on touched scripts.
- Taskfile: render or dry-run changed tasks when possible, and run the repo's
  YAML/task lint command after any available fixer.
