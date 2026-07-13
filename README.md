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
3. (Optional) Copy the cross-project standards templates and adapt them:
   ```bash
   cp -r standards.example standards
   ```
   `standards/` is gitignored too — these are process/design rules (documentation requirements, UI conventions) the orchestrator injects into every delegation. See the Cross-Project Standards section of `CLAUDE.md`.
4. Run `claude` from this directory. On first run, approve the `@projects.md` import when prompted.

## Layout

| File | Checked in? | Purpose |
|---|---|---|
| `CLAUDE.md` | yes | Generic orchestrator instructions (role, delegation, model selection) |
| `projects.md` | **no** (gitignored) | Your private project registry, imported by CLAUDE.md |
| `projects.example.md` | yes | Template to copy for `projects.md` |
| `standards/` | **no** (gitignored) | Your private cross-project standards (docs process, UI rules), referenced in every delegation |
| `standards.example/` | yes | Templates to copy for `standards/` |
| `.claude/settings.json` | yes | Shared read-only tool permissions |
| `.claude/settings.local.json` | **no** (gitignored) | Your personal permission grants |
| `.claude/skills/audit-docs/` | yes | `/audit-docs` skill — sweeps registered projects for undocumented recent changes |
| `docs/` | yes | Getting started with Claude Code + how this pattern works |

## How is this different from Claude Cowork?

*(As of July 10, 2026 — Cowork is evolving quickly; details below may age.)*

[Claude Cowork](https://support.claude.com/en/articles/12138966-release-notes) is Anthropic's agentic workspace for general knowledge work — desktop, web, and mobile, with cloud-run sessions that continue while your laptop is closed and turnkey connectors for email, calendar, and file services. There's real overlap: both let you hand Claude tasks that run in the background, and Claude Code's remote control gives this setup phone access too.

The differences that matter:

- **Where it runs.** This orchestrator runs on *your* machine, inside your network — it can `docker exec` into local containers, read logs on your servers, hit LAN services, and use your SSH keys and deploy tooling. Cowork's cloud sessions work on synced files and connected apps; your local infrastructure isn't reachable from there.
- **Engineering-grade orchestration.** Multi-repo git work, parallel sub-agents with per-task model selection, cross-project contract awareness, hooks/skills/fine-grained permissions. Cowork deliberately abstracts all of that away for a non-technical audience.
- **Multi-provider routing.** Cowork is Claude-only. This setup can dispatch specific projects to other agent CLIs (e.g., a work-mandated GitHub Copilot seat) because it can run arbitrary local tools with your local auth — see [docs/external-agents.md](docs/external-agents.md).

And the trade-offs, honestly:

- **Your machine must be on** — remote control drives the session, but your box is the engine. Cowork's cloud sessions genuinely don't care.
- **You're the admin** — registry currency, CLAUDE.md hygiene, permission grants, and keeping concurrent agents from colliding all take supervision Cowork handles for you.
- **Cost management is manual** — no managed usage dashboards; you watch your own spend.
- **Office-work connectors aren't turnkey** — email/calendar/document tasks need MCP setup here; Cowork does them out of the box.

They're complements: Cowork for laptop-closed knowledge work anywhere, this for coordinating real engineering across your repos, infrastructure, and AI providers.

## Docs

- [Getting started with Claude Code](docs/getting-started.md) — install, login, first session
- [The orchestrator pattern](docs/orchestrator-pattern.md) — how and why this setup works
- [External agent CLIs](docs/external-agents.md) — per-project LLM providers (e.g., delegate work projects to GitHub Copilot CLI while Claude orchestrates)
