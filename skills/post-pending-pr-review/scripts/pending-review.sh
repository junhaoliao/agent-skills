#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

readonly SNAPSHOT_VERSION=1

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

note() {
    printf '%s\n' "$*" >&2
}

usage() {
    cat >&2 <<'USAGE'
Usage:
  pending-review.sh snapshot --repo OWNER/REPO --pr N --output FILE [--hostname HOST]
  pending-review.sh validate --snapshot FILE --payload FILE
  pending-review.sh apply --snapshot FILE --payload FILE --run
  pending-review.sh self-test

The payload is the GitHub create-review JSON object:
  {"commit_id":"...","body":"...","comments":[...]}

Never include `event`; omitting it creates a PENDING review.
USAGE
}

need_command() {
    command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

need_json_file() {
    local path="$1"
    [[ -f "$path" ]] || die "JSON file not found: $path"
    jq -e . "$path" >/dev/null || die "invalid JSON: $path"
}

make_temp_dir() {
    REVIEW_HELPER_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pending-review.XXXXXX")"
    trap 'rm -rf -- "$REVIEW_HELPER_TEMP_DIR"' EXIT HUP INT TERM
}

api() {
    gh api --hostname "$GITHUB_HOST" "$@"
}

preflight_github() {
    need_command gh
    need_command jq
    gh auth status --hostname "$GITHUB_HOST" >/dev/null 2>&1 ||
        die "gh is not authenticated for $GITHUB_HOST"
}

split_repo() {
    [[ "$REPO_SLUG" =~ ^[^/]+/[^/]+$ ]] ||
        die "--repo must be OWNER/REPO: $REPO_SLUG"
    REPO_OWNER="${REPO_SLUG%%/*}"
    REPO_NAME="${REPO_SLUG#*/}"
}

fetch_graphql_comments() {
    # Keep GraphQL variables literal for gh to bind through -F.
    # shellcheck disable=SC2016
    api graphql --paginate --slurp \
        -F owner="$REPO_OWNER" \
        -F name="$REPO_NAME" \
        -F number="$PR_NUMBER" \
        -f query='query(
          $owner: String!,
          $name: String!,
          $number: Int!,
          $endCursor: String
        ) {
          repository(owner: $owner, name: $name) {
            pullRequest(number: $number) {
              reviewThreads(first: 100, after: $endCursor) {
                nodes {
                  comments(first: 100) {
                    nodes {
                      databaseId
                      body
                      path
                      line
                      originalLine
                      startLine
                      originalStartLine
                      diffHunk
                      pullRequestReview {
                        databaseId
                      }
                    }
                  }
                }
                pageInfo {
                  hasNextPage
                  endCursor
                }
              }
            }
          }
        }' |
        jq '[
          .[].data.repository.pullRequest.reviewThreads.nodes[]
          | .comments.nodes[]
        ]'
}

