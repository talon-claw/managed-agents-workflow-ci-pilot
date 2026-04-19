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

append_evidence_path() {
    rel_path=$1
    [ -n "$rel_path" ] || return 0
    printf '%s\n' "$rel_path" >> "$evidence_paths_tmp"
}

resolve_helper_script() {
    script_name=$1
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

    die "helper script not found: $script_name"
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

required_evidence_entries() {
    awk '
        BEGIN { in_section = 0 }
        /^## Required Evidence$/ { in_section = 1; next }
        in_section && /^## / { exit }
        in_section && /^- \[[ xX]\]/ {
            item = $0
            sub(/^- \[[ xX]\][[:space:]]*/, "", item)
            print item
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

task_id=$(field_value task_id)
change_id=$(field_value change_id)
base_ref=$(field_value base_ref)
[ -n "$base_ref" ] || base_ref=main
risk_level=$(field_value risk_level)

[ -n "$task_id" ] || die "task spec missing task_id"
[ -n "$change_id" ] || die "task spec missing change_id"
validate_segment "$task_id" "task_id"
validate_segment "$change_id" "change_id"
validate_segment "$run_id" "run_id"

current_task_spec=$(abs_path "$task_spec")
if repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    repo_root=$(abs_path "$repo_root")
else
    repo_root=
fi
[ -n "$repo_root" ] || die "not inside a git worktree"
if head_sha=$(git rev-parse HEAD 2>/dev/null); then
    :
else
    head_sha=
fi
worktree_path=$(abs_path "$repo_root")
generated_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
artifact_dir="$repo_root/artifacts/tasks/$task_id/$run_id"
acceptance_log="$artifact_dir/acceptance.txt"
manifest_path="$artifact_dir/manifest.json"
search_plan="$artifact_dir/search-plan.md"
verify_log="$artifact_dir/verify.txt"
review_log="$artifact_dir/review.txt"
change_dir="$repo_root/openspec/changes/$change_id"
status=PASS

scheduler_dry_run=${SCHEDULER_DRY_RUN:-0}
preflight_exit_override=${PREFLIGHT_EXIT_OVERRIDE:-}
verify_exit_override=${VERIFY_EXIT_OVERRIDE:-}
review_exit_override=${REVIEW_EXIT_OVERRIDE:-}
worktree_preflight_script=$(resolve_helper_script worktree-preflight.sh)
verify_script=$(resolve_helper_script verify.sh)
review_script=$(resolve_helper_script review-check.sh)

if [ "$scheduler_dry_run" = "1" ]; then
    if [ -n "$preflight_exit_override" ]; then
        preflight_exit=$preflight_exit_override
    elif SCHEDULER_DRY_RUN=1 "$worktree_preflight_script" --task "$task_spec"; then
        preflight_exit=0
    else
        preflight_exit=$?
    fi
else
    if [ -n "$preflight_exit_override" ]; then
        preflight_exit=$preflight_exit_override
    elif "$worktree_preflight_script" --task "$task_spec"; then
        preflight_exit=0
    else
        preflight_exit=$?
    fi
fi


mkdir -p "$artifact_dir"
: > "$acceptance_log"

evidence_paths_tmp=$(mktemp)
validation_tmp=$(mktemp)
required_tmp=$(mktemp)
cleanup() {
    rm -f "$evidence_paths_tmp" "$validation_tmp" "$required_tmp"
}
trap cleanup 0 HUP INT TERM

append_evidence_path "artifacts/tasks/$task_id/$run_id/search-plan.md"
append_evidence_path "artifacts/tasks/$task_id/$run_id/verify.txt"
append_evidence_path "artifacts/tasks/$task_id/$run_id/review.txt"
append_evidence_path "artifacts/tasks/$task_id/$run_id/acceptance.txt"

verify_exit=
review_exit=

if [ -n "$verify_exit_override" ]; then
    verify_exit=$verify_exit_override
fi
if [ -n "$review_exit_override" ]; then
    review_exit=$review_exit_override
fi

if [ "$preflight_exit" -eq 0 ]; then
    if [ -z "$verify_exit_override" ]; then
        if "$verify_script" --task "$task_spec" --run-id "$run_id"; then
            verify_exit=0
        else
            verify_exit=$?
        fi
    fi

    if [ -z "$review_exit_override" ]; then
        if "$review_script" --task "$task_spec" --run-id "$run_id"; then
            review_exit=0
        else
            review_exit=$?
        fi
    fi
else
    : "${verify_exit:=99}"
    : "${review_exit:=99}"
fi

[ "$preflight_exit" -eq 0 ] || { printf '%s\n' "worktree-preflight failed with exit code $preflight_exit" >> "$acceptance_log"; status=FAIL; }
[ -d "$change_dir" ] || { printf '%s\n' "missing bound change directory: $change_dir" >> "$acceptance_log"; status=FAIL; }

if [ "$preflight_exit" -eq 0 ]; then
    [ -f "$search_plan" ] || { printf '%s\n' "missing required artifact: $search_plan" >> "$acceptance_log"; status=FAIL; }
    [ -f "$verify_log" ] || { printf '%s\n' "missing required artifact: $verify_log" >> "$acceptance_log"; status=FAIL; }
    [ -f "$review_log" ] || { printf '%s\n' "missing required artifact: $review_log" >> "$acceptance_log"; status=FAIL; }
    [ "$verify_exit" -eq 0 ] || { printf '%s\n' "verify failed with exit code $verify_exit" >> "$acceptance_log"; status=FAIL; }
    [ "$review_exit" -eq 0 ] || { printf '%s\n' "review-check failed with exit code $review_exit" >> "$acceptance_log"; status=FAIL; }

    validation_rows > "$validation_tmp"
    while IFS="$(printf '\t')" read -r requirement method evidence row_status; do
        [ -n "$requirement" ] || continue
        evidence=$(trim "$evidence")
        row_status=$(trim "$row_status")

        if [ "$row_status" = "skip" ]; then
            case "$evidence" in
                skip:*) : ;;
                *)
                    printf '%s\n' "invalid skip evidence for requirement: $requirement" >> "$acceptance_log"
                    status=FAIL
                    ;;
            esac
            continue
        fi

        case "$evidence" in
            path:*)
                rel_path=${evidence#path:}
                resolved_path=$(resolve_repo_path "$rel_path") || {
                    printf '%s\n' "validation evidence must stay within repo: $evidence" >> "$acceptance_log"
                    status=FAIL
                    continue
                }
                normalized_rel_path=$(printf '%s' "$rel_path" | sed "s#<run_id>#$run_id#g")
                if [ "$normalized_rel_path" = "artifacts/tasks/$task_id/$run_id/manifest.json" ]; then
                    append_evidence_path "$normalized_rel_path"
                    continue
                fi
                if [ ! -e "$resolved_path" ]; then
                    printf '%s\n' "missing validation evidence path: $rel_path" >> "$acceptance_log"
                    status=FAIL
                    continue
                fi
                append_evidence_path "$normalized_rel_path"
                ;;
            *)
                printf '%s\n' "invalid evidence reference for requirement: $requirement" >> "$acceptance_log"
                status=FAIL
                ;;
        esac
    done < "$validation_tmp"

    required_evidence_entries > "$required_tmp"
    while IFS= read -r entry; do
        entry=$(trim "$entry")
        [ -n "$entry" ] || continue
        case "$entry" in
            path:*)
                rel_path=${entry#path:}
                resolved_path=$(resolve_repo_path "$rel_path") || {
                    printf '%s\n' "required evidence must stay within repo: $entry" >> "$acceptance_log"
                    status=FAIL
                    continue
                }
                normalized_rel_path=$(printf '%s' "$rel_path" | sed "s#<run_id>#$run_id#g")
                if [ "$normalized_rel_path" = "artifacts/tasks/$task_id/$run_id/manifest.json" ]; then
                    append_evidence_path "$normalized_rel_path"
                    continue
                fi
                if [ ! -e "$resolved_path" ]; then
                    printf '%s\n' "missing required evidence path: $rel_path" >> "$acceptance_log"
                    status=FAIL
                    continue
                fi
                append_evidence_path "$normalized_rel_path"
                ;;
            *)
                printf '%s\n' "unresolved required evidence entry: $entry" >> "$acceptance_log"
                status=FAIL
                ;;
        esac
    done < "$required_tmp"
