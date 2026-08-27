# Setting Up a New Machine

The registry already knows where every project lives and where it came from, so most of a rebuild
is mechanical. `scripts/bootstrap.sh` does the mechanical part; this page covers the rest, which is
the part that actually takes the time.

The honest summary: **bootstrap gets you repositories, not running projects.** Cloning is the easy
half. Secrets, keys and toolchains cannot come out of a registry that is safe to keep in git, and
pretending otherwise would mean putting credentials somewhere they must never be.

## Order of operations

Steps 1 and 2 come first because cloning fails without them.

### 1. Port your private files

Neither of these is in the shared repo, by design:

```
projects.md            your registry — paths, remotes, notes
standards/             your cross-project standards
personal-links.conf    personal-folder link config (if you use it)
```

Copy them from your backup or previous machine. If you are starting fresh instead, copy the
templates: `projects.example.md`, `standards.example/`, `personal-links.example.conf`.

**Paths are machine-specific.** Registered paths reflect wherever the projects lived before —
including any drive-mount layout that machine happened to have. Edit them in `projects.md` before
running anything else; everything downstream reads paths from there, so fixing them once fixes them
everywhere.

### 2. SSH keys, config and credentials

Restore your keys to `~/.ssh` on a **native filesystem**. Mounted Windows drives cannot represent
Unix permission bits, and ssh refuses keys it considers world-readable, so a key on such a mount is
unusable no matter how the file looks.

Recreate every `Host` alias your remotes depend on. A remote written as `git@some-alias:org/repo.git`
resolves only through `~/.ssh/config`; without the alias the clone fails with a name-resolution
error that looks nothing like a missing config entry.

For HTTPS remotes, set up a credential helper or `~/.netrc`. Registry URLs deliberately carry no
username or password — see the warning at the end of this page.

### 3. Clone

```bash
./scripts/bootstrap.sh              # report: what is missing, what has drifted
./scripts/bootstrap.sh --apply      # clone the missing ones
```

Safe by default — without `--apply` nothing on disk is touched. Run it first and read the report.

Existing working copies are **checked, never modified.** When a checkout's remote or branch differs
from what the registry claims, that is reported as `DRIFT` and left alone: switching a branch can
discard uncommitted work, so it stays your decision. Drift is reported in both directions, including
a project the registry says has no repo but which turns out to have an origin — usually a leftover
remote from scaffolding, which is worth knowing about before you push into the wrong repository.

Anything on a non-git remote is listed as `MANUAL`; check those out yourself.

### 4. Personal folders

```bash
./scripts/personal-links.sh --apply
```

See [personal-folders.md](personal-folders.md).

### 5. The manual tier

```bash
./scripts/bootstrap.sh --checklist
```

Per-project secrets (`.env` files, API keys, tokens, gitignored local config), language runtimes at
whatever versions individual projects pin, system tools, dependency installs, virtualenvs, databases
and migrations. These are per project — each one's own `CLAUDE.md` and docs are authoritative, and
the registry notes usually say which secrets a project needs.

Expect this step to dominate. It is also the step where a project's own documentation earns its
keep.

## Keeping the registry honest

`bootstrap.sh` with no arguments is a cheap audit, not just a setup tool. Run it occasionally on a
machine you have been working on for a while: it compares every checkout's remote and branch against
what the registry claims and reports the differences.

That catches the failure mode where the registry drifts from reality silently — a repo checked out
on the wrong branch, an origin pointing somewhere unintended, a project that quietly gained a remote
nobody recorded. Each of those is invisible until it causes damage, and each shows up here as one
line.

## Never put credentials in a remote URL

A remote of the form `https://user:password@host/org/repo` puts a password in the registry, in every
clone's `.git/config`, and in the output of any command that prints remotes. Registry URLs carry no
credentials for exactly this reason.

If you find one, rotate the password — assume it has been copied — and move the authentication into
`~/.ssh/config`, a credential helper, or `~/.netrc`.
