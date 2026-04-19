#!/usr/bin/env sh
set -eu

usage() {
    printf '%s\n' "Usage: $0 --task <specs/tasks/task_id.md> [--expected-change <change_id>] [--base-ref <ref>] [--run-id <run_id>]" >&2
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
    value=$(sed -n "s/^- \*\*$label\*\*:[[:space:]]*//p" "$task_spec_abs" | sed -n '1p')
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

sha_or_empty() {
    path=$1
    if [ -f "$path" ]; then
        sha256sum "$path" | awk '{print $1}'
    else
        printf '%s\n' ""
    fi
}

json_int_or_default() {
    json_path=$1
    key=$2
    default_value=$3
    python3 - "$json_path" "$key" "$default_value" <<'PY'
import json
import sys

json_path, key, default_value = sys.argv[1:]
try:
    with open(json_path, 'r', encoding='utf-8') as fh:
        payload = json.load(fh)
except Exception:
    print(default_value)
    raise SystemExit(0)

value = payload.get(key, default_value)
try:
    print(int(value))
except Exception:
    print(default_value)
PY
}

json_str_or_default() {
    json_path=$1
    key=$2
    default_value=$3
    python3 - "$json_path" "$key" "$default_value" <<'PY'
import json
import sys

json_path, key, default_value = sys.argv[1:]
try:
    with open(json_path, 'r', encoding='utf-8') as fh:
        payload = json.load(fh)
except Exception:
    print(default_value)
    raise SystemExit(0)

value = payload.get(key, default_value)
if value is None:
    value = default_value
print(str(value))
PY
}

task_spec=
expected_change=phase2-ci-unified-gate-pilot
base_ref_override=
run_id_override=

while [ "$#" -gt 0 ]; do
    case "$1" in
        --task)
            [ "$#" -ge 2 ] || usage
            task_spec=$2
            shift 2
            ;;
        --expected-change)
            [ "$#" -ge 2 ] || usage
            expected_change=$2
            shift 2
            ;;
        --base-ref)
            [ "$#" -ge 2 ] || usage
            base_ref_override=$2
            shift 2
            ;;
        --run-id)
            [ "$#" -ge 2 ] || usage
            run_id_override=$2
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

[ -n "$task_spec" ] || usage
[ -f "$task_spec" ] || die "task spec not found: $task_spec"

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a git worktree"
repo_root=$(abs_path "$repo_root")

if git rev-parse --verify HEAD >/dev/null 2>&1; then
    head_sha=$(git rev-parse HEAD)
else
    head_sha=
fi

task_spec_abs=$(abs_path "$task_spec")
task_id=$(field_value task_id)
change_id=$(field_value change_id)
risk_level=$(field_value risk_level)
task_status_before=$(field_value status)

[ -n "$task_id" ] || die "task spec missing task_id"
[ -n "$change_id" ] || die "task spec missing change_id"
[ -n "$task_status_before" ] || die "task spec missing status"
validate_segment "$task_id" "task_id"
validate_segment "$change_id" "change_id"

expected_task_spec="$repo_root/specs/tasks/$task_id.md"
[ "$task_spec_abs" = "$expected_task_spec" ] || die "task spec path must be specs/tasks/$task_id.md"
[ "$risk_level" = "low" ] || die "ci pilot only accepts low risk tasks"
[ "$change_id" = "$expected_change" ] || die "task change_id must match expected change: $expected_change"

change_tasks="$repo_root/openspec/changes/$change_id/tasks.md"
[ -f "$change_tasks" ] || die "change tasks file missing: $change_tasks"
grep -Fq "$task_id" "$change_tasks" || die "change tasks.md must reference task_id"

if [ -n "$base_ref_override" ]; then
    base_ref=$base_ref_override
else
    base_ref=$(field_value base_ref)
    [ -n "$base_ref" ] || base_ref=main
fi

git rev-parse --verify "$base_ref^{commit}" >/dev/null 2>&1 || die "base_ref is not a valid commit or branch: $base_ref"
git merge-base --is-ancestor "$base_ref" HEAD >/dev/null 2>&1 || die "HEAD must descend from base_ref"

if [ -n "$run_id_override" ]; then
    run_id=$run_id_override
else
    run_id="$(date -u +%Y%m%dT%H%M%SZ)-$task_id-r${GITHUB_RUN_ATTEMPT:-1}"
fi
validate_segment "$run_id" "run_id"

