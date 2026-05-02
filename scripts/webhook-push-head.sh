#!/usr/bin/env sh
set -eu

usage() {
    printf '%s\n' "Usage: $0 --expect-head <sha> [--remote <name>]" >&2
    exit 2
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$repo_root" ] || die "not inside a git repository"
cd "$repo_root"

expect_head=
remote_name=origin

while [ "$#" -gt 0 ]; do
    case "$1" in
        --expect-head)
            [ "$#" -ge 2 ] || usage
            expect_head=$2
            shift 2
            ;;
        --remote)
            [ "$#" -ge 2 ] || usage
            remote_name=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$expect_head" ] || usage

branch=$(git rev-parse --abbrev-ref HEAD)
[ "$branch" != "HEAD" ] || die "detached HEAD is not supported"
current_head=$(git rev-parse HEAD)
[ "$current_head" = "$expect_head" ] || die "HEAD changed since webhook event: expected $expect_head, got $current_head"
[ -z "$(git status --porcelain)" ] || die "repository must be clean before webhook push"

git fetch "$remote_name" "$branch"
remote_head=$(git rev-parse "$remote_name/$branch" 2>/dev/null || true)
if [ -n "$remote_head" ] && [ "$remote_head" = "$current_head" ]; then
    printf '%s\n' "remote already has commit $current_head"
    exit 0
fi

git pull --rebase --autostash "$remote_name" "$branch"
new_head=$(git rev-parse HEAD)
[ "$new_head" = "$expect_head" ] || die "rebase changed HEAD from $expect_head to $new_head; manual review required"

git push "$remote_name" "$branch"
pushed_head=$(git rev-parse HEAD)
printf '%s\n' "pushed watched config commit on $branch at $pushed_head"