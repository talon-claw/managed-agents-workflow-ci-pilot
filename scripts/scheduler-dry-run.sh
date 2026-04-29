#!/usr/bin/env sh
set -eu

usage() {
    printf '%s\n' "Usage: $0 --task <specs/tasks/task_id.md> [--run-id <run_id>] [--lease-owner <lease_owner>] [--controller-session-id <session_id>] [--executor-session-id <session_id>] [--update-mirror]" >&2
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

task_status() {
    value=$(sed -n 's/^- \*\*status\*\*:[[:space:]]*//p' "$task_spec" | sed -n '1p')
    trim "$value"
}

generate_run_id() {
    timestamp=$(date -u +%Y%m%dT%H%M%SZ)
    attempt=1
    candidate="${timestamp}-${task_id}-r$attempt"
    while [ -e "$task_root/$candidate" ]; do
        attempt=$((attempt + 1))
        candidate="${timestamp}-${task_id}-r$attempt"
    done
    printf '%s\n' "$candidate"
}

json_field_or_default() {
    path=$1
    key=$2
    default_value=$3
    python3 - "$path" "$key" "$default_value" <<'PY'
import json
import sys

path, key, default = sys.argv[1:]
try:
    with open(path, 'r', encoding='utf-8') as fh:
        payload = json.load(fh)
except FileNotFoundError:
    print(default)
    raise SystemExit(0)
except Exception:
    raise SystemExit(1)

value = payload.get(key, default)
if value is None:
    value = default
print(value)
PY
}

write_search_plan() {
    plan_path=$1
    {
        printf '%s\n' "# Search Plan"
        printf '\n'
        printf '%s\n' "- task_id: $task_id"
        printf '%s\n' "- change_id: $change_id"
        printf '%s\n' "- run_id: $run_id"
        printf '%s\n' "- generated_at_utc: $generated_at_utc"
        printf '%s\n' "- controller_session_id: $controller_session_id"
        printf '%s\n' "- executor_session_id: $executor_session_id"
        printf '%s\n' "- mode: repository-local dry-run"
        printf '\n'
        printf '%s\n' "## Objective"
        printf '%s\n' "$goal"
        printf '\n'
        printf '%s\n' "## Planned Checks"
        printf '%s\n' "1. Acquire the single-writer lease for this task."
        printf '%s\n' "2. Run the repository-local verify, review, and acceptance scripts."
        printf '%s\n' "3. Rewrite manifest.json to the Phase 2 canonical result contract."
        printf '%s\n' "4. Apply fail-closed task-spec writeback and optional derived mirror writeback."
    } > "$plan_path"
}

write_lease() {
    lease_state=$1
    lease_result_state=$2
    lease_released_at_utc_value=$3
    python3 - "$lease_path" "$task_id" "$run_id" "$lease_owner" "$lease_acquired_at_utc" "$lease_state" "$lease_result_state" "$lease_released_at_utc_value" "$write_scope_tmp" <<'PY'
import json
import sys

(
    lease_path,
    task_id,
    run_id,
    lease_owner,
    lease_acquired_at_utc,
    lease_state,
    lease_result_state,
    lease_released_at_utc,
    write_scope_path,
) = sys.argv[1:]

write_scope = []
with open(write_scope_path, 'r', encoding='utf-8') as fh:
    for line in fh:
        value = line.strip()
        if value:
            write_scope.append(value)

payload = {
    'task_id': task_id,
    'run_id': run_id,
    'lease_owner': lease_owner,
    'lease_acquired_at_utc': lease_acquired_at_utc,
    'write_scope': write_scope,
}
if lease_state:
    payload['lease_state'] = lease_state
if lease_result_state:
    payload['last_result_state'] = lease_result_state
if lease_released_at_utc:
    payload['lease_released_at_utc'] = lease_released_at_utc

with open(lease_path, 'w', encoding='utf-8') as fh:
    json.dump(payload, fh, indent=2)
    fh.write('\n')
PY
}

acquire_lease() {
    if [ -f "$lease_path" ]; then
        if python3 - "$lease_path" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], 'r', encoding='utf-8') as fh:
        payload = json.load(fh)
