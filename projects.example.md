# Project Registry (template)

Copy this file to `projects.md` (which is gitignored) and fill in your own projects. `CLAUDE.md` imports `projects.md` at session start.

## Projects

Add each project below with its path, purpose, stack, and any cross-project dependencies.

`**Repo:**` and `**Branch:**` are what `scripts/bootstrap.sh` uses to clone missing projects on a
new machine — see `docs/new-machine.md`. Use `none` for anything not version-controlled (planning
folders, workspaces) or not yet pushed; prefix non-git remotes with the VCS, e.g. `svn+https://…`.
**Never store credentials in the URL** — a remote like `https://user:password@host/repo` puts a
password in the registry and in every clone's `.git/config`. Configure auth in `~/.ssh/config`, a
credential helper, or a `~/.netrc` instead.

### Template
```
### [Project Name]
- **Path:** ~/path/to/project
- **Repo:** git@github.com:you/project.git | svn+https://host/svn/project | none
- **Branch:** main
- **Type:** work | personal
- **Stack:** (e.g., Node, Postgres, React)
- **Purpose:** One sentence description.
- **Agent:** (optional — external agent CLI for this project, e.g. copilot or copilot-strict; omit for Claude sub-agents. See docs/external-agents.md)
- **UI Standard:** (optional — which standards/UI_*.md file governs this project's UI work; omit for non-UI projects)
- **Depends on:** (other projects, shared libs, APIs)
- **Depended on by:** (other projects that consume this one)
- **Notes:** Anything Claude should know before touching this project.
```

### Example
```
### project-a
- **Path:** ~/work/project-a
- **Repo:** git@github.com:you/project-a.git
- **Branch:** main
- **Type:** work
- **Stack:** Node.js, Postgres, REST API
- **Purpose:** Core billing service.
- **Depends on:** shared-auth
- **Depended on by:** project-b (consumes /api/v2)
- **Notes:** OpenAPI spec lives at docs/openapi.yaml. Never modify the /api/v1 routes — legacy clients depend on them.
```

---

## Cross-Project Rules

Invariants Claude should check before and after cross-cutting changes. Examples: API contracts between your projects, shared libraries that must be version-bumped in consumers, auth providers other apps depend on.

- (add yours here)

---

## Workspace & Deployment

How your projects get deployed, and where that is documented. Prefer documenting deploy flows once (e.g., in a workspace-level CLAUDE.md) and referencing them here.

---

## Shared Resources

| Resource | Path / Location | Used By |
|---|---|---|
| (shared lib) | ~/path | project-a, project-b |

---

## Local Environment Notes

Machine-specific gotchas (filesystem quirks, mounts, VPNs) that affect how Claude should work here.