fi

append_evidence_path "artifacts/tasks/$task_id/$run_id/manifest.json"

python3 - "$manifest_path" "$task_id" "$change_id" "$run_id" "$current_task_spec" "$worktree_path" "$base_ref" "$risk_level" "$head_sha" "$generated_at_utc" "$preflight_exit" "$verify_exit" "$review_exit" "$status" "$evidence_paths_tmp" <<'PY'
import json
import sys

(
    manifest_path,
    task_id,
    change_id,
    run_id,
    task_spec_path,
    worktree_path,
    base_ref,
    risk_level,
    head_sha,
    generated_at_utc,
    preflight_exit,
    verify_exit,
    review_exit,
    acceptance_status,
    evidence_paths_file,
) = sys.argv[1:]

seen = set()
evidence_paths = []
with open(evidence_paths_file, 'r', encoding='utf-8') as fh:
    for line in fh:
        value = line.strip()
        if not value or value in seen:
            continue
        seen.add(value)
        evidence_paths.append(value)

payload = {
    'task_id': task_id,
    'change_id': change_id,
    'run_id': run_id,
    'task_spec_path': task_spec_path,
    'worktree_path': worktree_path,
    'base_ref': base_ref,
    'risk_level': risk_level,
    'head_sha': head_sha,
    'generated_at_utc': generated_at_utc,
    'preflight_exit': int(preflight_exit),
    'verify_exit': int(verify_exit),
    'review_exit': int(review_exit),
    'acceptance_status': acceptance_status,
    'evidence_paths': evidence_paths,
}

with open(manifest_path, 'w', encoding='utf-8') as fh:
    json.dump(payload, fh, indent=2)
    fh.write('\n')
PY

{
    printf '%s\n' "task_id=$task_id"
    printf '%s\n' "change_id=$change_id"
    printf '%s\n' "run_id=$run_id"
    printf '%s\n' "status=$status"
} >> "$acceptance_log"

[ "$status" = "PASS" ] || exit 1
exit 0