except Exception:
    raise SystemExit(2)

if payload.get('lease_state', 'active') == 'active':
    raise SystemExit(1)
PY
        then
            :
        else
            rc=$?
            case "$rc" in
                1) return 1 ;;
                *) return 2 ;;
            esac
        fi
    fi

    write_lease active "" ""
}

update_task_status() {
    expected_status=$1
    next_status=$2
    python3 - "$task_spec" "$expected_status" "$next_status" <<'PY'
import re
import sys

task_spec_path, expected_status, next_status = sys.argv[1:]
allowed = {
    ('pending', 'in-progress'),
    ('in-progress', 'completed'),
    ('in-progress', 'blocked'),
    ('blocked', 'in-progress'),
}

with open(task_spec_path, 'r', encoding='utf-8') as fh:
    content = fh.read()

pattern = re.compile(r'^- \*\*status\*\*:[ \t]*(.+)$', re.MULTILINE)
matches = pattern.findall(content)
if len(matches) != 1:
    raise SystemExit('task spec must contain exactly one status field')

current_status = matches[0].strip()
if current_status != expected_status:
    raise SystemExit(f"task status changed concurrently: expected {expected_status}, found {current_status}")
if (current_status, next_status) not in allowed:
    raise SystemExit(f"illegal automated transition: {current_status} -> {next_status}")

updated = pattern.sub(f'- **status**: {next_status}', content, count=1)
with open(task_spec_path, 'w', encoding='utf-8') as fh:
    fh.write(updated)
PY
}

update_mirror_file() {
    python3 - "$change_tasks_path" "$task_id" "$task_status_after" "$run_id" <<'PY'
import re
import sys

change_tasks_path, task_id, status, run_id = sys.argv[1:]

with open(change_tasks_path, 'r', encoding='utf-8') as fh:
    lines = fh.readlines()

matches = [index for index, line in enumerate(lines) if task_id in line and re.match(r'^- \[[ xX]\]', line)]
if len(matches) != 1:
    raise SystemExit(1)

index = matches[0]
line = lines[index].rstrip('\n')
line = re.sub(r'\s*<!-- derived: .* -->\s*$', '', line)
checkbox = 'x' if status == 'completed' else ' '
line = re.sub(r'^- \[[ xX]\]', f'- [{checkbox}]', line, count=1)
line = f"{line} <!-- derived: specs/tasks/{task_id}.md status={status} run_id={run_id} -->"
lines[index] = line + '\n'

with open(change_tasks_path, 'w', encoding='utf-8') as fh:
    fh.writelines(lines)
PY
}

populate_evidence_files() {
    : > "$evidence_paths_tmp"
    : > "$missing_paths_tmp"

    for rel_path in \
        "artifacts/tasks/$task_id/$run_id/search-plan.md" \
        "artifacts/tasks/$task_id/$run_id/verify.txt" \
        "artifacts/tasks/$task_id/$run_id/review.txt" \
        "artifacts/tasks/$task_id/$run_id/acceptance.txt" \
        "artifacts/tasks/$task_id/$run_id/manifest.json" \
        "artifacts/tasks/$task_id/active-lease.json"
    do
        printf '%s\n' "$rel_path" >> "$evidence_paths_tmp"
        if [ "$rel_path" = "artifacts/tasks/$task_id/$run_id/manifest.json" ]; then
            continue
        fi
        if [ ! -e "$repo_root/$rel_path" ]; then
            printf '%s\n' "$rel_path" >> "$missing_paths_tmp"
        fi
    done
}

append_review_summary() {
    [ -f "$review_log" ] || return 0
    {
        printf '\n'
        printf '%s\n' "task_status_before=$task_status_before"
        printf '%s\n' "task_status_after=$task_status_after"
        printf '%s\n' "task_writeback=$task_writeback"
        printf '%s\n' "mirror_writeback=$mirror_writeback_status"
        printf '%s\n' "result_state=$result_state"
    } >> "$review_log"
}

