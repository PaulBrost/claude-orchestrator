# Claude Orchestrator

A lightweight pattern for coordinating many projects with [Claude Code](https://code.claude.com/docs): one directory whose `CLAUDE.md` turns Claude into an **orchestrator** that knows your whole project landscape, delegates implementation work to sub-agents inside each project, and watches for cross-project breakage.

## Why

Working on one repo at a time, Claude can't warn you that the API change you just made breaks a consumer it has never seen. Running Claude from an orchestrator directory gives it a registry of all your projects — paths, stacks, dependencies, deploy flows — so multi-project work gets coordinated instead of siloed: it can dispatch parallel agents into different repos, sequence dependent changes, and keep a persistent memory of ongoing efforts.

## Setup

1. Clone this repo (anywhere you like).
2. Copy the registry template and fill in your projects:
   ```bash
   cp projects.example.md projects.md
   ```
   `projects.md` is gitignored — your project details stay private.
3. Run `claude` from this directory. On first run, approve the `@projects.md` import when prompted.

## Layout

| File | Checked in? | Purpose |
|---|---|---|
| `CLAUDE.md` | yes | Generic orchestrator instructions (role, delegation, model selection) |
| `projects.md` | **no** (gitignored) | Your private project registry, imported by CLAUDE.md |
| `projects.example.md` | yes | Template to copy for `projects.md` |
| `.claude/settings.json` | yes | Shared read-only tool permissions |
| `.claude/settings.local.json` | **no** (gitignored) | Your personal permission grants |
| `docs/` | yes | Getting started with Claude Code + how this pattern works |

## Docs

- [Getting started with Claude Code](docs/getting-started.md) — install, login, first session
- [The orchestrator pattern](docs/orchestrator-pattern.md) — how and why this setup works
