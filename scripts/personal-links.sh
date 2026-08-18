#!/usr/bin/env bash
#
# personal-links.sh — create and repair per-project linked folders.
#
# Each registered project gets one symlink per configured LINK, pointing at that
# project's own directory under a central tree. Those trees are backed up or
# version controlled separately, so the content never enters a project's git
# history and never has to be re-created by hand.
#
# Project paths are read from projects.md, so there is no second list to keep in
# sync with the registry.
#
# Usage:
#   ./scripts/personal-links.sh            report status, change nothing
#   ./scripts/personal-links.sh --apply    create missing folders and links
#   ./scripts/personal-links.sh --fix      also repoint links aimed elsewhere
#   ./scripts/personal-links.sh --migrate  move an existing real folder into the
#                                          tree and replace it with a link
#   ./scripts/personal-links.sh --list     show the resolved mapping and exit
#
# Safe by default: without a flag nothing on disk is touched. A real
# (non-symlink) directory is only ever moved by --migrate, never deleted.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$REPO_DIR/projects.md"
CONFIG="$REPO_DIR/personal-links.conf"

MODE="check"
case "${1:-}" in
    "")        MODE="check" ;;
    --apply)   MODE="apply" ;;
    --fix)     MODE="fix" ;;
    --migrate) MODE="migrate" ;;
    --list)    MODE="list" ;;
    -h|--help) sed -n '3,23p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
    *)         echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------- config ----

if [[ ! -f "$CONFIG" ]]; then
    cat >&2 <<EOF
No config found at:
  $CONFIG

Copy the template and edit it:
  cp personal-links.example.conf personal-links.conf
EOF
    exit 2
fi

LINK_NAMES=()
LINK_ROOTS=()
EXCLUDES=()

