# Personal Folders — Per-Project Notes That Stay Out of Git

Most projects accumulate material that is yours rather than the project's: investigation notes,
scratch plans, exported data, screenshots, a copy of something you were comparing against. It has to
live *somewhere*, and the two obvious places are both wrong. Commit it and it pollutes a shared
repository with your working memory. Leave it untracked and it is one `git clean` away from gone,
and it is backed up only if you happen to back up that repo's working tree.

This pattern gives every project a folder that is present where you need it, stored somewhere it
survives, and invisible to git.

## Shape

One central tree holds the real directories, one per project:

```
~/personal_files/
├── brost_us/
├── gb_grooves/
├── pds-builder/
└── scout/
```

Each project gets a symlink pointing into it:

```
~/Brost/brost_us/.brost      ->  ~/personal_files/brost_us
/mnt/d/ETS/PIAAC/pds-builder/.brost  ->  ~/personal_files/pds-builder
```

You work in `.brost/` from inside the project as if it were a normal folder. The bytes live in the
central tree, which you back up or version control once, separately from any project.

## Why a symlink rather than an ignored folder

A gitignored real folder inside the project looks equivalent and is not. `git clean -xdf` deletes
ignored directories:

```
$ git clean -xdf
Removing brost          <- a symlink: only the link is removed
Removing realdir/       <- a real folder: contents destroyed
```

With a symlink, git removes the link and the content behind it is untouched. Re-run the setup script
and you are back. That difference is the main reason to prefer this over simply ignoring a folder.

It also means one central location to back up instead of notes scattered across every repo.

## Choosing the link name

Two rules, both learned the hard way:

**Do not use a generic name.** `docs/` already exists in real projects — 12 of them across this
registry — and carries a meaning readers expect. A reader who sees `docs/` reasonably assumes it is
project documentation that belongs in the repo.

**Anchor the git exclude with a leading slash, and never add a trailing one.** A bare pattern in a
global excludes file matches at every depth:

```
pattern 'brost'     ->  ./brost            IGNORED
                        ./src/brost/cli.py IGNORED   <- your own source package
pattern '/brost'    ->  ./brost            IGNORED
                        ./src/brost/cli.py tracked
```

Already-tracked files stay tracked, so nothing breaks loudly — but *new* files under the collided
path get silently ignored.

The trailing slash is the trap. `/brost/` looks safer — it restricts the pattern to directories —
but **git classifies a symlink as a file regardless of what it points at**, so a directory-only
pattern never matches the link and it stays visible in every `git status`. Verified on both ext4 and
NTFS working trees:

```
/.brost/   ->  git status shows .brost   (pattern does not match)
/.brost    ->  ignored                   (correct)
```

The leading slash alone is what prevents the collision; the trailing slash only breaks matching.

A leading dot is worth preferring. It sits naturally beside `.claude`, and most tooling skips
dot-directories by default — pytest's `norecursedirs` includes `.*`, ripgrep skips hidden paths — so
notes cannot break test collection or pollute a codebase search. The cost is `rg --hidden` when you
do want to search them, which is usually the behaviour you want anyway.

## Setup

**1. Configure.**

```bash
cp personal-links.example.conf personal-links.conf
```

`LINK=<name>:<root>` is repeatable — one entry per link you want in every project:

```
LINK=.brost:/mnt/h/personal_files
LINK=.claude:/mnt/h/claude_files
```

Add `EXCLUDE` lines for projects to skip. `personal-links.conf` is gitignored; the example is the
committed schema.

**2. Set the global git exclude**, once, covering every repo forever:

```bash
git config --global core.excludesFile ~/.gitignore_global
printf '/.brost\n' >> ~/.gitignore_global
```

Leading slash, no trailing slash — see "Choosing the link name" above for why the trailing slash
silently fails. This avoids touching any project's tracked `.gitignore`, so your personal layout
never appears in a shared file or someone else's diff.

**3. Create the links.**

```bash
./scripts/personal-links.sh            # report what would change
./scripts/personal-links.sh --apply    # create them
```

**4. Register the tree as an additional directory** so writes through the link are not fighting the
workspace boundary. In `.claude/settings.json`:

