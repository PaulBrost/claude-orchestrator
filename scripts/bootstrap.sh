#!/usr/bin/env bash
#
# bootstrap.sh — clone registered projects onto a new machine.
#
# Reads **Path:**, **Repo:** and **Branch:** from projects.md and clones anything
# that is registered but not present. Projects that already exist are checked
# rather than touched: it reports when a working copy's remote or branch has
# drifted from what the registry claims, which is how a wrong-remote or
# wrong-branch checkout gets noticed before it causes damage.
#
# This gets you repositories, not running projects. Secrets, SSH keys and
# toolchains are deliberately out of scope — run --checklist for those, and see
# docs/new-machine.md.
#
# Usage:
#   ./scripts/bootstrap.sh             report what is missing or drifted
#   ./scripts/bootstrap.sh --apply     clone the missing projects
#   ./scripts/bootstrap.sh --list      show the resolved registry mapping
#   ./scripts/bootstrap.sh --checklist print the manual steps this cannot do
#
# Safe by default: without --apply nothing on disk is touched. Existing working
# copies are never modified, and drift is never "fixed" automatically — checking
# out a different branch can discard uncommitted work, so that stays a human
# decision.
#
# Order matters on a fresh machine: SSH keys and ~/.ssh/config must exist before
# cloning, or every git@ remote fails. Run --checklist first.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$REPO_DIR/projects.md"

MODE="check"
case "${1:-}" in
    "")          MODE="check" ;;
    --apply)     MODE="apply" ;;
    --list)      MODE="list" ;;
    --checklist) MODE="checklist" ;;
    -h|--help)   sed -n '3,26p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
    *)           echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

if [[ "$MODE" == "checklist" ]]; then
    cat <<'EOF'
Things bootstrap.sh cannot do. Work top to bottom — cloning fails without step 1.

1. SSH keys and config
   Restore your keys to ~/.ssh (native filesystem only — NTFS mounts such as
   /mnt/h and /mnt/d cannot hold 0600 permissions and ssh will refuse them).
   Recreate every Host alias the registry's remotes rely on; a remote of the
   form git@<alias>:... is broken until its alias exists in ~/.ssh/config.

2. Credential helper for HTTPS remotes
   Registry URLs deliberately carry no username or password. Configure a
   credential helper or ~/.netrc for the hosts you clone over HTTPS.

3. Per-project secrets (gitignored, never in any repo)
   .env files, API keys, database credentials, tokens and any local-only
   config the registry notes mention. These come from your password manager or
   a backup, one project at a time.

4. Toolchains
   Language runtimes and version managers at the versions individual projects
   pin, plus any system tools their notes call for. Check each project's own
   CLAUDE.md and docs.

5. Non-git working copies
   Anything registered with an svn+ or other non-git remote needs its own
   checkout and credentials.

6. Project setup
   Dependency installs, virtualenvs, database creation and migrations are per
   project. Follow each project's own documentation.

Then run:  ./scripts/personal-links.sh --apply
EOF
    exit 0
fi

if [[ ! -f "$REGISTRY" ]]; then
    cat >&2 <<EOF
No registry found at:
  $REGISTRY

Copy the template and fill it in:
  cp projects.example.md projects.md
EOF
    exit 2
fi

# Parsed with awk into tab-separated records so paths containing spaces survive.
parse_registry() {
    awk '
        function flush() {
            if (path != "") printf "%s\t%s\t%s\t%s\n", name, path, repo, branch
            path = ""; repo = ""; branch = ""
        }
        function field(line) {
            sub(/^[^:]*:\*\*[[:space:]]*/, "", line)
            gsub(/[[:space:]]+$/, "", line)
            return line
        }
        # Anchored to the start of the line: prose in a Notes field can mention
        # **Repo:** while discussing the registry, and an unanchored match would
        # silently take the whole sentence as the field value.
        /^###[[:space:]]/                              { flush(); name = substr($0, 5); next }
        /^[[:space:]]*-?[[:space:]]*\*\*Path:\*\*/     { path   = field($0); next }
        /^[[:space:]]*-?[[:space:]]*\*\*Repo:\*\*/     { repo   = field($0); next }
        /^[[:space:]]*-?[[:space:]]*\*\*Branch:\*\*/   { branch = field($0); next }
        END { flush() }
    ' "$REGISTRY"
}

expand() { local p="$1"; echo "${p/#\~/$HOME}"; }

# Compare remotes ignoring embedded credentials and a trailing .git, so a working
# copy cloned with a username in the URL is not reported as drift.
normalize_url() {
    local u="$1"
    u="${u%.git}"
    u="$(echo "$u" | sed -E 's#^(https?://)[^/@]*@#\1#')"
    echo "$u"
}

n_ok=0; n_missing=0; n_drift=0; n_skip=0; n_manual=0; n_cloned=0; n_failed=0
MISSING_PATHS=()

