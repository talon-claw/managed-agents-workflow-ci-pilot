#!/usr/bin/env sh
set -eu

usage() {
    printf '%s\n' "Usage: $0 [--base <rev>] [--head <rev>] [--watch-file <path>]" >&2
    exit 2
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$repo_root" ] || die "not inside a git repository"
cd "$repo_root"

base_ref=HEAD~1
head_ref=HEAD
watch_file="$repo_root/.config-watch-pathspecs"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --base)
            [ "$#" -ge 2 ] || usage
            base_ref=$2
            shift 2
            ;;
        --head)
            [ "$#" -ge 2 ] || usage
            head_ref=$2
            shift 2
            ;;
        --watch-file)
            [ "$#" -ge 2 ] || usage
            watch_file=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -f "$watch_file" ] || die "watch file not found: $watch_file"

git rev-parse --verify "$base_ref^{commit}" >/dev/null 2>&1 || die "invalid base ref: $base_ref"
git rev-parse --verify "$head_ref^{commit}" >/dev/null 2>&1 || die "invalid head ref: $head_ref"

set --
while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
        ''|'#'*)
            continue
            ;;
        *)
            set -- "$@" "$line"
            ;;
    esac
done < "$watch_file"

[ "$#" -gt 0 ] || die "watch file contains no pathspecs: $watch_file"

changed_files=$(git diff --name-only "$base_ref" "$head_ref" -- "$@")
if [ -z "$changed_files" ]; then
    printf '%s\n' "no watched config changes in $base_ref..$head_ref"
    exit 0
fi

printf '%s\n' "reviewing watched config changes in $base_ref..$head_ref"
printf '%s\n' "$changed_files"

# Basic patch hygiene limited to the watched paths in this event.
git diff --check "$base_ref" "$head_ref" -- "$@"

printf '%s\n' "$changed_files" | while IFS= read -r file; do
    [ -n "$file" ] || continue
    case "$file" in
        *.json)
            python3 -m json.tool "$file" >/dev/null
            ;;
        *.yml|*.yaml)
            python3 - "$file" <<'PY'
import sys, yaml
with open(sys.argv[1], 'r', encoding='utf-8') as fh:
    yaml.safe_load(fh)
PY
            ;;
        *.sh)
            sh -n "$file"
            ;;
    esac
done

printf '%s\n' "review passed for watched config changes in $base_ref..$head_ref"