trim() { echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'; }

# Parsed by hand rather than sourced, so the config cannot execute anything.
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(trim "$line")"
    [[ -z "$line" ]] && continue
    key="$(trim "${line%%=*}")"
    val="$(trim "${line#*=}")"
    case "$key" in
        LINK)
            name="$(trim "${val%%:*}")"
            root="$(trim "${val#*:}")"
            if [[ "$val" != *:* || -z "$name" || -z "$root" ]]; then
                echo "config error: LINK must be '<name>:<root>', got: $val" >&2; exit 2
            fi
            case "$name" in
                */*)  echo "config error: LINK name must be a bare name: $name" >&2; exit 2 ;;
                .|..) echo "config error: LINK name must not be . or .." >&2; exit 2 ;;
            esac
            for existing in ${LINK_NAMES[@]+"${LINK_NAMES[@]}"}; do
                [[ "$existing" == "$name" ]] && { echo "config error: LINK '$name' declared twice" >&2; exit 2; }
            done
            LINK_NAMES+=("$name")
            LINK_ROOTS+=("${root/#\~/$HOME}")
            ;;
        EXCLUDE) EXCLUDES+=("$val") ;;
        *)       echo "warning: ignoring unknown config key '$key'" >&2 ;;
    esac
done < "$CONFIG"

[[ ${#LINK_NAMES[@]} -gt 0 ]] || { echo "config error: no LINK entries defined" >&2; exit 2; }
[[ -f "$REGISTRY" ]] || { echo "no registry at $REGISTRY" >&2; exit 2; }

# ------------------------------------------------------------ discovery ----

mapfile -t PROJECTS < <(
    grep -oP '\*\*Path:\*\*\s*\K.+' "$REGISTRY" | sed 's/[[:space:]]*$//' | grep -v '^$'
)

is_excluded() {
    local path="$1" base; base="$(basename "$path")"
    local ex
    for ex in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
        [[ "$base" == "$ex" || "$path" == "$ex" ]] && return 0
    done
    return 1
}

# Two projects resolving to one folder would silently share content.
declare -A SEEN_BASE=()
COLLISION=0
for p in "${PROJECTS[@]}"; do
    b="$(basename "$p")"
    if [[ -n "${SEEN_BASE[$b]:-}" ]]; then
        echo "ERROR: '$b' is the folder name for two registered projects:" >&2
        echo "         ${SEEN_BASE[$b]}" >&2
        echo "         $p" >&2
        COLLISION=1
    fi
    SEEN_BASE[$b]="$p"
done
[[ "$COLLISION" -eq 0 ]] || { echo "Resolve the collision before linking." >&2; exit 2; }

# ----------------------------------------------------------------- run -----

ok=0; created=0; migrated=0; missing=0; wrong=0; blocked=0; absent=0; skipped=0

for project in "${PROJECTS[@]}"; do
    expanded="${project/#\~/$HOME}"

    if is_excluded "$project"; then
        skipped=$((skipped + ${#LINK_NAMES[@]})); continue
    fi
    if [[ ! -d "$expanded" ]]; then
        printf '  absent   %s (not on this machine)\n' "$project"
        absent=$((absent + ${#LINK_NAMES[@]})); continue
    fi

    base="$(basename "$expanded")"

    for i in "${!LINK_NAMES[@]}"; do
        link_name="${LINK_NAMES[$i]}"
        target="${LINK_ROOTS[$i]}/$base"
        linkpath="$expanded/$link_name"

        if [[ "$MODE" == "list" ]]; then
            printf '  %s -> %s\n' "$linkpath" "$target"; continue
        fi

        if [[ -L "$linkpath" ]]; then
            current="$(readlink "$linkpath")"
            if [[ "$current" == "$target" ]]; then
                ok=$((ok + 1)); continue
            fi
            if [[ "$MODE" == "fix" ]]; then
                rm "$linkpath"                  # a symlink only, never content
                mkdir -p "$target"
                ln -s "$target" "$linkpath"
                printf '  repointed %s\n             was %s\n             now %s\n' "$linkpath" "$current" "$target"
                created=$((created + 1))
            else
                printf '  WRONG    %s -> %s (expected %s)\n' "$linkpath" "$current" "$target"
                wrong=$((wrong + 1))
            fi
            continue
        fi

        if [[ -e "$linkpath" ]]; then
            # A real file or directory. Only --migrate may move it; nothing deletes it.
            if [[ "$MODE" == "migrate" && -d "$linkpath" ]]; then
                # Moving a tracked directory out of the working tree registers as
                # deletions, which would remove those files for everyone else.
                if git -C "$expanded" rev-parse --git-dir >/dev/null 2>&1 \
                   && [[ -n "$(git -C "$expanded" ls-files "$link_name" 2>/dev/null)" ]]; then
                    printf '  BLOCKED  %s holds git-TRACKED files — untrack first:\n             git -C %q rm -r --cached %s\n' \
                        "$linkpath" "$expanded" "$link_name"
                    blocked=$((blocked + 1)); continue
                fi
                if [[ -e "$target" ]] && [[ -n "$(ls -A "$target" 2>/dev/null)" ]]; then
                    printf '  BLOCKED  %s exists AND %s is non-empty — merge by hand\n' "$linkpath" "$target"
                    blocked=$((blocked + 1)); continue
                fi
                mkdir -p "$(dirname "$target")"
                rm -rf "$target"                # only ever an empty dir at this point
                mv "$linkpath" "$target"
                ln -s "$target" "$linkpath"
                printf '  migrated %s -> %s\n' "$linkpath" "$target"
                migrated=$((migrated + 1))
            else
                printf '  BLOCKED  %s exists and is not a symlink — left alone\n' "$linkpath"
                blocked=$((blocked + 1))
            fi
            continue
        fi

        if [[ "$MODE" == "apply" || "$MODE" == "fix" || "$MODE" == "migrate" ]]; then
            mkdir -p "$target"
            ln -s "$target" "$linkpath"
            printf '  created  %s -> %s\n' "$linkpath" "$target"
            created=$((created + 1))
        else
            printf '  missing  %s -> %s\n' "$linkpath" "$target"
            missing=$((missing + 1))
        fi
    done
done

[[ "$MODE" == "list" ]] && exit 0

echo
printf 'ok %d, created %d, migrated %d, missing %d, wrong-target %d, blocked %d, absent %d, excluded %d\n' \
    "$ok" "$created" "$migrated" "$missing" "$wrong" "$blocked" "$absent" "$skipped"

# --------------------------------------------------------- gitignore ------

excludes_file="$(git config --global core.excludesFile 2>/dev/null || true)"
excludes_file="${excludes_file/#\~/$HOME}"
unset_patterns=()
for name in "${LINK_NAMES[@]}"; do
    pattern="/$name"
    if [[ -z "$excludes_file" || ! -f "$excludes_file" ]] || ! grep -qxF "$pattern" "$excludes_file"; then
        unset_patterns+=("$pattern")
    fi
done

if [[ ${#unset_patterns[@]} -gt 0 ]]; then
    echo
    echo "These global git excludes are missing. Without them the links show as"
    echo "untracked files in every repo:"
    echo
    echo "  git config --global core.excludesFile ~/.gitignore_global"
    for p in "${unset_patterns[@]}"; do
        printf "  printf '%%s\\\\n' '%s' >> ~/.gitignore_global\n" "$p"
    done
    cat <<'EOF'

The leading slash anchors each pattern to the repo root, so a source package
deeper in the tree that happens to share the name is not affected.

Do NOT add a trailing slash. A trailing slash restricts a pattern to
directories, and git classifies a symlink as a file no matter what it points
at, so the pattern silently fails to match and the link stays visible.
EOF
fi

if [[ "$blocked" -gt 0 && "$MODE" != "migrate" ]]; then
    echo
    echo "Blocked entries are real directories, not links. Run with --migrate to move"
    echo "each into its tree and replace it with a link. Close any running session in"
    echo "those projects first."
fi

if [[ "$missing" -gt 0 || "$wrong" -gt 0 ]]; then
    echo
    echo "Run with --apply to create missing links, or --fix to also repoint wrong ones."
    exit 1
fi
exit 0