fetch_pending_state() {
    local viewer="$1"
    local reviews_file="$REVIEW_HELPER_TEMP_DIR/reviews.json"
    local pending_count pending_id
    local detail_file="$REVIEW_HELPER_TEMP_DIR/review-detail.json"
    local rest_comments_file="$REVIEW_HELPER_TEMP_DIR/review-comments.json"
    local graphql_comments_file="$REVIEW_HELPER_TEMP_DIR/graphql-comments.json"

    api "repos/$REPO_SLUG/pulls/$PR_NUMBER/reviews?per_page=100" \
        --paginate --slurp |
        jq 'add' >"$reviews_file"

    pending_count="$(
        jq --arg viewer "$viewer" \
            '[.[] | select(.state == "PENDING" and .user.login == $viewer)] | length' \
            "$reviews_file"
    )"
    ((pending_count <= 1)) ||
        die "found $pending_count pending reviews owned by $viewer; refusing to guess"

    if ((pending_count == 0)); then
        printf 'null\n'
        return
    fi

    pending_id="$(
        jq -r --arg viewer "$viewer" \
            '.[] | select(.state == "PENDING" and .user.login == $viewer) | .id' \
            "$reviews_file"
    )"
    api "repos/$REPO_SLUG/pulls/$PR_NUMBER/reviews/$pending_id" >"$detail_file"
    api "repos/$REPO_SLUG/pulls/$PR_NUMBER/reviews/$pending_id/comments?per_page=100" \
        --paginate --slurp |
        jq 'add' >"$rest_comments_file"
    fetch_graphql_comments >"$graphql_comments_file"

    jq -n \
        --slurpfile detail "$detail_file" \
        --slurpfile rest "$rest_comments_file" \
        --slurpfile graphql "$graphql_comments_file" '
      $detail[0] as $review
      | $graphql[0] as $graphql_comments
      | {
          id: $review.id,
          state: $review.state,
          commit_id: $review.commit_id,
          body: ($review.body // ""),
          html_url: ($review.html_url // $review._links.html.href),
          comments: [
            $rest[0][]
            | . as $rest_comment
            | (
                $graphql_comments
                | map(select(.databaseId == $rest_comment.id))[0] // {}
              ) as $graphql_comment
            | {
                id: $rest_comment.id,
                path: $rest_comment.path,
                body: $rest_comment.body,
                line: (
                  $graphql_comment.line
                  // $graphql_comment.originalLine
                  // $rest_comment.line
                  // $rest_comment.original_line
                ),
                start_line: (
                  $graphql_comment.startLine
                  // $graphql_comment.originalStartLine
                  // $rest_comment.start_line
                  // $rest_comment.original_start_line
                ),
                side: (
                  $rest_comment.side
                  // (if (
                    $graphql_comment.line
                    // $graphql_comment.originalLine
                    // $rest_comment.line
                    // $rest_comment.original_line
                  ) != null then "RIGHT" else null end)
                ),
                start_side: (
                  $rest_comment.start_side
                  // (if (
                    $graphql_comment.startLine
                    // $graphql_comment.originalStartLine
                    // $rest_comment.start_line
                    // $rest_comment.original_start_line
                  ) != null then "RIGHT" else null end)
                ),
                position: ($rest_comment.position // $rest_comment.original_position),
                diff_hunk: ($graphql_comment.diffHunk // $rest_comment.diff_hunk),
                html_url: $rest_comment.html_url
              }
          ] | sort_by(.id)
        }'
}

pending_fingerprint_filter='def normalized_pending:
  if . == null then null
  else {
    id,
    commit_id,
    body,
    comments: ([.comments[] | {
      id,
      path,
      line,
      start_line,
      side,
      start_side,
      position,
      body
    }] | sort_by(.id))
  }
  end;
normalized_pending | tojson'

