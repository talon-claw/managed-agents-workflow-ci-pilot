#!/usr/bin/env sh
set -eu

usage() {
    printf '%s\n' "Usage: $0 --task <specs/tasks/task_id.md> --run-id <run_id>" >&2
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

validate_segment() {
    value=$1
    name=$2
    case "$value" in
        ""|*/*|*..*|.*)
            die "$name contains an invalid path segment: $value"
            ;;
    esac
}

is_placeholder() {
    value=$(trim "$1")
    case "$value" in
        ""|\[*\]|TBD|TODO|tbd|todo) return 0 ;;
        *) return 1 ;;
    esac
}

task_spec=
run_id=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --task)
            [ "$#" -ge 2 ] || usage
            task_spec=$2
            shift 2
            ;;
        --run-id)
            [ "$#" -ge 2 ] || usage
            run_id=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$task_spec" ] || usage
[ -n "$run_id" ] || usage
[ -f "$task_spec" ] || die "task spec not found: $task_spec"

task_id=$(field_value task_id)
[ -n "$task_id" ] || die "task spec missing task_id"
validate_segment "$task_id" "task_id"
validate_segment "$run_id" "run_id"
risk_level=$(field_value risk_level)
review_notes=$(field_value review_notes)
rollback_considerations=$(field_value rollback_considerations)

if repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    repo_root=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$repo_root")
else
    die "not inside a git worktree"
fi

artifact_dir="$repo_root/artifacts/tasks/$task_id/$run_id"
mkdir -p "$artifact_dir"
review_log="$artifact_dir/review.txt"

status=PASS
message=
exit_code=0

case "$risk_level" in
    low)
        message="low-risk task passes local review-check"
        ;;
    medium)
        if is_placeholder "$review_notes"; then
            status=BLOCK
            message="medium-risk task requires non-placeholder review_notes"
            exit_code=1
        elif is_placeholder "$rollback_considerations"; then
            status=BLOCK
            message="medium-risk task requires non-placeholder rollback_considerations"
            exit_code=1
        else
            message="medium-risk task includes review_notes and rollback_considerations"
        fi
        ;;
    high)
        status=BLOCK
        message="high-risk task requires explicit human approval and cannot pass review-check locally"
        exit_code=1
        ;;
    *)
        status=BLOCK
        message="task spec contains unknown risk_level: $risk_level"
        exit_code=1
        ;;
esac

{
    printf '%s\n' "risk_level=$risk_level"
    printf '%s\n' "status=$status"
    printf '%s\n' "message=$message"
} > "$review_log"

exit "$exit_code"