artifact_dir="$repo_root/artifacts/tasks/$task_id/$run_id"
mkdir -p "$artifact_dir"
search_plan="$artifact_dir/search-plan.md"
verify_log="$artifact_dir/verify.txt"
review_log="$artifact_dir/review.txt"
acceptance_log="$artifact_dir/acceptance.txt"
manifest_path="$artifact_dir/manifest.json"

{
    printf '%s\n' "# Search Plan"
    printf '\n'
    printf '%s\n' "- task_id: $task_id"
    printf '%s\n' "- change_id: $change_id"
    printf '%s\n' "- run_id: $run_id"
    printf '%s\n' "- source: github-actions"
    printf '%s\n' "- goal: CI unified gate pilot with fixed-order repository scripts"
} > "$search_plan"

worktree_root="$repo_root/.claude/worktrees"
ci_worktree="$worktree_root/$task_id"
ci_task_spec_rel="specs/tasks/$task_id.md"
ci_task_spec="$ci_worktree/$ci_task_spec_rel"
ci_change_tasks_rel="openspec/changes/$change_id/tasks.md"
ci_change_tasks="$ci_worktree/$ci_change_tasks_rel"
ci_lease_path="$ci_worktree/artifacts/tasks/$task_id/active-lease.json"
ci_run_artifact_dir="$ci_worktree/artifacts/tasks/$task_id/$run_id"
ci_manifest_path="$ci_run_artifact_dir/manifest.json"

mkdir -p "$worktree_root"

missing_paths_tmp=$(mktemp)
evidence_paths_tmp=$(mktemp)

