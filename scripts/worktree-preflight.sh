#!/usr/bin/env sh
set -eu

usage() {
    printf '%s\n' "Usage: $0 --task <specs/tasks/task_id.md>" >&2
    exit 2
}

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

field_value() {
    label=$1
    value=$(sed -n "s/^- \*\*$label\*\*:[[:space:]]*//p" "$task_spec" | sed -n '1p')
    trim "$value"
}

abs_path() {
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

resolve_base_ref() {
    candidate=$1
    if git rev-parse --verify "$candidate^{commit}" >/dev/null 2>&1; then
        printf '%s\n' "$candidate"
        return 0
    fi

    remote_candidate="origin/$candidate"
    if git rev-parse --verify "$remote_candidate^{commit}" >/dev/null 2>&1; then
        printf '%s\n' "$remote_candidate"
        return 0
    fi

    die "base_ref is not a valid commit or branch: $candidate"
}

validate_segment() {
    value=$1
    name=$2
    case "$value" in
        ""|*/*|*..*|.*)
            die "$name contains an invalid path segment: $value"
            ;;
    esac
}

task_spec=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --task)
            [ "$#" -ge 2 ] || usage
            task_spec=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$task_spec" ] || usage
[ -f "$task_spec" ] || die "task spec not found: $task_spec"

task_spec=$(abs_path "$task_spec")
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git worktree"
repo_root=$(abs_path "$repo_root")
main_worktree=$(git worktree list --porcelain | sed -n 's/^worktree //p' | sed -n '1p')
main_worktree=$(abs_path "$main_worktree")
scheduler_dry_run=${SCHEDULER_DRY_RUN:-0}

task_id=$(field_value task_id)
change_id=$(field_value change_id)
base_ref=$(field_value base_ref)

[ -n "$task_id" ] || die "task spec missing task_id"
[ -n "$change_id" ] || die "task spec missing change_id"
validate_segment "$task_id" "task_id"
validate_segment "$change_id" "change_id"
[ -n "$base_ref" ] || base_ref=main
resolved_base_ref=$(resolve_base_ref "$base_ref")

expected_task_spec="$repo_root/specs/tasks/$task_id.md"
[ "$task_spec" = "$expected_task_spec" ] || die "task spec path must be specs/tasks/$task_id.md"
if [ "$scheduler_dry_run" != "1" ]; then
    [ "$(basename "$repo_root")" = "$task_id" ] || die "worktree root directory name must match task_id"
    [ "$repo_root" != "$main_worktree" ] || die "task must not execute in the main worktree"
fi

change_dir="$repo_root/openspec/changes/$change_id"
[ -d "$change_dir" ] || die "active change directory not found: $change_dir"
grep -Fq "$task_id" "$change_dir/tasks.md" || die "change tasks.md must reference task_id"
git merge-base --is-ancestor "$resolved_base_ref" HEAD >/dev/null 2>&1 || die "HEAD must descend from base_ref"
if [ "$scheduler_dry_run" != "1" ]; then
    status_output=$(git status --porcelain)
    [ -z "$status_output" ] || die "worktree must be clean before validation begins"
fi

printf '%s\n' "task_id=$task_id"
printf '%s\n' "change_id=$change_id"
printf '%s\n' "base_ref=$base_ref"
printf '%s\n' "head_sha=$(git rev-parse HEAD)"
