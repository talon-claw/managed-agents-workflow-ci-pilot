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

resolve_base_ref() {
    repo_root=$1
    candidate=$2

    if git -C "$repo_root" rev-parse --verify "$candidate^{commit}" >/dev/null 2>&1; then
        printf '%s\n' "$candidate"
        return 0
    fi

    remote_candidate="origin/$candidate"
    if git -C "$repo_root" rev-parse --verify "$remote_candidate^{commit}" >/dev/null 2>&1; then
        printf '%s\n' "$remote_candidate"
        return 0
    fi

    die "base_ref is not a valid commit or branch: $candidate"
}

scoped_changes() {
    repo_root=$1
    base_ref=$2

    committed_changes=$(git -C "$repo_root" diff --name-only "$base_ref"...HEAD -- .github/workflows scripts/guard-command.sh)
    local_changes=$(git -C "$repo_root" status --porcelain -- .github/workflows scripts/guard-command.sh)

    printf '%s\n' "$committed_changes"
    printf '%s\n' "$local_changes"
}

task_id=$(require_env TASK_ID)
repo_root=$(require_env REPO_ROOT)
base_ref=$(require_env BASE_REF)
resolved_base_ref=$(resolve_base_ref "$repo_root" "$base_ref")

case "$task_id" in
    phase2-scheduler-artifact-dry-run-pilot)
        changed_paths=$(scoped_changes "$repo_root" "$resolved_base_ref" | sort -u)
        if [ -n "$changed_paths" ]; then
            printf '%s\n' "CI or guard rollout changes are out of scope for this pilot:" >&2
            printf '%s\n' "$changed_paths" >&2
            exit 1
        fi
        printf '%s\n' "repo-local dry-run scope excludes CI wiring and guard rollout"
        ;;
    phase2-ci-unified-gate-pilot-task)
        [ -f "$repo_root/.github/workflows/phase2-ci-unified-gate-pilot.yml" ] || die "missing pilot workflow file"
        [ -f "$repo_root/scripts/ci-unified-gate-pilot.sh" ] || die "missing CI adapter entrypoint"
        printf '%s\n' "ci unified gate pilot is limited to one workflow and one repository-owned adapter"
        ;;
    *)
        printf '%s\n' "Phase 2 dry-run unit assertions are only implemented for $task_id." >&2
        exit 1
        ;;
esac