append_acceptance_summary() {
    [ -f "$acceptance_log" ] || return 0
    {
        printf '%s\n' "result_state=$result_state"
        printf '%s\n' "task_status_before=$task_status_before"
        printf '%s\n' "task_status_after=$task_status_after"
        printf '%s\n' "task_writeback=$task_writeback"
        printf '%s\n' "mirror_writeback=$mirror_writeback_status"
        printf '%s\n' "scope_guard_status=$scope_guard_status"
    } >> "$acceptance_log"
}

write_manifest() {
    python3 - "$manifest_path" "$task_id" "$change_id" "$run_id" "$task_spec" "$repo_root" "$base_ref" "$risk_level" "$head_sha" "$generated_at_utc" "$controller_session_id" "$executor_session_id" "$lease_owner" "$lease_acquired_at_utc" "$lease_released_at_utc" "$result_state" "$preflight_exit" "$verify_exit" "$review_exit" "$acceptance_exit" "$acceptance_status" "$task_status_before" "$task_status_after" "$task_writeback" "$mirror_writeback_status" "$scheduler_message" "$scope_guard_status" "$evidence_paths_tmp" "$missing_paths_tmp" <<'PY'
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
    controller_session_id,
    executor_session_id,
    lease_owner,
    lease_acquired_at_utc,
    lease_released_at_utc,
    result_state,
    preflight_exit,
    verify_exit,
    review_exit,
    acceptance_exit,
    acceptance_status,
    task_status_before,
    task_status_after,
    task_writeback,
    mirror_writeback,
    scheduler_message,
    scope_guard_status,
    evidence_paths_file,
    missing_paths_file,
) = sys.argv[1:]

def read_unique_lines(path):
    values = []
    seen = set()
    with open(path, 'r', encoding='utf-8') as fh:
        for line in fh:
            value = line.strip()
            if not value or value in seen:
                continue
            seen.add(value)
            values.append(value)
    return values

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
    'controller_session_id': controller_session_id,
    'executor_session_id': executor_session_id,
    'lease_owner': lease_owner,
    'result_state': result_state,
    'preflight_exit': int(preflight_exit),
    'verify_exit': int(verify_exit),
    'review_exit': int(review_exit),
    'verify_exit_code': int(verify_exit),
    'review_exit_code': int(review_exit),
    'acceptance_exit_code': int(acceptance_exit),
    'acceptance_status': acceptance_status,
    'task_status_before': task_status_before,
    'task_status_after': task_status_after,
    'task_writeback': task_writeback,
    'mirror_writeback': mirror_writeback,
    'scheduler_message': scheduler_message,
    'scope_guard_status': scope_guard_status,
    'evidence_paths': read_unique_lines(evidence_paths_file),
    'missing_evidence_paths': read_unique_lines(missing_paths_file),
}
if lease_acquired_at_utc:
    payload['lease_acquired_at_utc'] = lease_acquired_at_utc
if lease_released_at_utc:
    payload['lease_released_at_utc'] = lease_released_at_utc

with open(manifest_path, 'w', encoding='utf-8') as fh:
    json.dump(payload, fh, indent=2)
    fh.write('\n')
PY
}

task_spec=
run_id=
lease_owner=claude-controller
controller_session_id=local-controller-session
executor_session_id=local-executor-session
update_mirror=0

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
        --lease-owner)
            [ "$#" -ge 2 ] || usage
            lease_owner=$2
            shift 2
            ;;
        --controller-session-id)
            [ "$#" -ge 2 ] || usage
            controller_session_id=$2
            shift 2
            ;;
        --executor-session-id)
            [ "$#" -ge 2 ] || usage
            executor_session_id=$2
            shift 2
            ;;
        --update-mirror)
            update_mirror=1
            shift
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$task_spec" ] || usage
[ -f "$task_spec" ] || die "task spec not found: $task_spec"
task_spec=$(abs_path "$task_spec")

if repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    repo_root=$(abs_path "$repo_root")
else
    die "not inside a git worktree"
fi

task_id=$(field_value task_id)
change_id=$(field_value change_id)
risk_level=$(field_value risk_level)
base_ref=$(field_value base_ref)
goal=$(field_value goal)
[ -n "$task_id" ] || die "task spec missing task_id"
[ -n "$change_id" ] || die "task spec missing change_id"
[ -n "$base_ref" ] || base_ref=main
resolved_base_ref=$(resolve_base_ref "$base_ref")
validate_segment "$task_id" "task_id"
validate_segment "$change_id" "change_id"
expected_task_spec="$repo_root/specs/tasks/$task_id.md"
[ "$task_spec" = "$expected_task_spec" ] || die "task spec path must be specs/tasks/$task_id.md"

task_status_before=$(task_status)
[ -n "$task_status_before" ] || die "task spec missing status"

task_root="$repo_root/artifacts/tasks/$task_id"
mkdir -p "$task_root"

if [ -z "$run_id" ]; then
    run_id=$(generate_run_id)
fi
validate_segment "$run_id" "run_id"

artifact_dir="$task_root/$run_id"
mkdir -p "$artifact_dir"

search_plan="$artifact_dir/search-plan.md"
verify_log="$artifact_dir/verify.txt"
review_log="$artifact_dir/review.txt"
acceptance_log="$artifact_dir/acceptance.txt"
manifest_path="$artifact_dir/manifest.json"
lease_path="$task_root/active-lease.json"
change_tasks_path="$repo_root/openspec/changes/$change_id/tasks.md"

write_scope_tmp=$(mktemp)
evidence_paths_tmp=$(mktemp)
missing_paths_tmp=$(mktemp)
cleanup() {
    rm -f "$write_scope_tmp" "$evidence_paths_tmp" "$missing_paths_tmp"
}
trap cleanup 0 HUP INT TERM

printf '%s\n' "specs/tasks/$task_id.md" > "$write_scope_tmp"
printf '%s\n' "artifacts/tasks/$task_id/$run_id/" >> "$write_scope_tmp"
if [ "$update_mirror" -eq 1 ]; then
    printf '%s\n' "openspec/changes/$change_id/tasks.md" >> "$write_scope_tmp"
fi

generated_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
if head_sha=$(git rev-parse HEAD 2>/dev/null); then
    :
else
    head_sha=
fi

scope_guard_status=unknown
scope_guard_committed=
scope_guard_local=
if scope_guard_committed=$(git diff --name-only "$resolved_base_ref"...HEAD -- .github/workflows scripts/guard-command.sh 2>/dev/null); then
    :
fi
if scope_guard_local=$(git status --porcelain -- .github/workflows scripts/guard-command.sh 2>/dev/null); then
    :
fi
if [ -n "$scope_guard_committed" ] || [ -n "$scope_guard_local" ]; then
    scope_guard_status=changed
else
    scope_guard_status=clean
fi

lease_acquired=0
lease_acquired_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
lease_released_at_utc=
preflight_exit=99
verify_exit=99
review_exit=99
acceptance_exit=99
acceptance_status=FAIL
result_state=transient
scheduler_message=
task_status_after=$task_status_before
task_writeback=none
mirror_writeback_status=not-requested

if acquire_lease; then
    lease_acquired=1
else
    rc=$?
    case "$rc" in
        1) result_state=requires-human ; scheduler_message="active lease already exists for task $task_id" ;;
        *) result_state=requires-human ; scheduler_message="active lease file is malformed: $lease_path" ;;
    esac
fi

manifest_seed_valid=0
if [ "$lease_acquired" -eq 1 ] && [ -z "$scheduler_message" ]; then
    write_search_plan "$search_plan"
    [ -f "$search_plan" ] || {
        result_state=requires-human
        scheduler_message="search-plan.md was not created"
    }
fi

