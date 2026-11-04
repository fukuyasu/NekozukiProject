#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/milestone.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

# 授業用PortableGitではjq.exeが/usr/local/binに置かれている。
[[ -x /usr/local/bin/jq.exe ]] && export PATH="/usr/local/bin:${PATH}"

# 授業用のbash_profileはWindowsのシステムPATHを引き継がないため、
# Windows PowerShellを明示的に探索する。
POWERSHELL_EXE="$(command -v powershell.exe || true)"
if [[ -z "$POWERSHELL_EXE" ]]; then
  for candidate in \
    /c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
    /c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe; do
    if [[ -x "$candidate" ]]; then
      POWERSHELL_EXE="$candidate"
      break
    fi
  done
fi
[[ -n "$POWERSHELL_EXE" ]] || {
  echo 'エラー: Windows PowerShellが見つかりません。Windows上のPortableGit Bashで実行してください。' >&2
  exit 1
}

for command_name in gh jq git date cygpath; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "エラー: ${command_name} が見つかりません。PortableGit BashとGitHub CLIを利用できる環境で実行してください。" >&2
    exit 1
  }
done

LOGIN="$(gh api user --jq .login)"
STUDENT="$LOGIN"
MILESTONE=""
while (($#)); do
  case "$1" in
    --student|--milestone)
      (($# >= 2)) || { echo "エラー: $1 には値が必要です。" >&2; exit 2; }
      case "$1" in
        --student) STUDENT="$2" ;;
        --milestone) MILESTONE="$2" ;;
      esac
      shift 2 ;;
    *) echo "使い方: $0 --milestone lec06～lec14 [--student GitHub名]" >&2; exit 2 ;;
  esac
done
[[ "$STUDENT" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,38}$ ]] || { echo 'エラー: 学生のGitHub名が不正です。' >&2; exit 2; }
[[ -n "$MILESTONE" ]] || { echo 'エラー: --milestone にlec06～lec14を指定してください。' >&2; exit 2; }
REPOSITORY="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
require_milestone "$MILESTONE" "$REPOSITORY" || exit 1
DATA_DIR="docs/weekly-summary-data/${STUDENT}"
REPORT_FILE="docs/weekly-summary_${STUDENT}.html"

NOW="$(date -u -d '+9 hours' '+%Y-%m-%dT%H:%M:%S+09:00')"
FILE_STAMP="$(date -u -d '+9 hours' '+%Y-%m-%d_%H%M%S')"
DATA_FILE="${DATA_DIR}/${MILESTONE}.json"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT

duration_seconds() {
  local start="$1" end="$2"
  local start_seconds end_seconds
  start_seconds="$(date -d "$start" +%s 2>/dev/null)" || return 1
  end_seconds="$(date -d "$end" +%s 2>/dev/null)" || return 1
  (( end_seconds >= start_seconds )) || return 1
  printf '%s' "$((end_seconds - start_seconds))"
}

reflog_branch_start() {
  local branch="$1"
  [[ -n "$branch" ]] || return 1
  git reflog show --date=iso-local "refs/heads/${branch}" 2>/dev/null |
    sed -nE 's/^.*@\{([^}]*)\}: branch: Created from (origin\/main|main)$/\1/p' |
    tail -n 1
}

choose_start() {
  local branch="$1" commits_json="$2" issue_created="$3" pr_created="$4"
  local value
  value="$(reflog_branch_start "$branch" || true)"
  if [[ -n "$value" ]]; then printf '%s\t%s' "$value" reflog; return; fi
  value="$(jq -r '[.[] | .committedAt // .authoredAt // empty] | min // empty' <<<"$commits_json")"
  if [[ -n "$value" ]]; then printf '%s\t%s' "$value" first-commit; return; fi
  if [[ -n "$issue_created" && "$issue_created" != null ]]; then printf '%s\t%s' "$issue_created" issue-created; return; fi
  printf '%s\t%s' "$pr_created" pr-created
}

echo 'PR一覧を取得しています…' >&2
gh pr list --repo "$REPOSITORY" --state all --limit 10000 \
  --json number,state,title,url,body,createdAt,closedAt,mergedAt,mergedBy,headRefName,author,assignees,milestone > "$TEMP_DIR/all-pulls.json"
