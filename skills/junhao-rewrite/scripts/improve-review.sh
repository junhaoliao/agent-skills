#!/bin/sh
set -eu

MODEL='claude-fable-5[1m]'
EFFORT='xhigh'
MAX_DISPOSITIONS_BYTES=65536

usage() {
    printf '%s\n' \
        'Usage:' \
        '  improve-review.sh start commit <commit-sha>' \
        '  improve-review.sh resume commit <session-anchor-sha> [current-commit-sha] --dispositions <file>' \
        '  improve-review.sh start batch <base-sha> [head-sha]' \
        '  improve-review.sh resume batch <base-sha> [head-sha] --dispositions <file>' \
        '  improve-review.sh fresh batch <base-sha> [head-sha]'
}

fail() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

resolve_commit() {
    git rev-parse --verify "$1^{commit}" 2>/dev/null
}

new_session_id() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [ -r /proc/sys/kernel/random/uuid ]; then
        sed -n '1p' /proc/sys/kernel/random/uuid
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c 'import uuid; print(uuid.uuid4())'
    else
        fail 'uuidgen, /proc UUID support, or python3 is required'
    fi
}

[ "$#" -ge 3 ] || {
    usage >&2
    exit 2
}

action=$1
scope=$2
shift 2

case "$action" in
    start|resume|fresh) ;;
    *) fail "unknown action: $action" ;;
esac

case "$scope" in
    commit|batch) ;;
    *) fail "unknown scope: $scope" ;;
esac

[ "$action" != fresh ] || [ "$scope" = batch ] ||
    fail 'fresh is supported only for batch scope'

argument_count=0
argument_1=''
argument_2=''
dispositions_file=''

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dispositions)
            shift
            [ "$#" -gt 0 ] || fail '--dispositions requires a file'
            [ -z "$dispositions_file" ] ||
                fail '--dispositions may be supplied only once'
            dispositions_file=$1
            ;;
        --*) fail "unknown option: $1" ;;
        *)
            argument_count=$((argument_count + 1))
            case "$argument_count" in
                1) argument_1=$1 ;;
                2) argument_2=$1 ;;
                *) fail 'too many positional arguments' ;;
            esac
            ;;
    esac
    shift
done

if [ "$action" = resume ]; then
    [ -n "$dispositions_file" ] ||
        fail 'resume requires --dispositions with the vetted finding ledger'
    [ -f "$dispositions_file" ] ||
        fail "cannot read dispositions file: $dispositions_file"
    dispositions_size=$(wc -c <"$dispositions_file" | tr -d '[:space:]')
    [ "$dispositions_size" -le "$MAX_DISPOSITIONS_BYTES" ] ||
        fail 'dispositions file exceeds 65536 bytes'
else
    [ -z "$dispositions_file" ] ||
        fail '--dispositions is accepted only by resume'
fi

command -v git >/dev/null 2>&1 || fail 'git is required'
command -v claude >/dev/null 2>&1 || fail 'claude CLI is required'

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) ||
    fail 'run this command inside a Git worktree'
cd "$repo_root"
repo_root=$(pwd -P)

if [ "$scope" = commit ]; then
    if [ "$action" = resume ]; then
        if [ "$argument_count" -lt 1 ] || [ "$argument_count" -gt 2 ]; then
            fail 'resume commit requires an anchor and optional current SHA'
        fi
        anchor=$(resolve_commit "$argument_1") ||
            fail "cannot resolve commit session anchor: $argument_1"
        target_arg=${argument_2:-$argument_1}
    else
        [ "$argument_count" -eq 1 ] ||
            fail 'start commit requires exactly one commit SHA'
        anchor=$(resolve_commit "$argument_1") ||
            fail "cannot resolve commit: $argument_1"
        target_arg=$argument_1
    fi

    target=$(resolve_commit "$target_arg") ||
        fail "cannot resolve current commit: $target_arg"
    parent=$(resolve_commit "$target^") ||
        fail 'the root commit cannot be reviewed with commit scope'
    short_anchor=$(git rev-parse --short=12 "$anchor")
    key="commit-$short_anchor"
    review_scope="commit $target, range $parent..$target"
    initial_prompt="/improve

Audit findings only; do not create or modify plans or any repository file. Review only the introduced delta in commit $target ($parent..$target) plus direct callers needed to validate that delta. Treat earlier history as baseline. Label anything pre-existing explicitly. Inspect correctness, security, tests, maintainability, dependency or contract drift, and whether this commit is independently coherent and valid. Return evidence-backed findings and a clear no-actionable-findings verdict when appropriate."
else
    if [ "$argument_count" -lt 1 ] || [ "$argument_count" -gt 2 ]; then
        fail 'batch scope requires a base SHA and optional head SHA'
    fi
    base=$(resolve_commit "$argument_1") ||
        fail "cannot resolve base commit: $argument_1"
    head_arg=${argument_2:-HEAD}
    head=$(resolve_commit "$head_arg") ||
        fail "cannot resolve head commit: $head_arg"
    [ "$base" != "$head" ] || fail 'batch range must not be empty'
    git merge-base --is-ancestor "$base" "$head" ||
        fail 'batch base is not an ancestor of batch head'
    short_base=$(git rev-parse --short=12 "$base")
    key="batch-$short_base"
    review_scope="curated rewrite range $base..$head"
    initial_prompt="/improve

Audit findings only; do not create or modify plans or any repository file. Audit the complete curated rewrite range $base..$head and its affected callers. Verify cross-commit coherence, correctness, security, tests, maintainability, dependency and contract consistency, intermediate-commit validity risks, and unintended behavior drift. Separate introduced findings from pre-existing issues. Return evidence-backed findings and a clear no-actionable-findings verdict when appropriate."
fi

common_git_dir=$(git rev-parse --path-format=absolute --git-common-dir)
git_private_dir="$common_git_dir/junhao-rewrite"
mkdir -p "$git_private_dir"
session_file="$git_private_dir/improve-$key.session"

if [ "$action" = resume ]; then
    [ -s "$session_file" ] ||
        fail "no saved session for $review_scope; run start first"
    session_id=$(sed -n '1p' "$session_file")
    session_root=$(sed -n '2p' "$session_file")
    [ "$session_root" = "$repo_root" ] ||
        fail "resume from the original review worktree: $session_root"
    dispositions=$(cat "$dispositions_file")
    follow_up="Re-run the /improve audit for the updated $review_scope. The implementation agent independently vetted the prior findings. Re-read the current exact code and diff; do not rely on the earlier snapshot. Do not modify files or create plans. Challenge unsupported dispositions, report remaining or newly introduced evidence-backed findings, and state clearly when no actionable finding remains.

Vetted finding dispositions:
$dispositions"
    printf 'Resuming Claude improve session %s for %s\n' \
        "$session_id" "$review_scope" >&2
    exec claude --print --output-format text \
        --resume "$session_id" \
        --model "$MODEL" \
        --effort "$EFFORT" \
        --permission-mode plan \
        "$follow_up"
fi

session_id=$(new_session_id)
printf 'Starting Claude improve session %s for %s\n' \
    "$session_id" "$review_scope" >&2

if claude --print --output-format text \
    --session-id "$session_id" \
    --name "junhao-rewrite-$key" \
    --model "$MODEL" \
    --effort "$EFFORT" \
    --permission-mode plan \
    "$initial_prompt"; then
    printf '%s\n%s\n' "$session_id" "$repo_root" >"$session_file"
else
    status=$?
    printf 'Claude improve session failed; no resumable session was recorded.\n' >&2
    exit "$status"
fi