if [ "$lease_acquired" -eq 1 ] && [ -z "$scheduler_message" ]; then
    if SCHEDULER_DRY_RUN=1 "$repo_root/scripts/acceptance.sh" --task "$task_spec" --run-id "$run_id"; then
        acceptance_exit=0
    else
        acceptance_exit=$?
    fi

    if [ -f "$manifest_path" ]; then
        if preflight_exit=$(json_field_or_default "$manifest_path" preflight_exit 99) \
            && verify_exit=$(json_field_or_default "$manifest_path" verify_exit 99) \
            && review_exit=$(json_field_or_default "$manifest_path" review_exit 99) \
            && acceptance_status=$(json_field_or_default "$manifest_path" acceptance_status FAIL); then
            manifest_seed_valid=1
        fi
    fi

    if [ "$manifest_seed_valid" -ne 1 ]; then
        result_state=requires-human
        scheduler_message="acceptance did not produce a readable manifest"
    elif [ "$preflight_exit" -ne 0 ]; then
        result_state=requires-human
        scheduler_message="worktree-preflight failed"
    elif [ "$review_exit" -ne 0 ]; then
        result_state=policy-blocked
        scheduler_message="review-check blocked the run"
    elif [ "$verify_exit" -ne 0 ] || [ "$acceptance_exit" -ne 0 ]; then
        result_state=failed-validation
        scheduler_message="repository-local validation failed"
    else
        result_state=verified
        scheduler_message="repository-local dry-run verified"
    fi
fi

populate_evidence_files
if [ -s "$missing_paths_tmp" ] && [ "$result_state" = "verified" ]; then
    result_state=requires-human
    scheduler_message="required dry-run evidence is missing"
fi

case "$result_state" in
    verified)
        case "$task_status_before" in
            pending|blocked)
                desired_status=in-progress
                ;;
            in-progress)
                desired_status=completed
                ;;
            *)
                desired_status=
                ;;
        esac

        if [ -n "$desired_status" ]; then
            if update_task_status "$task_status_before" "$desired_status"; then
                task_status_after=$desired_status
                task_writeback="$task_status_before->$desired_status"
            else
                if task_status_after=$(task_status 2>/dev/null); then
                    :
                else
                    task_status_after=$task_status_before
                fi
                task_writeback="failed-closed:$task_status_before->$desired_status"
                result_state=requires-human
                scheduler_message="task-spec writeback failed closed"
            fi
        else
            task_writeback="failed-closed:no-verified-transition-from-$task_status_before"
            result_state=requires-human
            scheduler_message="verified run cannot advance task-spec status from $task_status_before"
        fi
        ;;
    policy-blocked|requires-human)
        if [ "$task_status_before" = "in-progress" ]; then
            if update_task_status in-progress blocked; then
                task_status_after=blocked
                task_writeback="in-progress->blocked"
            else
                if task_status_after=$(task_status 2>/dev/null); then
                    :
                else
                    task_status_after=$task_status_before
                fi
                task_writeback="failed-closed:in-progress->blocked"
                result_state=requires-human
                scheduler_message="task-spec writeback failed closed"
            fi
        else
            task_writeback="no-op:$task_status_before"
        fi
        ;;
    *)
        task_writeback="no-op:$task_status_before"
        ;;
esac

if [ "$update_mirror" -eq 1 ]; then
    if [ "${task_writeback#failed-closed:}" != "$task_writeback" ]; then
        mirror_writeback_status="skipped-task-writeback-failed"
    elif [ ! -f "$change_tasks_path" ]; then
        mirror_writeback_status="skipped-missing-mirror"
    elif update_mirror_file; then
        mirror_writeback_status="updated"
    else
        mirror_writeback_status="skipped-ambiguous"
    fi
fi

append_review_summary
append_acceptance_summary

if [ "$lease_acquired" -eq 1 ]; then
    lease_released_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    write_lease released "$result_state" "$lease_released_at_utc"
fi

write_manifest

[ "$result_state" = "verified" ] || exit 1
exit 0