```json
{ "permissions": { "additionalDirectories": ["~/personal_files"] } }
```

## Repairing

Links get removed — `git clean`, a fresh clone, a project moved. The script is idempotent, so
re-running it restores whatever is missing:

```bash
./scripts/personal-links.sh --apply
```

It reads project paths from `projects.md`, so there is no second list to keep in sync with the
registry. Adding a project to the registry and re-running is all that is needed.

Modes:

| Command | Effect |
|---|---|
| *(no flag)* | Report only. Nothing on disk is touched. Exit 1 if action is needed. |
| `--apply` | Create missing folders and links. |
| `--fix` | Also repoint links aimed at the wrong target. |
| `--migrate` | Move an existing real folder into its tree and replace it with a link. |
| `--list` | Print the resolved mapping and exit. |

## Adopting a link name that already exists

`.claude` is the common case: the directory is already there as real content in most projects, so
`--apply` reports it as `BLOCKED` and leaves it alone. `--migrate` moves it into the tree and puts a
link in its place. It refuses in two situations rather than guessing:

- **The target already holds content.** Merging two directories is not something a script should
  decide. Merge by hand, then re-run.
- **The directory holds git-tracked files.** Moving tracked files out of a working tree registers as
  deletions, so committing afterwards would remove them for everyone else. The script prints the
  `git rm -r --cached` needed to untrack them first.

That second guard matters more than it sounds. `.claude/settings.local.json` is committed in some
repos despite being local-by-name, and a repo can carry another person's Claude memory files under
`.claude/projects/`. Check what is tracked before untracking anything:

```bash
git ls-files .claude
```

Close any running session in a project before migrating its `.claude`, since the directory moves out
from under it.

## What the script will not do

- **Never deletes a real directory.** If something that is not a symlink already occupies the link
  path, it is reported as `BLOCKED` and left alone under every flag, including `--fix`.
- **Never deletes content behind a link.** `--fix` replaces the symlink itself; whatever the old
  target pointed at stays where it is.
- **Refuses on a name collision.** Two registered projects whose directories share a folder name
  would resolve to one personal folder and silently share notes. The script exits with an error
  rather than linking either.
- **Skips projects not present on this machine** rather than failing, so the same config works
  across machines that check out different subsets.

## Excluding projects whose contents get copied

Some projects are **build inputs**: their whole directory is rsync'd or copied into a build tree by
tooling that then walks everything it finds. A symlink pointing at a path that tooling cannot
resolve becomes a hard failure there.

This is not hypothetical. On 2026-08-21 a PIAAC national PDS build died at the packaging step:

```
Packaging with electron-packager...
EACCES: permission denied, stat 'D:\ETS-LSA\BUILDDIR\PDS_SVN_20260821\.brost'
```

`pds-builder` does `rsync -az "$REPODIR/pds/" "$WD/"` and `cp -r "$REPODIR/QAT-Runtime/"*`, which
copied `.brost` and `.claude` into the build tree. Windows `node.exe` cannot stat a WSL absolute
path, and `builder.sh` runs under `set -e`, so the whole build aborted. It would have broken **every
build on that machine, for every country**, until the links were removed.

**Rule: exclude any project whose directory is copied wholesale by other tooling**, especially when
the consumer is on a different platform (Windows tools reading a WSL symlink) or inside a container.

```
EXCLUDE=pds
EXCLUDE=QAT-Runtime
```

Two things make this class of failure easy to miss:

- It appears at the **consumer**, not the project — nothing looks wrong in the repo itself.
- It surfaces only when that tooling next runs, which may be weeks after the links are created. The
  build above was the first since the links went in.

Before adding a project to the registry, ask whether anything copies its directory somewhere else.
If so, exclude it: the personal folder buys nothing in a repo you do not sit and work in, and costs
a broken build.

## Backing up the tree

The central tree is ordinary content, so back it up however you back up anything else. A private git
repo adds version history, which file-level backup does not.

One caution if you extend this to `.claude/` as well: those directories can contain credentials —
`settings.local.json` holds permission grants and, in at least one project here, a long-lived API
token. A private repo is not the same as a safe one. Exclude `settings.local.json`, or keep the
Claude tree out of git and let ordinary backup cover it.
