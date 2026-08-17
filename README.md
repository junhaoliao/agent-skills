# Agent Skills

Junhao's skills for AI coding agents. A skill is a set of packaged instructions, references, and scripts that an agent loads when a matching task comes up.

Skills follow the [Agent Skills](https://agentskills.io/) format.

[![skills.sh](https://skills.sh/b/junhaoliao/agent-skills)](https://skills.sh/junhaoliao/agent-skills)

## Installation

Install with the [skills CLI](https://github.com/vercel-labs/skills):

```bash
npx skills add junhaoliao/agent-skills
```

To install a single skill globally for Claude Code:

```bash
npx skills add junhaoliao/agent-skills --skill junhao-review -g -a claude-code -y
```

## Available skills

### junhao-review

Reviews pull requests, branches, commits, or uncommitted changes. It resolves the exact base and head of the target, reads the change alongside its callers, contracts, and deployment surfaces, and keeps a finding only when it can attribute the problem to this change, show a concrete path that reaches it, and back it with evidence the author can act on. A thorough review may have zero findings.

**Use when:**

- Reviewing a PR, branch, commit, or local uncommitted changes
- Asking for an explanation or walkthrough of a change
- Checking whether prior review comments were addressed (thread-aware follow-up)
- Applying safe review fixes locally

**Modes:**

- `--fix` - Apply unambiguous fixes locally (never stages, commits, or pushes)
- `--base <ref>` - Override the comparison base for non-PR targets
- `--file [path]` - Write or refresh a Markdown review artifact
- `--inline` - Emit host-native inline annotations for changed-line findings
- `--diagrams` - Include a diagram only when it clarifies the change

**What it covers:**

- Exact base/head targeting (PR object IDs, merge bases, detached heads, stacked PRs)
- Architecture, ownership, and contract analysis instead of low-signal style commentary
- Compatibility checks for persisted formats, schemas, APIs, and config contracts
- Conventions for y-scope repos such as CLP, Spider, and yscope-log-viewer
- Validation with the project's own lint, test, and build commands

### junhao-implement

Implements fixes and features with the smallest change that satisfies the request, then validates with the repository's real commands and reports what actually passed. For known repos it loads a project reference that carries the exact commands and conventions. For behavior changes it writes a failing test first whenever a practical test surface exists.

**Use when:**

- Implementing a fix or feature in Junhao's local repos
- Project conventions or validation commands matter
- A repo-root PR description in Conventional Commit form is needed
- The work must pass auto-fix, lint, build, and tests before it is reported done

**What it covers:**

- Project references for y-scope repos, plus a generic fallback for Node.js, Python, CMake/C++, Shell, and Taskfile projects
- Dependency updates pinned to the latest stable compatible release, with narrow lock changes
- A completion gate: auto-fix before lint, required builds and tests, and honest reporting of failures
- Mandatory PR description prep: repo template, Conventional Commit title, `pr-<type>-<scope>-<slug>.md` naming
- `--submit` - Stage task-owned changes, commit, push the task branch, and create or update the PR

### junhao-rewrite

Rewrites or replaces a substantial codebase or subsystem while preserving observable behavior, or changing it only on purpose. It freezes a behavior reference, plans the commit stack in dependency order, implements slices in portable Git worktrees, and curates the history so the published stack reads as an intentional implementation plan rather than a log of the session.

**Use when:**

- Rewriting or replacing a large subsystem or codebase
- A clean, incremental, reviewable Git history is a deliverable
- Coordinating parallel agents or worktrees on independent slices
- Building characterization or differential tests against a frozen reference
- Invoking `--improve commit`, `--improve batch`, or `--improve auto` review gates

**What it covers:**

- Separate target base and behavior reference, frozen as exact SHAs in a ledger
- A behavior map where every mismatch is classified as matching, intentional, obsolete, or unresolved
- Plain `git worktree` workflows that run from Codex, Claude Code, or any shell-capable agent
- Continuous integration and curation: fixups, autosquash, `git range-diff`, and per-commit validation
- External `--improve` audits through the Claude CLI, with resumable sessions that track each finding's disposition
- Acceptance from a fresh worktree before handoff; pushes only with explicit authority

## Usage

Once installed, a skill loads on its own when a task matches its description. You can also ask for one directly:

```
Review PR #123 and check whether the earlier review comments were addressed
```

```
Implement this fix and prepare the PR description
```

```
Rewrite the ingestion pipeline with --improve auto, keeping observable behavior identical
```

## Skill structure

Each skill contains:

- `SKILL.md` - Instructions for the agent
- `references/` - Supporting documentation (optional)
- `scripts/` - Helper scripts for automation (optional)
- `agents/` - Per-agent interface metadata (optional)
