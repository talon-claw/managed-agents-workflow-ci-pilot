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

abs_path() {
    python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
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

resolve_repo_path() {
    rel_path=$1
    [ -n "$repo_root" ] || return 1
    python3 - "$repo_root" "$rel_path" "$run_id" <<'PY'
import os
import sys

repo_root = os.path.realpath(sys.argv[1])
rel_path = sys.argv[2].replace('<run_id>', sys.argv[3])
if not rel_path or os.path.isabs(rel_path):
    sys.exit(1)
resolved = os.path.realpath(os.path.join(repo_root, rel_path))
repo_prefix = repo_root + os.sep
if resolved != repo_root and not resolved.startswith(repo_prefix):
    sys.exit(1)
print(resolved)
PY
}

current_run_artifact_path() {
    rel_path=$1
    normalized_path=$(printf '%s' "$rel_path" | sed "s#<run_id>#$run_id#g")
    case "$normalized_path" in
        "artifacts/tasks/$task_id/$run_id/"*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

script_for_method() {
    script_name=
    case "$1" in
        lint) script_name=lint.sh ;;
        typecheck) script_name=typecheck.sh ;;
        test-unit) script_name=test-unit.sh ;;
        test-integration) script_name=test-integration.sh ;;
        test-e2e) script_name=test-e2e.sh ;;
        *) return 1 ;;
    esac

    primary="$repo_root/scripts/$script_name"
    if [ -x "$primary" ]; then
        printf '%s\n' "$primary"
        return 0
    fi

    script_dir=$(python3 -c 'import os,sys; print(os.path.realpath(os.path.dirname(sys.argv[1])))' "$0")
    fallback="$script_dir/$script_name"
    if [ -x "$fallback" ]; then
        printf '%s\n' "$fallback"
        return 0
    fi

    return 1
}

validation_rows() {
    awk '
        BEGIN { in_table = 0 }
        /^## Validation Matrix$/ { in_table = 1; next }
        in_table && /^## / { exit }
        in_table && /^\|/ {
            line = $0
            gsub(/^\|/, "", line)
            gsub(/\|$/, "", line)
            n = split(line, cells, "|")
            if (n != 4) next
            for (i = 1; i <= 4; i++) {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", cells[i])
            }
            if (cells[1] == "Requirement" || cells[1] ~ /^-+$/) next
            print cells[1] "\t" cells[2] "\t" cells[3] "\t" cells[4]
        }
    ' "$task_spec"
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

if repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    repo_root=$(abs_path "$repo_root")
else
    die "not inside a git worktree"
fi

task_id=$(field_value task_id)
change_id=$(field_value change_id)
base_ref=$(field_value base_ref)
[ -n "$base_ref" ] || base_ref=main
[ -n "$task_id" ] || die "task spec missing task_id"
[ -n "$change_id" ] || die "task spec missing change_id"
validate_segment "$task_id" "task_id"
validate_segment "$change_id" "change_id"
validate_segment "$run_id" "run_id"

artifact_dir="$repo_root/artifacts/tasks/$task_id/$run_id"
mkdir -p "$artifact_dir"
verify_log="$artifact_dir/verify.txt"
: > "$verify_log"

validation_tmp=$(mktemp)
validation_rows > "$validation_tmp"

pass_count=0
fail_count=0
skip_count=0
rows_seen=0

while IFS="$(printf '\t')" read -r requirement method evidence status; do
    [ -n "$requirement" ] || continue
    rows_seen=$((rows_seen + 1))
    method=$(trim "$method")
    evidence=$(trim "$evidence")
    status=$(trim "$status")

    if [ "$status" = "skip" ]; then
        case "$evidence" in
            skip:*)
                skip_count=$((skip_count + 1))
                printf '%s\n' "SKIP | $requirement | $method | $evidence" >> "$verify_log"
                ;;
            *)
                fail_count=$((fail_count + 1))
                printf '%s\n' "FAIL | $requirement | malformed skip evidence: $evidence" >> "$verify_log"
                ;;
        esac
        continue
    fi

    case "$evidence" in
        path:*)
            rel_path=${evidence#path:}
            resolved_path=$(resolve_repo_path "$rel_path") || {
                fail_count=$((fail_count + 1))
                printf '%s\n' "FAIL | $requirement | evidence must stay within repo: $evidence" >> "$verify_log"
                continue
            }
            evidence_deferred=0
            if [ ! -e "$resolved_path" ]; then
                if current_run_artifact_path "$rel_path"; then
                    evidence_deferred=1
                    printf '%s\n' "DEFER | $requirement | evidence generated later in current run: $rel_path" >> "$verify_log"
                else
                    fail_count=$((fail_count + 1))
                    printf '%s\n' "FAIL | $requirement | missing evidence path: $rel_path" >> "$verify_log"
                    continue
                fi
            fi
            ;;
        *)
            fail_count=$((fail_count + 1))
            printf '%s\n' "FAIL | $requirement | non-skip evidence must use path:<repo-relative-path>: $evidence" >> "$verify_log"
            continue
            ;;
    esac

    script_path=$(script_for_method "$method") || {
        fail_count=$((fail_count + 1))
        printf '%s\n' "FAIL | $requirement | unsupported verification method: $method" >> "$verify_log"
        continue
    }

    printf '%s\n' "RUN | $requirement | $script_path" >> "$verify_log"
    if TASK_SPEC_PATH="$task_spec" TASK_ID="$task_id" CHANGE_ID="$change_id" BASE_REF="$base_ref" RUN_ID="$run_id" REPO_ROOT="$repo_root" EVIDENCE_PATH="$rel_path" VALIDATION_REQUIREMENT="$requirement" "$script_path" >> "$verify_log" 2>&1; then
        if [ "$evidence_deferred" -eq 1 ] || [ -e "$resolved_path" ]; then
            pass_count=$((pass_count + 1))
            if [ "$evidence_deferred" -eq 1 ]; then
                printf '%s\n' "PASS | $requirement | $script_path | evidence deferred to acceptance: $rel_path" >> "$verify_log"
            else
                printf '%s\n' "PASS | $requirement | $script_path" >> "$verify_log"
            fi
        else
            fail_count=$((fail_count + 1))
            printf '%s\n' "FAIL | $requirement | verification passed but evidence is still missing: $rel_path" >> "$verify_log"
        fi
    else
        fail_count=$((fail_count + 1))
        printf '%s\n' "FAIL | $requirement | $script_path" >> "$verify_log"
    fi
done < "$validation_tmp"

rm -f "$validation_tmp"

if [ "$rows_seen" -eq 0 ]; then
    fail_count=$((fail_count + 1))
    printf '%s\n' "FAIL | validation matrix must contain at least one row" >> "$verify_log"
fi

printf '%s\n' "SUMMARY | pass=$pass_count fail=$fail_count skip=$skip_count rows=$rows_seen" >> "$verify_log"

[ "$fail_count" -eq 0 ] || exit 1
exit 0