gh api --paginate --slurp "repos/${REPOSITORY}/issues?state=all&per_page=100" |
  jq 'add // [] | map(select(.pull_request == null))' > "$TEMP_DIR/all-issues.json"

multiple_prs="$(jq -r '.[] | select(([.assignees[]?.login] | unique | length) > 1) |
  "PR #\(.number) \(.url) — assignees: \([.assignees[]?.login] | unique | join(", "))"' "$TEMP_DIR/all-pulls.json")"
multiple_issues="$(jq -r '.[] | select(([.assignees[]?.login] | unique | length) > 1) |
  "Issue #\(.number) \(.html_url) — assignees: \([.assignees[]?.login] | unique | join(", "))"' "$TEMP_DIR/all-issues.json")"
if [[ -n "$multiple_prs" || -n "$multiple_issues" ]]; then
  echo 'エラー: 複数のassigneeが設定されたIssue・PRがあります。' >&2
  [[ -z "$multiple_issues" ]] || printf '%s\n' "$multiple_issues" >&2
  [[ -z "$multiple_prs" ]] || printf '%s\n' "$multiple_prs" >&2
  echo 'GitHub上で内容を一番よく理解している主担当のみをassigneeに残してください。' >&2
  echo "修正後に bash scripts/report/weekly-summary.sh --milestone ${MILESTONE} --student ${STUDENT} を再実行してください。既存のレポートは変更していません。" >&2
  exit 1
fi

missing_prs="$(jq -r '.[] | select(.milestone == null) | "PR #\(.number) \(.url)"' "$TEMP_DIR/all-pulls.json")"
missing_issues="$(jq -r '.[] | select(.milestone == null) | "Issue #\(.number) \(.html_url)"' "$TEMP_DIR/all-issues.json")"
if [[ -n "$missing_prs" || -n "$missing_issues" ]]; then
  echo 'エラー: Milestone未割当のIssue・PRがあります。' >&2
  [[ -z "$missing_issues" ]] || printf '%s\n' "$missing_issues" >&2
  [[ -z "$missing_prs" ]] || printf '%s\n' "$missing_prs" >&2
  echo "GitHubでMilestoneを設定し、bash scripts/report/weekly-summary.sh --milestone ${MILESTONE} --student ${STUDENT} を再実行してください。既存のレポートは変更していません。" >&2
  exit 1
fi

echo '対象学生のPR詳細を取得しています…' >&2
: > "$TEMP_DIR/target-prs.jsonl"
while IFS= read -r number; do
  rest="$(jq --argjson number "$number" '.[] | select(.number == $number)' "$TEMP_DIR/all-pulls.json")"
  body="$(jq -r '.body // ""' <<<"$rest")"
  if ! detail="$(gh pr view "$number" --repo "$REPOSITORY" --json number,title,url,body,createdAt,closedAt,mergedAt,mergedBy,headRefName,closingIssuesReferences 2>/dev/null)"; then
    echo "エラー: PR #${number} の詳細を取得できません。既存のレポートは変更せず終了します。" >&2
    exit 1
  fi
  if ! commits="$(gh api --paginate --slurp "repos/${REPOSITORY}/pulls/${number}/commits?per_page=100" | jq '[add[] | {sha, html_url, message: .commit.message, committedAt: .commit.committer.date, authoredAt: .commit.author.date}]')"; then
    echo "エラー: PR #${number} のコミットを取得できません。既存のレポートは変更せず終了します。" >&2
    exit 1
  fi
  jq -n --argjson detail "$detail" --argjson rest "$rest" --arg body "$body" --argjson commits "$commits" \
    '$detail + {body: $body, commits: $commits, author: $rest.author, assignees: ($rest.assignees // [])}' >> "$TEMP_DIR/target-prs.jsonl"
