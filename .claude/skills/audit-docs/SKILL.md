---
name: audit-docs
description: Sweep registered projects for recent code changes that violate standards/documentation.md, and report gaps. Use when the user asks to audit/check documentation across projects, or on a schedule.
---

# audit-docs

Audit every registered project for code changes that were committed without the documentation updates required by `standards/documentation.md`.

## Arguments

- Optional: a since-date (e.g. `2026-07-01`) or a lookback like `30d` — audit commits after that point.
- Optional: one or more project names from `projects.md` — restrict the audit to those projects.
- Default scope: all registry projects with a git repo, since the `lastAudit` timestamp in `.claude/audit-state.local.json`; if that file doesn't exist, the last 14 days.

## Procedure

1. Read `projects.md` for the project list, paths, `Agent:` fields, and dependency relationships. Read `standards/documentation.md` so you can quote the actual requirements in agent prompts.
2. Skip projects whose path doesn't exist or isn't a git repo (note them in the report).
3. **Strict-mode projects** (`Agent:` value ending in `-strict`): do NOT read their files or diffs. Dispatch the audit to that project's named CLI instead (per `docs/external-agents.md`), passing the documentation standard's requirements inline in the prompt, and relay its findings.
4. For all other projects, fan out **parallel read-only Explore agents**, one per project. Each agent's prompt must include:
   - The absolute project path and the audit window (`git log --since=<date>`).
   - The full text (or absolute path) of `standards/documentation.md`.
   - The task: for each substantive commit (skip formatting/test-only/dep-bump commits per the standard's exclusions), check whether the required docs were updated in that commit or a nearby one — the project's docs folder, API reference, `CLAUDE.md`/`AGENTS.md`, `.env.example` — and whether existing docs were made stale.
   - Required output: a structured list of gaps — `commit hash, what changed, which doc should have been updated, what's missing or now wrong` — or an explicit "no gaps".
5. Aggregate into one report, grouped by project: commits reviewed, gaps found, and any cross-project impacts (API/contract changes affecting `Depended on by` projects) that never reached `projects.md`.
6. Write the current timestamp to `.claude/audit-state.local.json` as `{"lastAudit": "<ISO date>"}`.

## After the report

Do not fix anything unprompted. Offer to delegate fixes per the normal delegation rules in `CLAUDE.md` (respecting each project's `Agent:` field), including the absolute path to `standards/documentation.md` in each fix prompt. Doc-gap fixes with a precise gap description are usually cheap-model work.