snapshot_command() {
    local output_file=""
    local files_file pending_file head_sha viewer pending_fingerprint

    REPO_SLUG=""
    PR_NUMBER=""
    GITHUB_HOST="github.com"

    while (($# > 0)); do
        case "$1" in
            --repo)
                (($# >= 2)) || die "--repo requires a value"
                REPO_SLUG="$2"
                shift 2
                ;;
            --pr)
                (($# >= 2)) || die "--pr requires a value"
                PR_NUMBER="$2"
                shift 2
                ;;
            --hostname)
                (($# >= 2)) || die "--hostname requires a value"
                GITHUB_HOST="$2"
                shift 2
                ;;
            --output)
                (($# >= 2)) || die "--output requires a value"
                output_file="$2"
                shift 2
                ;;
            *)
                die "unknown snapshot argument: $1"
                ;;
        esac
    done

    [[ -n "$REPO_SLUG" ]] || die "snapshot requires --repo"
    [[ "$PR_NUMBER" =~ ^[1-9][0-9]*$ ]] || die "snapshot requires a numeric --pr"
    [[ -n "$output_file" ]] || die "snapshot requires --output"
    split_repo
    preflight_github
    make_temp_dir

    files_file="$REVIEW_HELPER_TEMP_DIR/files.json"
    pending_file="$REVIEW_HELPER_TEMP_DIR/pending.json"
    head_sha="$(api "repos/$REPO_SLUG/pulls/$PR_NUMBER" --jq '.head.sha')"
    viewer="$(api user --jq '.login')"
    api "repos/$REPO_SLUG/pulls/$PR_NUMBER/files?per_page=100" \
        --paginate --slurp |
        jq 'add' >"$files_file"
    fetch_pending_state "$viewer" >"$pending_file"
    pending_fingerprint="$(jq -r "$pending_fingerprint_filter" "$pending_file")"

    jq -n \
        --argjson version "$SNAPSHOT_VERSION" \
        --arg hostname "$GITHUB_HOST" \
        --arg repo "$REPO_SLUG" \
        --argjson pr_number "$PR_NUMBER" \
        --arg viewer "$viewer" \
        --arg head_sha "$head_sha" \
        --arg pending_fingerprint "$pending_fingerprint" \
        --slurpfile pending "$pending_file" \
        --slurpfile files "$files_file" '{
          version: $version,
          hostname: $hostname,
          repo: $repo,
          pr_number: $pr_number,
          viewer: $viewer,
          head_sha: $head_sha,
          pending_fingerprint: $pending_fingerprint,
          pending: $pending[0],
          files: [
            $files[0][] | {
              filename,
              status,
              previous_filename,
              patch
            }
          ]
        }' >"$output_file"

    note "snapshot=$output_file head=$head_sha files=$(jq '.files | length' "$output_file") pending=$(jq 'if .pending == null then 0 else 1 end' "$output_file")"
}

# This is a literal jq program; its dollar-prefixed names are jq variables.
# shellcheck disable=SC2016
validation_filter='def hunk_ranges($patch):
  [
    $patch
    | split("\n")[]
    | capture("^@@ -[0-9]+(,[0-9]+)? \\+(?<start>[0-9]+)(,(?<count>[0-9]+))? @@")?
    | select(. != null)
    | {
        start: (.start | tonumber),
        count: ((.count // "1") | tonumber)
      }
    | . + {end: (.start + .count - 1)}
  ];

def suggestion_count($body):
  [$body | scan("```suggestion")] | length;

($snapshot[0]) as $s
| ($payload[0]) as $p
| (
    [
      if $s.version == 1 then empty else "unsupported snapshot version" end,
      if ($p | type) == "object" then empty else "payload must be an object" end,
      if ($p | has("event") | not) then empty else "payload must omit event" end,
      if ($p.commit_id | type) == "string" then empty else "payload.commit_id must be a string" end,
      if $p.commit_id == $s.head_sha then empty else "payload.commit_id must equal snapshot head_sha" end,
      if (($p.body // "") | type) == "string" then empty else "payload.body must be a string" end,
      if (($p.body // "") | contains("```suggestion") | not) then empty
      else "review body must not contain suggestion fences"
      end,
      if ($p.comments | type) == "array" then empty else "payload.comments must be an array" end
    ]
    + (
      if ($p.comments | type) != "array" then []
      else [
        range(0; $p.comments | length) as $index
        | $p.comments[$index] as $comment
        | ($s.files | map(select(.filename == $comment.path))[0]) as $file
        | ($comment.start_line // $comment.line) as $range_start
        | [
            if ($comment | type) == "object" then empty
            else "comment[\($index)] must be an object"
            end,
            if ($comment.path | type) == "string" and ($comment.path | length) > 0 then empty
            else "comment[\($index)].path must be a non-empty string"
            end,
            if ($comment.body | type) == "string" and ($comment.body | length) > 0 then empty
            else "comment[\($index)].body must be a non-empty string"
            end,
            if ($comment.line | type) == "number" and ($comment.line | floor) == $comment.line and $comment.line > 0 then empty
            else "comment[\($index)].line must be a positive integer"
            end,
            if $comment.side == "RIGHT" then empty
            else "comment[\($index)].side must be RIGHT"
            end,
            if ($comment.start_line == null) or (
              ($comment.start_line | type) == "number"
              and ($comment.start_line | floor) == $comment.start_line
              and $comment.start_line > 0
              and $comment.start_line <= $comment.line
            ) then empty
            else "comment[\($index)].start_line must be a positive integer not greater than line"
            end,
            if ($comment.start_line == null and $comment.start_side == null) or (
              $comment.start_line != null and $comment.start_side == "RIGHT"
            ) then empty
            else "comment[\($index)].start_side must be RIGHT exactly when start_line is present"
            end,
            if suggestion_count($comment.body) <= 1 then empty
            else "comment[\($index)] contains more than one suggestion fence"
            end,
            if $file != null then empty
            else "comment[\($index)] path is not in the final changed-file list"
            end,
            if $file == null or $file.status != "removed" then empty
            else "comment[\($index)] targets a removed file on the RIGHT side"
            end,
            if $file == null or ($file.patch | type) == "string" then empty
            else "comment[\($index)] has no usable final patch; move it to the review body"
            end,
            if $file == null or ($file.patch | type) != "string" then empty
            elif any(hunk_ranges($file.patch)[]; $range_start >= .start and $comment.line <= .end) then empty
            else "comment[\($index)] range is outside a single final RIGHT-side hunk"
            end
          ][]
      ]
      end
    )
    + (
      if ($p.comments | type) != "array" then []
      else (
        [$p.comments[]
          | select(suggestion_count(.body) == 1)
          | {
              path,
              start: (.start_line // .line),
              end: .line
            }
        ] as $suggestions
        | [
            range(0; $suggestions | length) as $left
            | range($left + 1; $suggestions | length) as $right
            | select(
                $suggestions[$left].path == $suggestions[$right].path
                and $suggestions[$left].start <= $suggestions[$right].end
                and $suggestions[$right].start <= $suggestions[$left].end
              )
            | "suggestion ranges overlap in \($suggestions[$left].path)"
          ]
      )
      end
    )
  ) as $errors
| {
    valid: ($errors | length == 0),
    errors: $errors,
    head_sha: $s.head_sha,
    comment_count: (if ($p.comments | type) == "array" then ($p.comments | length) else 0 end),
    pending_review_id: ($s.pending.id // null)
  }'

validate_payload() {
    local snapshot_file="$1"
    local payload_file="$2"
    local result_file="$REVIEW_HELPER_TEMP_DIR/validation.json"

    need_json_file "$snapshot_file"
    need_json_file "$payload_file"
    jq -n \
        --slurpfile snapshot "$snapshot_file" \
        --slurpfile payload "$payload_file" \
        "$validation_filter" >"$result_file"
    if ! jq -e '.valid' "$result_file" >/dev/null; then
        jq -r '.errors[] | "error: " + .' "$result_file" >&2
        return 1
    fi
    jq . "$result_file"
}

validate_command() {
    local snapshot_file=""
    local payload_file=""

    while (($# > 0)); do
        case "$1" in
            --snapshot)
                (($# >= 2)) || die "--snapshot requires a value"
                snapshot_file="$2"
                shift 2
                ;;
            --payload)
                (($# >= 2)) || die "--payload requires a value"
                payload_file="$2"
                shift 2
                ;;
            *)
                die "unknown validate argument: $1"
                ;;
        esac
    done

    [[ -n "$snapshot_file" ]] || die "validate requires --snapshot"
    [[ -n "$payload_file" ]] || die "validate requires --payload"
    need_command jq
    make_temp_dir
    validate_payload "$snapshot_file" "$payload_file"
}

same_comment_topology() {
    local pending_file="$1"
    local payload_file="$2"
    jq -e -n \
        --slurpfile pending "$pending_file" \
        --slurpfile payload "$payload_file" '
      $pending[0] as $old
      | $payload[0] as $new
      | $old != null
      and $old.commit_id == $new.commit_id
      and ($old.comments | length) == ($new.comments | length)
      and all($old.comments[];
        . as $old_comment
        | ([
            $new.comments[]
            | select(
                .path == $old_comment.path
                and .line == $old_comment.line
                and (.start_line // null) == ($old_comment.start_line // null)
                and .side == ($old_comment.side // "RIGHT")
                and (.start_side // null) == ($old_comment.start_side // null)
              )
          ] | length) == 1
      )' >/dev/null
}

update_in_place() {
    local pending_file="$1"
    local payload_file="$2"
    local review_id old_body new_body mapping_file mapping_count index
    local update_file comment_id

    review_id="$(jq -r '.id' "$pending_file")"
    old_body="$(jq -r '.body' "$pending_file")"
    new_body="$(jq -r '.body // ""' "$payload_file")"

    if [[ "$old_body" != "$new_body" ]]; then
        update_file="$REVIEW_HELPER_TEMP_DIR/update-review.json"
        jq '{body: (.body // "")}' "$payload_file" >"$update_file"
        api "repos/$REPO_SLUG/pulls/$PR_NUMBER/reviews/$review_id" \
            --method PUT --input "$update_file" >/dev/null
    fi

    mapping_file="$REVIEW_HELPER_TEMP_DIR/comment-updates.json"
    jq -n \
        --slurpfile pending "$pending_file" \
        --slurpfile payload "$payload_file" '[
      $pending[0].comments[]
      | . as $old
      | (
          $payload[0].comments
          | map(select(
              .path == $old.path
              and .line == $old.line
              and (.start_line // null) == ($old.start_line // null)
            ))[0]
        ) as $new
      | select($old.body != $new.body)
      | {id: $old.id, body: $new.body}
    ]' >"$mapping_file"

    mapping_count="$(jq 'length' "$mapping_file")"
    index=0
    while ((index < mapping_count)); do
        comment_id="$(jq -r ".[$index].id" "$mapping_file")"
        update_file="$REVIEW_HELPER_TEMP_DIR/update-comment-$index.json"
        jq ".[$index] | {body}" "$mapping_file" >"$update_file"
        api "repos/$REPO_SLUG/pulls/comments/$comment_id" \
            --method PATCH --input "$update_file" >/dev/null
        index=$((index + 1))
    done

    printf '%s\n' "$review_id"
}

build_backup_payload() {
    local pending_file="$1"
    local backup_file="$2"
    jq '{
      commit_id,
      body,
      comments: [
        .comments[]
        | if .line != null then
            {
              path,
              line,
              side: (.side // "RIGHT"),
              body
            }
            + (if .start_line != null then {
                start_line,
                start_side: (.start_side // "RIGHT")
              } else {} end)
          else
            {
              path,
              position,
              body
            }
          end
      ]
    }' "$pending_file" >"$backup_file"
}

replace_pending_review() {
    local pending_file="$1"
    local payload_file="$2"
    local response_file="$3"
    local old_review_id backup_file rollback_response

    if [[ "$(jq -r 'type' "$pending_file")" != "null" ]]; then
        old_review_id="$(jq -r '.id' "$pending_file")"
        backup_file="$REVIEW_HELPER_TEMP_DIR/backup-payload.json"
        build_backup_payload "$pending_file" "$backup_file"
        jq -e 'all(.comments[]; (.line? != null) or (.position? != null))' \
            "$backup_file" >/dev/null ||
            die "cannot safely back up every existing pending comment"
        api "repos/$REPO_SLUG/pulls/$PR_NUMBER/reviews/$old_review_id" \
            --method DELETE >/dev/null
    else
        old_review_id=""
        backup_file=""
    fi

    if api "repos/$REPO_SLUG/pulls/$PR_NUMBER/reviews" \
        --method POST \
        --header 'Accept: application/vnd.github+json' \
        --input "$payload_file" >"$response_file"; then
        return
    fi

    if [[ -n "$backup_file" ]]; then
        note "replacement failed; attempting to restore the original pending review"
        rollback_response="$REVIEW_HELPER_TEMP_DIR/rollback-response.json"
        if api "repos/$REPO_SLUG/pulls/$PR_NUMBER/reviews" \
            --method POST \
            --header 'Accept: application/vnd.github+json' \
            --input "$backup_file" >"$rollback_response"; then
            note "original pending review restored as review $(jq -r '.id' "$rollback_response")"
        else
            note "warning: automatic restoration also failed"
        fi
    fi
    die "GitHub rejected the replacement review"
}

verify_pending_review() {
    local payload_file="$1"
    local expected_review_id="$2"
    local pending_file="$REVIEW_HELPER_TEMP_DIR/verified-pending.json"
    local current_head

    current_head="$(api "repos/$REPO_SLUG/pulls/$PR_NUMBER" --jq '.head.sha')"
    [[ "$current_head" == "$(jq -r '.commit_id' "$payload_file")" ]] ||
        die "PR head moved during posting; review may now be stale"
    fetch_pending_state "$VIEWER_LOGIN" >"$pending_file"

    jq -e -n \
        --argjson expected_review_id "$expected_review_id" \
        --slurpfile pending "$pending_file" \
        --slurpfile payload "$payload_file" '
      def comment_key:
        [
          .path,
          (.start_line // .line),
          .line,
          .body
        ];
      $pending[0] as $actual
      | $payload[0] as $expected
      | $actual != null
      and $actual.id == $expected_review_id
      and $actual.state == "PENDING"
      and $actual.commit_id == $expected.commit_id
      and $actual.body == ($expected.body // "")
      and (
        [$actual.comments[] | comment_key] | sort
      ) == (
        [$expected.comments[] | comment_key] | sort
      )' >/dev/null || die "posted pending review did not match the validated payload"

    jq -n \
        --arg mutation "$APPLY_MUTATION" \
        --slurpfile pending "$pending_file" '{
          mutation: $mutation,
          id: $pending[0].id,
          state: $pending[0].state,
          commit_id: $pending[0].commit_id,
          html_url: $pending[0].html_url,
          comment_count: ($pending[0].comments | length)
        }'
}

apply_command() {
    local snapshot_file=""
    local source_payload_file=""
    local run_authorized=false
    local current_head current_pending_file current_fingerprint expected_fingerprint
    local api_payload_file response_file review_id

    while (($# > 0)); do
        case "$1" in
            --snapshot)
                (($# >= 2)) || die "--snapshot requires a value"
                snapshot_file="$2"
                shift 2
                ;;
            --payload)
                (($# >= 2)) || die "--payload requires a value"
                source_payload_file="$2"
                shift 2
                ;;
            --run)
                run_authorized=true
                shift
                ;;
            *)
                die "unknown apply argument: $1"
                ;;
        esac
    done

    [[ -n "$snapshot_file" ]] || die "apply requires --snapshot"
    [[ -n "$source_payload_file" ]] || die "apply requires --payload"
    [[ "$run_authorized" == true ]] || die "apply requires explicit --run authorization"
    need_command jq
    make_temp_dir
    need_json_file "$snapshot_file"
    need_json_file "$source_payload_file"

    GITHUB_HOST="$(jq -r '.hostname' "$snapshot_file")"
    REPO_SLUG="$(jq -r '.repo' "$snapshot_file")"
    PR_NUMBER="$(jq -r '.pr_number' "$snapshot_file")"
    VIEWER_LOGIN="$(jq -r '.viewer' "$snapshot_file")"
    split_repo
    preflight_github
    validate_payload "$snapshot_file" "$source_payload_file" >/dev/null

    api_payload_file="$REVIEW_HELPER_TEMP_DIR/api-payload.json"
    jq 'del(.event, ._meta)' "$source_payload_file" >"$api_payload_file"

    current_head="$(api "repos/$REPO_SLUG/pulls/$PR_NUMBER" --jq '.head.sha')"
    [[ "$current_head" == "$(jq -r '.head_sha' "$snapshot_file")" ]] ||
        die "PR head changed after snapshot; refresh and merge again"
    [[ "$(api user --jq '.login')" == "$VIEWER_LOGIN" ]] ||
        die "authenticated GitHub user changed after snapshot"

    current_pending_file="$REVIEW_HELPER_TEMP_DIR/current-pending.json"
    fetch_pending_state "$VIEWER_LOGIN" >"$current_pending_file"
    current_fingerprint="$(jq -r "$pending_fingerprint_filter" "$current_pending_file")"
    expected_fingerprint="$(jq -r '.pending_fingerprint' "$snapshot_file")"
    [[ "$current_fingerprint" == "$expected_fingerprint" ]] ||
        die "pending review changed after snapshot; refresh and merge again"

    response_file="$REVIEW_HELPER_TEMP_DIR/post-response.json"
    if same_comment_topology "$current_pending_file" "$api_payload_file"; then
        APPLY_MUTATION="updated-in-place"
        review_id="$(update_in_place "$current_pending_file" "$api_payload_file")"
    else
        if [[ "$(jq -r 'type' "$current_pending_file")" == "null" ]]; then
            APPLY_MUTATION="created"
        else
            APPLY_MUTATION="replaced"
        fi
        replace_pending_review "$current_pending_file" "$api_payload_file" "$response_file"
        review_id="$(jq -r '.id' "$response_file")"
    fi

    [[ "$review_id" =~ ^[1-9][0-9]*$ ]] || die "GitHub did not return a valid review id"
    verify_pending_review "$api_payload_file" "$review_id"
}

self_test_command() {
    local snapshot_file payload_file invalid_file overlap_file

    need_command jq
    make_temp_dir
    snapshot_file="$REVIEW_HELPER_TEMP_DIR/snapshot.json"
    payload_file="$REVIEW_HELPER_TEMP_DIR/payload.json"
    invalid_file="$REVIEW_HELPER_TEMP_DIR/invalid.json"
    overlap_file="$REVIEW_HELPER_TEMP_DIR/overlap.json"

    cat >"$snapshot_file" <<'SNAPSHOT'
{
  "version": 1,
  "hostname": "github.com",
  "repo": "example/project",
  "pr_number": 7,
  "viewer": "reviewer",
  "head_sha": "abc123",
  "pending_fingerprint": "null",
  "pending": null,
  "files": [
    {
      "filename": "src/app.ts",
      "status": "modified",
      "previous_filename": null,
      "patch": "@@ -8,3 +8,5 @@\n context\n+added\n+more\n context\n context\n@@ -30,2 +32,2 @@\n-old\n+new\n context"
    }
  ]
}
SNAPSHOT
    cat >"$payload_file" <<'PAYLOAD'
{
  "commit_id": "abc123",
  "body": "review body",
  "comments": [
    {
      "path": "src/app.ts",
      "line": 10,
      "side": "RIGHT",
      "body": "please adjust this\n\n```suggestion\nreplacement\n```"
    }
  ]
}
PAYLOAD
    jq '.comments[0].line = 20' "$payload_file" >"$invalid_file"
    jq '.comments += [{
      path: "src/app.ts",
      line: 10,
      side: "RIGHT",
      body: "second\n\n```suggestion\nother\n```"
    }]' "$payload_file" >"$overlap_file"

    validate_payload "$snapshot_file" "$payload_file" >/dev/null
    if validate_payload "$snapshot_file" "$invalid_file" >/dev/null 2>&1; then
        die "self-test expected out-of-hunk validation to fail"
    fi
    if validate_payload "$snapshot_file" "$overlap_file" >/dev/null 2>&1; then
        die "self-test expected overlapping suggestions to fail"
    fi
    note "self-test passed"
}

main() {
    local command_name="${1:-}"
    [[ -n "$command_name" ]] || {
        usage
        exit 2
    }
    shift

    case "$command_name" in
        snapshot)
            snapshot_command "$@"
            ;;
        validate)
            validate_command "$@"
            ;;
        apply)
            apply_command "$@"
            ;;
        self-test)
            (($# == 0)) || die "self-test takes no arguments"
            self_test_command
            ;;
        -h | --help | help)
            usage
            ;;
        *)
            usage
            die "unknown command: $command_name"
            ;;
    esac
}

main "$@"
