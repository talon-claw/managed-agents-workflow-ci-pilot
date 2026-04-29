#!/usr/bin/env sh
set -eu

usage() {
    printf '%s\n' "Usage: $0 [watch_file]" >&2
    exit 2
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$repo_root" ] || die "not inside a git repository"
cd "$repo_root"

watch_file=${1:-$repo_root/.config-watch-pathspecs}
[ -f "$watch_file" ] || die "watch file not found: $watch_file"

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

branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" != "HEAD" ] || die "detached HEAD is not supported for auto-push"

if [ -z "$(git status --porcelain --untracked-files=all -- "$@")" ]; then
    printf '%s\n' "no watched config changes"
    exit 0
fi

git add -A -- "$@"

if git diff --cached --quiet; then
    printf '%s\n' "no staged watched config changes"
    exit 0
fi

timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
git commit -m "chore(config): auto-sync watched config updates at $timestamp" --no-verify

git pull --rebase --autostash origin "$branch"
git push origin "$branch"

commit_sha=$(git rev-parse HEAD)
printf '%s\n' "auto-pushed watched config changes on $branch at $commit_sha"
