#!/usr/bin/env sh
set -eu

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

require_env() {
    name=$1
    eval "value=\${$name:-}"
    [ -n "$value" ] || die "$name is required"
    printf '%s\n' "$value"
}

task_id=$(require_env TASK_ID)
change_id=$(require_env CHANGE_ID)
run_id=$(require_env RUN_ID)
repo_root=$(require_env REPO_ROOT)
evidence_path=$(require_env EVIDENCE_PATH)

artifact_dir="$repo_root/artifacts/tasks/$task_id/$run_id"
search_plan="$artifact_dir/search-plan.md"
lease_path="$repo_root/artifacts/tasks/$task_id/active-lease.json"
review_log="$artifact_dir/review.txt"
manifest_path="$artifact_dir/manifest.json"

assert_common_scheduler_state() {
    [ -f "$search_plan" ] || die "missing scheduler search plan: $search_plan"
    [ -f "$lease_path" ] || die "missing active lease: $lease_path"
    [ -d "$repo_root/openspec/changes/$change_id" ] || die "missing bound change directory: $change_id"
    grep -Fq "$run_id" "$search_plan" || die "search plan does not record run_id: $run_id"

    python3 - "$lease_path" "$task_id" "$run_id" <<'PY'
import json
import sys

lease_path, task_id, run_id = sys.argv[1:]
with open(lease_path, 'r', encoding='utf-8') as fh:
    lease = json.load(fh)

required_lease = ['task_id', 'run_id', 'lease_owner', 'lease_acquired_at_utc', 'write_scope']
missing_lease = [key for key in required_lease if key not in lease]
if missing_lease:
    raise SystemExit(f"lease file is missing required fields: {', '.join(missing_lease)}")
if lease['task_id'] != task_id:
    raise SystemExit(f"lease task_id mismatch: {lease['task_id']}")
if lease['run_id'] != run_id:
    raise SystemExit(f"lease run_id mismatch: {lease['run_id']}")
if not isinstance(lease['write_scope'], list) or not lease['write_scope']:
    raise SystemExit('lease write_scope must be a non-empty list')
PY
}

assert_manifest_state() {
    [ -f "$manifest_path" ] || die "missing manifest: $manifest_path"

    python3 - "$manifest_path" "$task_id" "$change_id" "$run_id" <<'PY'
import json
import sys

manifest_path, task_id, change_id, run_id = sys.argv[1:]
with open(manifest_path, 'r', encoding='utf-8') as fh:
    manifest = json.load(fh)

required_manifest = [
    'task_id', 'change_id', 'run_id', 'task_spec_path', 'base_ref', 'generated_at_utc',
    'controller_session_id', 'executor_session_id', 'lease_owner', 'result_state',
    'verify_exit_code', 'review_exit_code', 'acceptance_exit_code', 'evidence_paths'
]
missing_manifest = [key for key in required_manifest if key not in manifest]
if missing_manifest:
    raise SystemExit(f"manifest is missing required fields: {', '.join(missing_manifest)}")
if manifest['task_id'] != task_id:
    raise SystemExit(f"manifest task_id mismatch: {manifest['task_id']}")
if manifest['change_id'] != change_id:
    raise SystemExit(f"manifest change_id mismatch: {manifest['change_id']}")
if manifest['run_id'] != run_id:
    raise SystemExit(f"manifest run_id mismatch: {manifest['run_id']}")
if manifest['result_state'] not in {
    'verified', 'failed-validation', 'awaiting-review', 'policy-blocked',
    'spec-mismatch', 'transient', 'requires-human'
}:
    raise SystemExit(f"invalid manifest result_state: {manifest['result_state']}")
if not isinstance(manifest['evidence_paths'], list) or not manifest['evidence_paths']:
    raise SystemExit('manifest evidence_paths must be a non-empty list')
PY
}

assert_review_summary() {
    [ -f "$review_log" ] || die "missing review log: $review_log"
    grep -Fq 'task_status_before=' "$review_log" || die "review log missing task_status_before"
    grep -Fq 'task_status_after=' "$review_log" || die "review log missing task_status_after"
    grep -Fq 'task_writeback=' "$review_log" || die "review log missing task_writeback"
}