printf '\n'
while IFS=$'\t' read -r name path repo branch; do
    [[ -z "$path" ]] && continue
    epath="$(expand "$path")"
    name="${name:0:28}"

    if [[ "$MODE" == "list" ]]; then
        printf '  %-28s %-42s %s %s\n' "$name" "$path" "${repo:-<none>}" "${branch:+[$branch]}"
        continue
    fi

    if [[ -z "$repo" || "$repo" == "none" ]]; then
        # Drift in the other direction: the registry claims no repo, but a real
        # one is sitting there. Worth reporting — it is usually either an
        # unregistered remote or a leftover origin from scaffolding.
        if [[ -d "$epath" ]] && git -C "$epath" rev-parse --git-dir >/dev/null 2>&1; then
            stray="$(git -C "$epath" remote get-url origin 2>/dev/null || echo '')"
            if [[ -n "$stray" ]]; then
                printf '  %-28s DRIFT     registry says none, but origin is %s\n' \
                    "$name" "$(normalize_url "$stray")"
                n_drift=$((n_drift + 1)); continue
            fi
        fi
        if [[ -d "$epath" ]]; then
            printf '  %-28s skip      not version controlled here\n' "$name"
        else
            printf '  %-28s SKIP      no repo registered, and %s is absent\n' "$name" "$path"
        fi
        n_skip=$((n_skip + 1)); continue
    fi

    if [[ "$repo" == svn+* || "$repo" != *:* ]]; then
        printf '  %-28s MANUAL    non-git remote, check out by hand: %s\n' "$name" "${repo#svn+}"
        n_manual=$((n_manual + 1)); continue
    fi

    if [[ ! -d "$epath" ]]; then
        if [[ "$MODE" == "apply" ]]; then
            printf '  %-28s cloning   %s\n' "$name" "$repo"
            parent="$(dirname "$epath")"
            if ! mkdir -p "$parent"; then
                printf '  %-28s FAILED    cannot create %s\n' "$name" "$parent"
                n_failed=$((n_failed + 1)); continue
            fi
            if git clone ${branch:+--branch "$branch"} -- "$repo" "$epath" >/dev/null 2>&1; then
                printf '  %-28s cloned    %s%s\n' "$name" "$path" "${branch:+ [$branch]}"
                n_cloned=$((n_cloned + 1))
            else
                printf '  %-28s FAILED    clone failed (auth? branch %s? host reachable?)\n' \
                    "$name" "${branch:-default}"
                n_failed=$((n_failed + 1))
            fi
        else
            printf '  %-28s MISSING   would clone %s%s\n' "$name" "$repo" "${branch:+ [$branch]}"
            MISSING_PATHS+=("$path")
            n_missing=$((n_missing + 1))
        fi
        continue
    fi

    if ! git -C "$epath" rev-parse --git-dir >/dev/null 2>&1; then
        printf '  %-28s DRIFT     %s exists but is not a git repo\n' "$name" "$path"
        n_drift=$((n_drift + 1)); continue
    fi

    actual_url="$(git -C "$epath" remote get-url origin 2>/dev/null || echo '')"
    actual_branch="$(git -C "$epath" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
    drifted=""

    if [[ -z "$actual_url" ]]; then
        drifted="no origin remote"
    elif [[ "$(normalize_url "$actual_url")" != "$(normalize_url "$repo")" ]]; then
        drifted="origin is $(normalize_url "$actual_url")"
    fi

    if [[ -n "$branch" && "$actual_branch" != "$branch" ]]; then
        drifted="${drifted:+$drifted; }on branch $actual_branch, registry says $branch"
    fi

    if [[ -n "$drifted" ]]; then
        printf '  %-28s DRIFT     %s\n' "$name" "$drifted"
        n_drift=$((n_drift + 1))
    else
        printf '  %-28s ok\n' "$name"
        n_ok=$((n_ok + 1))
    fi
done < <(parse_registry)

[[ "$MODE" == "list" ]] && exit 0

printf '\n'
if [[ "$MODE" == "apply" ]]; then
    printf '  cloned %d, failed %d, skipped %d, manual %d\n' \
        "$n_cloned" "$n_failed" "$n_skip" "$n_manual"
    printf '\n  Next:  ./scripts/personal-links.sh --apply\n'
    printf '         ./scripts/bootstrap.sh --checklist   (secrets, keys, toolchains)\n\n'
    [[ "$n_failed" -gt 0 ]] && exit 1
else
    printf '  %d ok, %d missing, %d drifted, %d skipped, %d manual\n' \
        "$n_ok" "$n_missing" "$n_drift" "$n_skip" "$n_manual"
    if [[ "$n_missing" -gt 0 ]]; then
        printf '\n  Run with --apply to clone the %d missing project(s).\n' "$n_missing"
    fi
    if [[ "$n_drift" -gt 0 ]]; then
        printf '\n  Drift is reported, never corrected — switching a branch or remote can\n'
        printf '  discard uncommitted work. Resolve each by hand, or fix the registry if\n'
        printf '  the working copy is right and the registry is stale.\n'
    fi
    printf '\n'
fi