done < <(jq -r --arg student "$STUDENT" --arg milestone "$MILESTONE" '
  .[] | select(.milestone.title == $milestone) |
  select(.author.login == $student or
    (if (.assignees // [] | length) > 0 then any(.assignees[]; .login == $student) else false end)) | .number
' "$TEMP_DIR/all-pulls.json" | tr -d '\r')
jq -s '.' "$TEMP_DIR/target-prs.jsonl" > "$TEMP_DIR/target-prs.json"

# Issueの最後のCloseイベントに記録された閉鎖元PRを取得する。
REPOSITORY_OWNER="${REPOSITORY%%/*}"
REPOSITORY_NAME="${REPOSITORY#*/}"
CLOSER_QUERY='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){issue(number:$number){timelineItems(itemTypes:CLOSED_EVENT,last:100){nodes{... on ClosedEvent{closer{... on PullRequest{number}}}}}}}}'
: > "$TEMP_DIR/issue-closers.jsonl"
: > "$TEMP_DIR/pr-closed-issues.txt"
while IFS= read -r issue_number; do
  closing_event="$(gh api graphql -f query="$CLOSER_QUERY" -f owner="$REPOSITORY_OWNER" -f name="$REPOSITORY_NAME" -F number="$issue_number")"
  jq -e '(.errors == null) and (.data.repository.issue != null)' <<<"$closing_event" >/dev/null || {
    echo "エラー: Issue #${issue_number} のCloseイベントを取得できません。" >&2
    exit 1
  }
  closer_pr="$(jq -r '.data.repository.issue.timelineItems.nodes | last | .closer.number // empty' <<<"$closing_event")"
  [[ -n "$closer_pr" ]] || continue
  jq -n --argjson issueNumber "$issue_number" --argjson prNumber "$closer_pr" '{issueNumber:$issueNumber,prNumber:$prNumber}' >> "$TEMP_DIR/issue-closers.jsonl"
  printf '%s\n' "$issue_number" >> "$TEMP_DIR/pr-closed-issues.txt"
done < <(jq -r --arg milestone "$MILESTONE" '.[] | select(.milestone.title == $milestone and .closed_at != null) | .number' "$TEMP_DIR/all-issues.json" | tr -d '\r')
jq -s '.' "$TEMP_DIR/issue-closers.jsonl" > "$TEMP_DIR/issue-closers.json"

echo 'Issueごとの所要時間を算定しています…' >&2
: > "$TEMP_DIR/completed-issues.jsonl"
: > "$TEMP_DIR/closed-prs.jsonl"
: > "$TEMP_DIR/closed-prs-without-issue.jsonl"
while IFS= read -r pr_number; do
  pr="$(jq --argjson number "$pr_number" '.[] | select(.number == $number)' "$TEMP_DIR/target-prs.json")"
  if ! jq -e --arg student "$STUDENT" 'if (.assignees | length) > 0 then any(.assignees[]; .login == $student) else .author.login == $student end' <<<"$pr" >/dev/null; then
    continue
  fi
  closed_at="$(jq -r '.closedAt // empty' <<<"$pr")"
  [[ -n "$closed_at" ]] || continue
  branch="$(jq -r '.headRefName // empty' <<<"$pr")"
  commits="$(jq -c '.commits' <<<"$pr")"
  pr_created="$(jq -r '.createdAt' <<<"$pr")"
  merged_at="$(jq -r '.mergedAt // empty' <<<"$pr")"
  closed_issue_numbers="$(jq -c --argjson pr "$pr_number" '[.[] | select(.prNumber == $pr) | .issueNumber]' "$TEMP_DIR/issue-closers.json")"
  closing_count="$(jq 'length' <<<"$closed_issue_numbers")"
  issue_created_fallback=''
  first_issue_number="$(jq -r '.[0] // empty' <<<"$closed_issue_numbers")"
  if [[ -n "$first_issue_number" ]]; then
    if ! issue_created_fallback="$(gh issue view "$first_issue_number" --repo "$REPOSITORY" --json createdAt --jq .createdAt 2>/dev/null)"; then
      echo "エラー: Issue #${first_issue_number} の作成日時を取得できません。既存のレポートは変更せず終了します。" >&2
      exit 1
    fi
  fi
  IFS=$'\t' read -r pr_start pr_start_source <<< "$(choose_start "$branch" "$commits" "$issue_created_fallback" "$pr_created")"
  pr_end="${merged_at:-$closed_at}"
  pr_seconds="$(duration_seconds "$pr_start" "$pr_end" || printf '')"
  jq -n --argjson pr "$pr" --argjson closingIssueNumbers "$closed_issue_numbers" --arg start "$pr_start" --arg source "$pr_start_source" --arg end "$pr_end" --arg seconds "$pr_seconds" '
    {number:$pr.number,title:$pr.title,url:$pr.url,body:$pr.body,createdAt:$pr.createdAt,
     closedAt:$pr.closedAt,mergedAt:$pr.mergedAt,mergedBy:$pr.mergedBy,
     author:$pr.author.login,assignees:[$pr.assignees[]?.login],
     closingIssueNumbers:$closingIssueNumbers,startAt:$start,startSource:$source,
     endAt:$end,endSource:(if $pr.mergedAt != null then "pr-merged" else "pr-closed" end),
     durationSeconds:($seconds|tonumber?)}
  ' >> "$TEMP_DIR/closed-prs.jsonl"
  if [[ "$closing_count" -eq 0 ]]; then
    jq -n --argjson pr "$pr" --arg start "$pr_start" --arg end "$pr_end" --arg source "$pr_start_source" --arg seconds "$pr_seconds" '
      {number:$pr.number,title:$pr.title,url:$pr.url,createdAt:$pr.createdAt,closedAt:$end,mergedAt:$pr.mergedAt,
       startAt:$start,startSource:$source,endSource:(if $pr.mergedAt != null then "pr-merged" else "pr-closed" end),durationSeconds:($seconds|tonumber?)}
    ' >> "$TEMP_DIR/closed-prs-without-issue.jsonl"
    continue
  fi
  [[ -n "$merged_at" ]] || continue
  while IFS= read -r issue_number; do
    if ! issue="$(gh issue view "$issue_number" --repo "$REPOSITORY" --json number,title,url,body,createdAt,closedAt,assignees,milestone 2>/dev/null)"; then
      echo "エラー: Issue #${issue_number} の詳細を取得できません。既存のレポートは変更せず終了します。" >&2
      exit 1
    fi
    issue_created="$(jq -r '.createdAt // empty' <<<"$issue")"
    issue_closed="$(jq -r '.closedAt // empty' <<<"$issue")"
    [[ "$(jq -r '.milestone.title // empty' <<<"$issue")" == "$MILESTONE" ]] || continue
    [[ -n "$issue_closed" ]] || continue
    jq -e --argjson issue "$issue_number" --argjson pr "$pr_number" \
      'any(.[]; .issueNumber == $issue and .prNumber == $pr)' "$TEMP_DIR/issue-closers.json" >/dev/null || continue
    IFS=$'\t' read -r start start_source <<< "$(choose_start "$branch" "$commits" "$issue_created" "$pr_created")"
    end="$merged_at"; end_source=pr-merged
    seconds="$(duration_seconds "$start" "$end" || printf '')"
    jq -n --argjson issue "$issue" --argjson pr "$pr" --arg start "$start" --arg end "$end" --arg startSource "$start_source" --arg endSource "$end_source" --arg seconds "$seconds" '
      {number:$issue.number,title:$issue.title,url:$issue.url,body:$issue.body,assignees:[$issue.assignees[].login],
       pr:{number:$pr.number,title:$pr.title,url:$pr.url},startAt:$start,endAt:$end,startSource:$startSource,endSource:$endSource,durationSeconds:($seconds|tonumber?)}
    ' >> "$TEMP_DIR/completed-issues.jsonl"
  done < <(jq -r '.[]' <<<"$closed_issue_numbers" | tr -d '\r')
done < <(jq -r '.[].number' "$TEMP_DIR/target-prs.json" | tr -d '\r')
jq -s '.' "$TEMP_DIR/completed-issues.jsonl" > "$TEMP_DIR/completed-issues.json"
jq -s '.' "$TEMP_DIR/closed-prs.jsonl" > "$TEMP_DIR/closed-prs.json"
jq -s '.' "$TEMP_DIR/closed-prs-without-issue.jsonl" > "$TEMP_DIR/closed-prs-without-issue.json"

: > "$TEMP_DIR/manually-closed-issues.jsonl"
while IFS= read -r issue_number; do
  grep -qx "$issue_number" "$TEMP_DIR/pr-closed-issues.txt" && continue
  issue="$(jq --argjson number "$issue_number" '.[] | select(.number == $number)' "$TEMP_DIR/all-issues.json")"
  start="$(jq -r '.created_at' <<<"$issue")"; end="$(jq -r '.closed_at' <<<"$issue")"
  seconds="$(duration_seconds "$start" "$end" || printf '')"
  jq -n --argjson issue "$issue" --arg start "$start" --arg end "$end" --arg seconds "$seconds" '
    {number:$issue.number,title:$issue.title,url:$issue.html_url,body:($issue.body // ""),
     author:$issue.user.login,assignees:[$issue.assignees[]?.login],createdAt:$start,closedAt:$end,
     startAt:$start,endAt:$end,startSource:"issue-created",endSource:"issue-closed",durationSeconds:($seconds|tonumber?)}
  ' >> "$TEMP_DIR/manually-closed-issues.jsonl"
done < <(jq -r --arg student "$STUDENT" --arg milestone "$MILESTONE" '
  .[] | select(.closed_at != null and .milestone.title == $milestone) |
  select(.user.login == $student or ([.assignees[].login] | index($student))) | .number
' "$TEMP_DIR/all-issues.json" | tr -d '\r')
jq -s '.' "$TEMP_DIR/manually-closed-issues.jsonl" > "$TEMP_DIR/manually-closed-issues.json"

gh api --paginate --slurp "repos/${REPOSITORY}/issues/comments?per_page=100" | jq 'add // []' > "$TEMP_DIR/issue-comments.json"
gh api --paginate --slurp "repos/${REPOSITORY}/pulls/comments?per_page=100" | jq 'add // []' > "$TEMP_DIR/review-comments.json"
previous_ai='{}'
previous_dod='{}'
previous_issue_numbers='[]'
previous_pr_numbers='[]'
previous_created_pr_numbers='[]'
if [[ -f "$DATA_FILE" ]]; then
  previous_ai="$(jq -c 'if .schemaVersion == 4 then .aiUsage // {} else {} end' "$DATA_FILE")"
  previous_dod="$(jq -c 'if .schemaVersion == 4 then .dodAssessment // {} else {} end' "$DATA_FILE")"
  previous_issue_numbers="$(jq -c '[.dodIssues[]?.number] | sort' "$DATA_FILE")"
  previous_pr_numbers="$(jq -c '[.dodPullRequests[]?.number] | sort' "$DATA_FILE")"
  previous_created_pr_numbers="$(jq -c '[.dodCreatedPullRequests[]?.number] | sort' "$DATA_FILE")"
fi

jq -n \
  --arg generatedAt "$NOW" --arg student "$STUDENT" --arg milestone "$MILESTONE" --arg repository "$REPOSITORY" \
  --slurpfile completed "$TEMP_DIR/completed-issues.json" \
  --slurpfile closedPrs "$TEMP_DIR/closed-prs.json" \
  --slurpfile withoutIssue "$TEMP_DIR/closed-prs-without-issue.json" \
  --slurpfile manual "$TEMP_DIR/manually-closed-issues.json" \
  --slurpfile targetPrs "$TEMP_DIR/target-prs.json" \
  --slurpfile allPrs "$TEMP_DIR/all-pulls.json" \
  --slurpfile allIssues "$TEMP_DIR/all-issues.json" \
  --slurpfile issueComments "$TEMP_DIR/issue-comments.json" \
  --slurpfile reviewComments "$TEMP_DIR/review-comments.json" \
  --argjson aiUsage "$previous_ai" --argjson dodAssessment "$previous_dod" \
  --argjson previousIssues "$previous_issue_numbers" --argjson previousPrs "$previous_pr_numbers" --argjson previousCreatedPrs "$previous_created_pr_numbers" '
  def completed: $completed[0] | unique_by(.number); def closedPrs: $closedPrs[0];
  def withoutIssue: $withoutIssue[0]; def manual: $manual[0];
  def targetPrs: $targetPrs[0]; def allPrs: $allPrs[0]; def allIssues: $allIssues[0];
  def issueComments: $issueComments[0]; def reviewComments: $reviewComments[0];
  def milestonePrs: allPrs | map(select(.milestone.title == $milestone));
  def milestoneIssues: allIssues | map(select(.milestone.title == $milestone));
  def responsible: if (.assignees // [] | length) > 0 then any(.assignees[]; .login == $student) else .author.login == $student end;
  def referencedNumbers($pr):
    ([ $pr.closingIssueNumbers[]?,
       ($pr.body // "" | match("(?i)(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?|refs?|references?)\\s+(?:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+(?:\\s*(?:,|;|and|&)\\s*(?:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+)*"; "g") |
         .string | scan("(?:[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)?#[0-9]+") |
         select(startswith("#") or startswith($repository + "#")) | split("#")[1] | tonumber) ] | unique);
  def relatedIssues($pr): [referencedNumbers($pr)[] as $number |
    allIssues[] | select(.number == $number) |
    {number,title,url:.html_url,state,author:.user.login,assignees:[.assignees[]?.login],
     createdAt:.created_at,closedAt:.closed_at,milestone:(.milestone.title // null)}];
  {
    schemaVersion: 4, repository: $repository, generatedAt: $generatedAt, milestone: $milestone, student: $student,
    closedPullRequests: (closedPrs | map(. as $pr | . + {relatedIssues: relatedIssues($pr)})),
    completedIssues: completed, closedPrsWithoutIssue: withoutIssue, manuallyClosedIssues: manual,
    pullRequests: targetPrs,
    mergedByStudent: (milestonePrs | map(select(.mergedBy.login == $student) |
      . as $pr | {number,title,url,createdAt,closedAt,mergedAt,mergedBy:.mergedBy.login,
        assignees:[.assignees[]?.login],author:.author.login,relatedIssues:relatedIssues($pr)})),
    dodIssues: (milestoneIssues | map(select(any(.assignees[]?; .login == $student)) |
      {number,title,url:.html_url,createdAt:.created_at,closedAt:.closed_at})),
    dodPullRequests: (milestonePrs | map(select(responsible) |
      {number,title,url,createdAt,closedAt})),
    dodCreatedPullRequests: (targetPrs | map(select(.author.login == $student) | {number,title,url,createdAt,closedAt})),
    openPullRequests: (allPrs | map(select(.state == "OPEN") | . as $pr |
      {number,title,url,body,createdAt,author,assignees:[.assignees[]?.login],
       milestone:(.milestone.title // null),relatedIssues:relatedIssues($pr)})),
    openIssues: (allIssues | map(select(.state == "open") |
      {number,title,url:.html_url,body,createdAt:.created_at,author:.user,assignees:[.assignees[]?.login],milestone:(.milestone.title // null)})),
    commits: (targetPrs | map(select(.author.login == $student) | .commits) | add // [] | unique_by(.sha)),
    githubComments: ((issueComments + reviewComments) | map(select(.user.login == $student) |
      select((.issue_url // .pull_request_url // "") as $url |
        any(milestoneIssues[]; .number as $number | $url | endswith("/" + ($number | tostring))) or
        any(milestonePrs[]; .number as $number | $url | endswith("/" + ($number | tostring)))))),
    troubleshooting: [],
    aiUsage: ($aiUsage | with_entries(select(.key as $key | any(closedPrs[]; (.number | tostring) == $key)))), dodAssessment: $dodAssessment
  } |
  .dodAssessment = (if ([.dodIssues[].number] | sort) == $previousIssues and ([.dodPullRequests[].number] | sort) == $previousPrs and ([.dodCreatedPullRequests[].number] | sort) == $previousCreatedPrs then .dodAssessment else {} end) |
  .summary = {
    closedPrCount: (.closedPullRequests | length),
    mergedPrCount: (.closedPullRequests | map(select(.mergedAt != null)) | length),
    mergedByStudentCount: (.mergedByStudent | length),
    completedIssueCount: (.completedIssues | length), manuallyClosedIssueCount: (.manuallyClosedIssues | length),
    openPrCount: (.openPullRequests | length), openIssueCount: (.openIssues | length), commitCount: (.commits | length),
    githubCommentCount: (.githubComments | length), troubleshootingCount: (.troubleshooting | length)
  }
' > "$TEMP_DIR/report.json"
jq -e --arg milestone "$MILESTONE" '.schemaVersion == 4 and .milestone == $milestone' "$TEMP_DIR/report.json" >/dev/null
mkdir -p "$DATA_DIR"
if [[ -f "$DATA_FILE" ]]; then
  backup="${DATA_DIR}/${MILESTONE}.backup-${FILE_STAMP}.json.bak"
  suffix=2
  while [[ -e "$backup" ]]; do backup="${DATA_DIR}/${MILESTONE}.backup-${FILE_STAMP}-${suffix}.json.bak"; suffix=$((suffix + 1)); done
  cp -- "$DATA_FILE" "$backup"
  echo "バックアップ: $backup"
fi
mv -f -- "$TEMP_DIR/report.json" "$DATA_FILE"

REPORT_JSON="$(jq -c . "$DATA_FILE" | sed 's/</\\u003c/g')"
cat > "$REPORT_FILE" <<'EOF'
<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>週次開発レビュー</title>
<link rel="stylesheet" href="assets/vendor/bulma-1.0.4.min.css">
<style>
:root{--text:#f8fafc;--muted:#d7e0ee;--surface:#14213d;--surface-2:#1e3156;--accent:#7dd3fc;--danger:#ff8fa3}
body{background:linear-gradient(135deg,#071426,#102a4c 55%,#16142d);min-height:100vh;color:var(--text)}
.hero{background:linear-gradient(120deg,#0b1e38,#1c3d6b)}
.hero .title,.hero .subtitle,.section-title,.detail-card .title{color:var(--text)!important}
.summary-card,.detail-card{background:var(--surface);color:var(--text);border:1px solid #6385b6}
.summary-card .title,.summary-card .label,.detail-card .label,.detail-card legend{color:var(--text)!important}
.summary-card a,.detail-card a,.dod-item a{color:#a5e5ff;text-decoration:underline}
.meta,.footer-note{color:var(--muted)!important;font-size:.9rem}
.warning{border-left:4px solid var(--danger);background:#4b1f32;color:#fff7f8}
.warning a{color:#fff!important}
.summary-links{display:flex;flex-wrap:wrap;gap:.6rem;margin-top:1rem}
.summary-link{padding:.35rem .65rem;background:var(--surface-2);border-radius:.35rem}
.overview-metrics{display:grid;grid-template-columns:repeat(auto-fit,minmax(10rem,1fr));gap:.6rem;margin:.9rem 0}
.metric-card{display:flex;flex-direction:column;padding:.7rem;background:var(--surface-2);border-radius:.4rem}
.metric-card strong{font-size:1.6rem;color:var(--accent)}
#overview-text{max-height:28rem;overflow:auto;padding:1rem;background:#0d1b33;border:1px solid #6385b6;border-radius:.4rem;font-family:ui-monospace,monospace}
.overview-row{margin:.2rem 0;overflow-wrap:anywhere}
.overview-depth-1{margin-left:1.5rem}.overview-depth-2{margin-left:3rem}
.detail-card{margin-top:1rem}
.detail-card .title{margin-bottom:.45rem}
.list-item,.dod-item{border-top:1px solid #526b90;padding:1rem 0}
.detail-fields{display:grid;grid-template-columns:repeat(auto-fit,minmax(13rem,1fr));gap:.5rem 1rem;margin:.75rem 0}
.detail-fields dt{color:var(--muted);font-size:.8rem}.detail-fields dd{overflow-wrap:anywhere}
.related-items{margin:.75rem 0}.related-items h5{font-weight:700}
.related-record{margin:.5rem 0;padding:.75rem;background:var(--surface-2);border-radius:.35rem}
.description{white-space:pre-wrap;margin-top:.6rem;max-height:16rem;overflow:auto}
.ai-controls{padding:.8rem;margin-top:.8rem;border:1px solid #526b90;border-radius:.4rem}
.ai-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(16rem,1fr));gap:.5rem}
.ai-grid .checkbox{color:var(--text)}
.dod-options{display:grid;gap:.5rem}.dod-options .checkbox{color:var(--text)}
.other-label{margin-top:.75rem}
.save-status{min-height:1.2rem;color:#a5e5ff;font-size:.85rem}
details summary{cursor:pointer;color:var(--text)}
.github-preview[hidden]{display:none!important}
.github-preview{position:fixed;z-index:1000;width:min(32rem,calc(100vw - 1rem));max-height:min(25rem,calc(100vh - 1rem));overflow:auto;padding:1rem;background:#102544;color:var(--text);border:2px solid var(--accent);border-radius:.5rem;box-shadow:0 1rem 2.5rem #000a}
.github-preview h3,.github-preview h4{font-weight:700;margin:.4rem 0}.github-preview h3{font-size:1.1rem}.github-preview a{color:#a5e5ff;text-decoration:underline}
.preview-body{white-space:pre-wrap;overflow-wrap:anywhere;margin:.6rem 0}.preview-entry{border-top:1px solid #526b90;padding:.5rem 0}.preview-entry small{display:block;color:var(--muted)}
</style>
</head>
<body>
<section class="hero"><div class="hero-body"><div class="container"><h1 class="title">Weekly Engineering Review</h1><p class="subtitle" id="report-meta"></p></div></div></section>
<main class="section"><div class="container">
<section class="box summary-card"><label class="label" for="report-select">表示する記録</label><div class="select is-fullwidth"><select id="report-select">__REPORT_OPTIONS__</select></div></section>
<section class="box summary-card" id="overview"><h2 class="title is-3">全体概要</h2><div class="overview-metrics" id="overview-metrics"></div><p>概要をコピーすると、Googleスプレッドシートへ貼り付けられるタブ区切りテキストをコピーします。</p><div id="overview-text"></div><button class="button is-info" id="copy-button" type="button">概要をコピー</button><span id="copy-status" aria-live="polite"></span><div id="ai-warning" aria-live="polite"></div><div id="dod-warning" aria-live="polite"></div><nav class="summary-links" aria-label="入力欄へのリンク"><a class="summary-link" href="#closed-prs">PRごとのAI利用へ</a><a class="summary-link" href="#dod-form">DoD自己評価へ</a></nav></section>
<section class="box summary-card" id="dod-form"><h2 class="title is-3">DoD自己評価</h2><p>担当Issueは自分がAssigneeのものです。担当PRはAssigneeがいればその中に自分が含まれるもの、いなければ自分が作成したものです。各項目を選択すると表示中のJSONへ保存されます。</p><div id="dod-form-items"></div></section>
<div id="details"></div>
<div id="unfinished"></div>
<aside id="github-preview" class="github-preview" role="tooltip" hidden></aside>
<p class="footer-note">AI利用とDoDの回答は表示中のJSONへ保存されます。ページを閉じると、約30秒後にローカルサーバは終了します。</p>
</div></main>
<script>const report=
EOF
printf '%s' "$REPORT_JSON" >> "$REPORT_FILE"
printf ';/*WEEKLY_SUMMARY_DATA_END*/' >> "$REPORT_FILE"
cat "${SCRIPT_DIR}/weekly-summary-ui.js" >> "$REPORT_FILE"
printf '\n</script></body></html>\n' >> "$REPORT_FILE"
PORT="$((18000 + RANDOM % 1000))"
echo "作成しました: $DATA_FILE"
echo "表示します: $REPORT_FILE"
"$POWERSHELL_EXE" -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/server-weekly-summary.ps1" -HtmlPath "$(pwd -W)/${REPORT_FILE}" -DataPath "$(pwd -W)/${DATA_FILE}" -GhPath "$(cygpath -w "$(command -v gh)")" -Port "$PORT" >/dev/null 2>&1 &
sleep 1
"$POWERSHELL_EXE" -NoProfile -Command "Start-Process 'http://127.0.0.1:${PORT}/'" >/dev/null 2>&1 || true
