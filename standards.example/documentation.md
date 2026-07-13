# Documentation Standard (template)

Copy this directory to `standards/` (which is gitignored) and adapt to your own conventions. This file is a working starting point — the rules below are generic enough to use as-is.

Applies to **every project** in the registry. Any delegation prompt for a code change must reference this file by absolute path and require compliance before commit.

## Core rule

Documentation is updated **in the same change** as the code it describes. A change is not done — and must not be committed — while it makes existing documentation wrong.

## What must be updated, when

| Change | Required doc update |
|---|---|
| New feature or behavior change | The project's docs folder (`Docs/` or `docs/`) — the page covering that area, or a new page if none exists |
| API request/response shape, endpoint, or contract change | The project's API reference doc, **and** a note of impact on consumers listed in the registry (`Depends on` / `Depended on by`) |
| New/changed config, env var, or deployment step | The project's deployment/setup doc and `.env.example` (if present) |
| New convention, gotcha, or invariant future agents must know | The project's `CLAUDE.md` (and `AGENTS.md` where present) |
| Schema/data-model change | The data-model or architecture doc, if the project has one |

## What does NOT require doc updates

Refactors with no behavior change, test-only changes, dependency bumps without API impact, and pure formatting. Do not add noise docs for these.

## Quality bar

- Docs describe **current** behavior — delete or rewrite stale sections rather than appending contradictions.
- No "changelog-style" docs inside feature pages; state what *is*, not what changed.
- If a change affects another project (per the registry's dependency fields), say so in the task report so the orchestrator can update `projects.md` and coordinate.

## Enforcement

- **Prevention:** the orchestrator includes this file's path in every code-change delegation.
- **Detection:** the orchestrator's `/audit-docs` skill periodically sweeps recent commits in each registered project and reports doc gaps.
