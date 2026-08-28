# The Orchestrator Pattern

How this repo turns a Claude Code session into a multi-project coordinator.

## The idea

Each of your projects has its own repo, its own `CLAUDE.md`, its own conventions. That's right for focused work, but nobody is holding the map: which projects consume which APIs, what breaks downstream when a contract changes, what's half-finished across three repos.

The orchestrator is that map. You run `claude` from this directory, and the session starts with:

1. **Generic orchestrator instructions** (`CLAUDE.md`) — the role: delegate code changes into project directories, watch cross-project impacts, keep the registry current.
2. **Your private registry** (`projects.md`, imported via `@projects.md`) — every project's path, stack, purpose, dependencies, and the invariants that must hold across them. It is an **index**: because it loads into every session it stays thin, and each project's accumulated detail lives in `registry/<name>.md`, read on demand.
3. **Persistent memory** — Claude Code's per-project memory accumulates the state of ongoing efforts across sessions, so "continue where we left off" works.

## How work gets done

The orchestrator doesn't edit project code itself. It:

- **Delegates** implementation to sub-agents launched inside the target project, with a precise prompt: absolute path, the task, acceptance criteria, verification steps, commit conventions, and any cross-project context (sub-agents don't inherit the registry — tell them what they need).
- **Parallelizes** independent work: agents in different repos, or in the same repo on non-overlapping files (tell each to `git pull --rebase` if a push is rejected).
- **Serializes** dependent work: a diagnosis agent reports first; the fix goes to the same agent afterward, because it retains context.
- **Chooses models per task**: cheap models for tightly-specified mechanical work, the best models for diagnosis, concurrency, auth surfaces, and contract changes (see CLAUDE.md for the full guidance).
- **Verifies before declaring done**: agents are told to run checks (tests, linters, rendering pages, hitting live endpoints) and report evidence, not just diffs.

## What goes in the registry

The private registry is the highest-leverage part of the setup. Keep the index thin — it is the tax you pay on every session — and push detail into `registry/<name>.md`. Beyond the per-project entries, keep:

- **Cross-Project Rules** — contracts that break silently: "app A calls app B's REST API with this shape", "this shared lib must be re-installed in consumers after changes", "app C is an OAuth provider for external apps".
- **Workspace & Deployment** — how code actually ships ("a local commit does not deploy" has to be written down somewhere).
- **Shared Resources** — the table of things multiple projects touch.
- **Local Environment Notes** — machine quirks (filesystem, mounts, keys) that would otherwise be rediscovered painfully.

## Practices that make it work

- **Keep project-specific depth in the projects.** The registry entry says *what* a project is and points at its own `CLAUDE.md`/docs for the *how*. Don't duplicate — stale duplicates are worse than pointers.
- **Update the registry in the same session** that changes reality (a new dependency, a renamed feature, a new gotcha). The orchestrator's value is exactly its currency.
- **Give the orchestrator the debugging first.** Cross-project symptoms ("app A says no results but service B works fine") are where the map pays off: the orchestrator can check both sides of a contract before delegating a fix to either.