case "$task_id" in
    phase2-scheduler-artifact-dry-run-pilot)
        assert_common_scheduler_state
        case "$evidence_path" in
            artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/*/manifest.json)
                assert_manifest_state
                printf '%s\n' "dry-run scheduler generated lease state and run envelope inputs"
                ;;
            artifacts/tasks/phase2-scheduler-artifact-dry-run-pilot/*/review.txt)
                assert_manifest_state
                assert_review_summary
                printf '%s\n' "dry-run scheduler preserves review-stage status assertions for later artifact checks"
                ;;
            *)
                die "unsupported evidence path for $task_id: $evidence_path"
                ;;
        esac
        ;;
    phase2-ci-unified-gate-pilot-task)
        [ -d "$repo_root/openspec/changes/$change_id" ] || die "missing bound change directory: $change_id"
        if [ ! -f "$manifest_path" ]; then
            case "$evidence_path" in
                artifacts/tasks/phase2-ci-unified-gate-pilot-task/*/manifest.json|\
                artifacts/tasks/phase2-ci-unified-gate-pilot-task/*/review.txt|\
                artifacts/tasks/phase2-ci-unified-gate-pilot-task/*/acceptance.txt)
                    printf '%s\n' "ci unified gate pilot defers manifest assertions until acceptance writes canonical artifacts"
                    exit 0
                    ;;
                *)
                    die "missing manifest: $manifest_path"
                    ;;
            esac
        fi
        assert_manifest_state
        python3 - "$manifest_path" "$task_id" <<'PY'
import json
import os
import sys

manifest_path, task_id = sys.argv[1:]
with open(manifest_path, 'r', encoding='utf-8') as fh:
    manifest = json.load(fh)

if manifest.get('task_status_before') != 'pending':
    raise SystemExit(f"unexpected task_status_before: {manifest.get('task_status_before')}")
if manifest.get('task_status_after') != 'pending':
    raise SystemExit(f"unexpected task_status_after: {manifest.get('task_status_after')}")
if manifest.get('task_writeback') != 'not-attempted':
    raise SystemExit(f"unexpected task_writeback: {manifest.get('task_writeback')}")
if manifest.get('mirror_writeback') != 'not-attempted':
    raise SystemExit(f"unexpected mirror_writeback: {manifest.get('mirror_writeback')}")
if manifest.get('lease_owner') != 'ci-read-only':
    raise SystemExit(f"unexpected lease_owner: {manifest.get('lease_owner')}")
if manifest.get('controller_session_id') != 'github-actions':
    raise SystemExit(f"unexpected controller_session_id: {manifest.get('controller_session_id')}")
if manifest.get('executor_session_id') != 'github-actions':
    raise SystemExit(f"unexpected executor_session_id: {manifest.get('executor_session_id')}")
worktree_path = manifest.get('worktree_path', '')
if os.path.basename(worktree_path) != task_id:
    raise SystemExit(f"worktree_path basename mismatch: {worktree_path}")
if 'missing_evidence_paths' not in manifest or not isinstance(manifest['missing_evidence_paths'], list):
    raise SystemExit('manifest missing missing_evidence_paths list')
if manifest['result_state'] == 'verified' and manifest['missing_evidence_paths']:
    raise SystemExit('verified manifest must not report missing evidence paths')
PY
        case "$evidence_path" in
            artifacts/tasks/phase2-ci-unified-gate-pilot-task/*/manifest.json)
                printf '%s\n' "ci unified gate pilot manifest preserves read-only canonical task state"
                ;;
            artifacts/tasks/phase2-ci-unified-gate-pilot-task/*/review.txt)
                [ -f "$review_log" ] || die "missing review log: $review_log"
                printf '%s\n' "ci unified gate pilot retains review evidence alongside canonical manifest"
                ;;
            artifacts/tasks/phase2-ci-unified-gate-pilot-task/*/acceptance.txt)
                [ -f "$artifact_dir/acceptance.txt" ] || die "missing acceptance log"
                printf '%s\n' "ci unified gate pilot retains acceptance evidence for read-only checks"
                ;;
            *)
                die "unsupported evidence path for $task_id: $evidence_path"
                ;;
        esac
        ;;
    *)
        printf '%s\n' "Phase 2 dry-run integration assertions are only implemented for $task_id." >&2
        exit 1
        ;;
esac