cleanup() {
    rm -f "$missing_paths_tmp" "$evidence_paths_tmp"
    if [ "${created_ci_worktree:-0}" -eq 1 ] && git worktree list --porcelain | sed -n 's/^worktree //p' | grep -Fqx "$ci_worktree"; then
        git worktree remove --force "$ci_worktree" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT HUP INT TERM

created_ci_worktree=0
auto_recycle_worktree=0
if [ "${CI:-}" = "1" ] || [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    auto_recycle_worktree=1
fi

if [ -e "$ci_worktree" ] && ! git worktree list --porcelain | sed -n 's/^worktree //p' | grep -Fqx "$ci_worktree"; then
    die "ci worktree path already exists and is not a registered git worktree: $ci_worktree"
fi

if git worktree list --porcelain | sed -n 's/^worktree //p' | grep -Fqx "$ci_worktree"; then
    if [ "$auto_recycle_worktree" -eq 1 ]; then
        git worktree remove --force "$ci_worktree" >/dev/null 2>&1 || true
    else
        die "ci worktree already exists; remove it manually or rerun in CI"
    fi
fi

git worktree add --detach "$ci_worktree" HEAD >/dev/null
created_ci_worktree=1
[ "$(basename "$ci_worktree")" = "$task_id" ] || die "synthetic worktree basename must equal task_id"

mkdir -p "$ci_worktree/scripts" "$ci_worktree/specs/tasks" "$ci_worktree/openspec/changes/$change_id"
cp "$repo_root/scripts/worktree-preflight.sh" "$ci_worktree/scripts/worktree-preflight.sh"
cp "$repo_root/scripts/verify.sh" "$ci_worktree/scripts/verify.sh"
cp "$repo_root/scripts/review-check.sh" "$ci_worktree/scripts/review-check.sh"
cp "$repo_root/scripts/acceptance.sh" "$ci_worktree/scripts/acceptance.sh"
cp "$repo_root/scripts/lint.sh" "$ci_worktree/scripts/lint.sh"
cp "$repo_root/scripts/typecheck.sh" "$ci_worktree/scripts/typecheck.sh"
cp "$repo_root/scripts/test-unit.sh" "$ci_worktree/scripts/test-unit.sh"
cp "$repo_root/scripts/test-integration.sh" "$ci_worktree/scripts/test-integration.sh"
cp "$repo_root/scripts/test-e2e.sh" "$ci_worktree/scripts/test-e2e.sh"
cp "$task_spec_abs" "$ci_task_spec"
cp "$change_tasks" "$ci_change_tasks"
chmod +x \
    "$ci_worktree/scripts/worktree-preflight.sh" \
    "$ci_worktree/scripts/verify.sh" \
    "$ci_worktree/scripts/review-check.sh" \
    "$ci_worktree/scripts/acceptance.sh" \
    "$ci_worktree/scripts/lint.sh" \
    "$ci_worktree/scripts/typecheck.sh" \
    "$ci_worktree/scripts/test-unit.sh" \
    "$ci_worktree/scripts/test-integration.sh" \
    "$ci_worktree/scripts/test-e2e.sh"

before_repo_task_sha=$(sha_or_empty "$task_spec_abs")
before_repo_change_sha=$(sha_or_empty "$change_tasks")
repo_lease_path="$repo_root/artifacts/tasks/$task_id/active-lease.json"
repo_lease_existed_before=0
before_repo_lease_sha=
if [ -e "$repo_lease_path" ]; then
    repo_lease_existed_before=1
    before_repo_lease_sha=$(sha_or_empty "$repo_lease_path")
fi

preflight_exit=99
verify_exit=99
review_exit=99
acceptance_exit=99

resolve_gate_script() {
    script_name=$1
    candidate="$ci_worktree/scripts/$script_name"
    if [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    die "required gate script not found in synthetic worktree: $script_name"
}

worktree_preflight_script=$(resolve_gate_script worktree-preflight.sh)
verify_script=$(resolve_gate_script verify.sh)
review_script=$(resolve_gate_script review-check.sh)
acceptance_script=$(resolve_gate_script acceptance.sh)

mkdir -p "$ci_run_artifact_dir"
cp "$search_plan" "$ci_run_artifact_dir/search-plan.md"

set +e
(
    cd "$ci_worktree" && SCHEDULER_DRY_RUN=1 "$worktree_preflight_script" --task "$ci_task_spec"
) > "$verify_log" 2>&1
preflight_exit=$?
set -e

if [ "$preflight_exit" -eq 0 ]; then
    set +e
    (
        cd "$ci_worktree" && "$verify_script" --task "$ci_task_spec" --run-id "$run_id"
    ) >> "$verify_log" 2>&1
    verify_exit=$?
    set -e

    set +e
    (
        cd "$ci_worktree" && "$review_script" --task "$ci_task_spec" --run-id "$run_id"
    ) > "$review_log" 2>&1
    review_exit=$?
    set -e
fi

set +e
(
    cd "$ci_worktree" && \
    PREFLIGHT_EXIT_OVERRIDE=$preflight_exit \
    VERIFY_EXIT_OVERRIDE=$verify_exit \
    REVIEW_EXIT_OVERRIDE=$review_exit \
    "$acceptance_script" --task "$ci_task_spec" --run-id "$run_id"
) > "$acceptance_log" 2>&1
acceptance_exit=$?
set -e


if [ -f "$ci_run_artifact_dir/verify.txt" ]; then
    cp "$ci_run_artifact_dir/verify.txt" "$verify_log"
fi
if [ -f "$ci_run_artifact_dir/review.txt" ]; then
    cp "$ci_run_artifact_dir/review.txt" "$review_log"
fi
if [ -f "$ci_run_artifact_dir/acceptance.txt" ]; then
    cp "$ci_run_artifact_dir/acceptance.txt" "$acceptance_log"
fi
if [ -f "$ci_manifest_path" ]; then
    cp "$ci_manifest_path" "$manifest_path"
fi

mkdir -p "$ci_run_artifact_dir"
cp "$search_plan" "$ci_run_artifact_dir/search-plan.md"

seed_manifest_ok=0
seed_preflight=99
seed_verify=99
seed_review=99
seed_acceptance_status=FAIL
seed_result_state=

if [ -f "$manifest_path" ]; then
    seed_preflight=$(json_int_or_default "$manifest_path" preflight_exit 99)
    seed_verify=$(json_int_or_default "$manifest_path" verify_exit 99)
    seed_review=$(json_int_or_default "$manifest_path" review_exit 99)
    seed_acceptance_status=$(json_str_or_default "$manifest_path" acceptance_status FAIL)
    seed_result_state=$(json_str_or_default "$manifest_path" result_state "")
    seed_manifest_ok=1
fi

after_repo_task_sha=$(sha_or_empty "$task_spec_abs")
after_repo_change_sha=$(sha_or_empty "$change_tasks")

task_status_after=$task_status_before
if [ -f "$ci_task_spec" ]; then
    task_status_after=$(sed -n 's/^- \*\*status\*\*:[[:space:]]*//p' "$ci_task_spec" | sed -n '1p' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$task_status_after" ] || task_status_after=$task_status_before
fi

read_only_violation=0
[ "$after_repo_task_sha" = "$before_repo_task_sha" ] || read_only_violation=1
[ "$after_repo_change_sha" = "$before_repo_change_sha" ] || read_only_violation=1
if [ "$repo_lease_existed_before" -eq 1 ]; then
    [ "$(sha_or_empty "$repo_lease_path")" = "$before_repo_lease_sha" ] || read_only_violation=1
else
    [ ! -e "$repo_lease_path" ] || read_only_violation=1
fi

required_paths="
artifacts/tasks/$task_id/$run_id/search-plan.md
artifacts/tasks/$task_id/$run_id/verify.txt
artifacts/tasks/$task_id/$run_id/review.txt
artifacts/tasks/$task_id/$run_id/acceptance.txt
artifacts/tasks/$task_id/$run_id/manifest.json
"

: > "$missing_paths_tmp"
: > "$evidence_paths_tmp"
printf '%s' "$required_paths" | while IFS= read -r rel; do
    rel=$(trim "$rel")
    [ -n "$rel" ] || continue
    printf '%s\n' "$rel" >> "$evidence_paths_tmp"
    if [ ! -e "$repo_root/$rel" ]; then
        printf '%s\n' "$rel" >> "$missing_paths_tmp"
    fi
done

result_state=requires-human
scheduler_message=

if [ "$seed_manifest_ok" -ne 1 ]; then
    result_state=requires-human
    scheduler_message="acceptance did not produce a readable manifest"
elif [ "$seed_preflight" -ne "$preflight_exit" ] || [ "$seed_verify" -ne "$verify_exit" ] || [ "$seed_review" -ne "$review_exit" ]; then
    result_state=requires-human
    scheduler_message="manifest and gate logs disagree"
elif [ "$read_only_violation" -eq 1 ]; then
    result_state=requires-human
    scheduler_message="ci pilot violated read-only canonical state"
else
    case "$seed_result_state" in
        awaiting-review|spec-mismatch|transient)
            result_state=$seed_result_state
            scheduler_message="preserved canonical result_state from manifest"
            ;;
        *)
            if [ "$seed_preflight" -ne 0 ]; then
                result_state=requires-human
                scheduler_message="worktree-preflight failed"
            elif [ "$seed_review" -ne 0 ]; then
                result_state=policy-blocked
                scheduler_message="review-check blocked the run"
            elif [ "$seed_verify" -ne 0 ] || [ "$acceptance_exit" -ne 0 ]; then
                result_state=failed-validation
                scheduler_message="repository-owned validation failed"
            elif [ -s "$missing_paths_tmp" ]; then
                result_state=requires-human
                scheduler_message="required evidence paths are missing"
            else
                result_state=verified
                scheduler_message="ci unified gate pilot verified"
            fi
            ;;
    esac
fi

scope_guard_status=clean
if [ "$read_only_violation" -eq 1 ]; then
    scope_guard_status=blocked
fi

python3 - "$manifest_path" "$task_id" "$change_id" "$run_id" "$base_ref" "$head_sha" "$preflight_exit" "$verify_exit" "$review_exit" "$acceptance_exit" "$seed_acceptance_status" "$task_status_before" "$task_status_after" "$result_state" "$scheduler_message" "$scope_guard_status" "$evidence_paths_tmp" "$missing_paths_tmp" <<'PY'
import json
import sys
from datetime import datetime, timezone

(
    manifest_path,
    task_id,
    change_id,
    run_id,
    base_ref,
    head_sha,
    preflight_exit,
    verify_exit,
    review_exit,
    acceptance_exit,
    acceptance_status,
    task_status_before,
    task_status_after,
    result_state,
    scheduler_message,
    scope_guard_status,
    evidence_paths_file,
    missing_paths_file,
) = sys.argv[1:]

def read_unique(path):
    seen = set()
    out = []
    with open(path, 'r', encoding='utf-8') as fh:
        for line in fh:
            value = line.strip()
            if not value or value in seen:
                continue
            seen.add(value)
            out.append(value)
    return out

payload = {
    'task_id': task_id,
    'change_id': change_id,
    'run_id': run_id,
    'task_spec_path': f'specs/tasks/{task_id}.md',
    'worktree_path': f'.claude/worktrees/{task_id}',
    'base_ref': base_ref,
    'risk_level': 'low',
    'head_sha': head_sha,
    'generated_at_utc': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'controller_session_id': 'github-actions',
    'executor_session_id': 'github-actions',
    'lease_owner': 'ci-read-only',
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
    'task_writeback': 'not-attempted',
    'mirror_writeback': 'not-attempted',
    'scheduler_message': scheduler_message,
    'scope_guard_status': scope_guard_status,
    'evidence_paths': read_unique(evidence_paths_file),
    'missing_evidence_paths': read_unique(missing_paths_file),
}

with open(manifest_path, 'w', encoding='utf-8') as fh:
    json.dump(payload, fh, indent=2)
    fh.write('\n')
PY

if [ "$result_state" = "verified" ]; then
    exit 0
fi
exit 1
