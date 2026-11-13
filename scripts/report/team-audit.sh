#!/usr/bin/env bash
set -euo pipefail

# 教員用の読み取り専用レポート。既存の週次レポートには依存しない。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

usage() {
  echo "使い方: bash scripts/report/team-audit.sh --milestone lec06 [--milestone lec07 ...] [--output 出力先.html]" >&2
}

MILESTONES=()
OUTPUT="docs/temp/team-audit.html"
while (($#)); do
  case "$1" in
    --milestone)
      (($# >= 2)) || { usage; exit 2; }
      [[ "$2" =~ ^lec(0[6-9]|1[0-4])$ ]] || { echo "不正なMilestone: $2" >&2; exit 2; }
      MILESTONES+=("$2")
      shift 2 ;;
    --output)
      (($# >= 2)) || { usage; exit 2; }
      OUTPUT="$2"
      shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
((${#MILESTONES[@]} > 0)) || { usage; exit 2; }
[[ "$OUTPUT" == *.html ]] || { echo '出力先は.htmlファイルを指定してください。' >&2; exit 2; }
for dependency in gh jq; do
  command -v "$dependency" >/dev/null 2>&1 || { echo "${dependency} が見つかりません。" >&2; exit 1; }
done
[[ -f "$SCRIPT_DIR/team-audit-ui.js" ]] || { echo 'team-audit-ui.js が見つかりません。' >&2; exit 1; }

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf -- "$TEMP_DIR"' EXIT
printf '%s\n' "${MILESTONES[@]}" | jq -R . | jq -s 'unique' > "$TEMP_DIR/milestones.json"
REPOSITORY="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
[[ "$REPOSITORY" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo 'リポジトリ名を取得できません。' >&2; exit 1; }
OWNER="$(gh api "repos/${REPOSITORY}" --jq .owner.login)"

echo 'Milestoneとメンバーを取得しています…' >&2
gh api --paginate --slurp "repos/${REPOSITORY}/milestones?state=all&per_page=100" | jq 'add // [] | map(.title)' > "$TEMP_DIR/available.json"
if ! jq -e --slurpfile available "$TEMP_DIR/available.json" 'all(.[]; . as $m | $available[0] | index($m) != null)' "$TEMP_DIR/milestones.json" >/dev/null; then
  echo '指定されたMilestoneがGitHub上にありません。' >&2
  exit 1
fi
gh api --paginate --slurp "repos/${REPOSITORY}/collaborators?affiliation=all&per_page=100" |
  jq --arg owner "$OWNER" '[add[]?.login, $owner] | unique' > "$TEMP_DIR/members.json"

echo 'IssueとPRを取得しています…' >&2
gh api --paginate --slurp "repos/${REPOSITORY}/issues?state=all&per_page=100" |
  jq 'add // [] | map(select(.pull_request == null))' > "$TEMP_DIR/all-issues.json"
gh api --paginate --slurp "repos/${REPOSITORY}/pulls?state=all&per_page=100" |
  jq 'add // []' > "$TEMP_DIR/all-prs.json"
jq -n --slurpfile milestones "$TEMP_DIR/milestones.json" --slurpfile items "$TEMP_DIR/all-issues.json" \
  '$items[0] | map(select(.milestone == null or (.milestone.title as $m | $milestones[0] | index($m) != null)))' > "$TEMP_DIR/issues.json"
jq -n --slurpfile milestones "$TEMP_DIR/milestones.json" --slurpfile items "$TEMP_DIR/all-prs.json" \
  '$items[0] | map(select(.milestone == null or (.milestone.title as $m | $milestones[0] | index($m) != null)))' > "$TEMP_DIR/prs.json"

echo '対象PRのレビューとマージ記録を取得しています…' >&2
: > "$TEMP_DIR/pr-details.jsonl"
while IFS= read -r number; do
  gh api --paginate --slurp "repos/${REPOSITORY}/pulls/${number}/reviews?per_page=100" |
    jq 'add // [] | map({user: .user.login, state, submitted_at, body, html_url})' > "$TEMP_DIR/reviews.json"
  gh api --paginate --slurp "repos/${REPOSITORY}/issues/${number}/comments?per_page=100" |
    jq 'add // [] | map({user: .user.login, created_at, body, html_url})' > "$TEMP_DIR/pr-comments.json"
  gh api --paginate --slurp "repos/${REPOSITORY}/pulls/${number}/comments?per_page=100" |
    jq 'add // [] | map({user: .user.login, created_at, body, html_url})' > "$TEMP_DIR/review-comments.json"
  gh api "repos/${REPOSITORY}/pulls/${number}/commits?per_page=1" |
    jq '.[0] // null | {sha, parents: [.parents[]?.sha]}' > "$TEMP_DIR/first-commit.json"
  MERGED_BY="$(gh pr view "$number" --repo "$REPOSITORY" --json mergedBy --jq '.mergedBy.login // empty')"
  jq -n --argjson number "$number" --arg mergedBy "$MERGED_BY" \
    --slurpfile prs "$TEMP_DIR/prs.json" --slurpfile reviews "$TEMP_DIR/reviews.json" \
    --slurpfile first "$TEMP_DIR/first-commit.json" --slurpfile comments "$TEMP_DIR/pr-comments.json" \
    --slurpfile reviewComments "$TEMP_DIR/review-comments.json" \
    '$prs[0][] | select(.number == $number) | . + {mergedBy: (if $mergedBy == "" then null else $mergedBy end), reviews: $reviews[0], comments: $comments[0], reviewComments: $reviewComments[0], firstCommit: $first[0]}' \
    >> "$TEMP_DIR/pr-details.jsonl"
done < <(jq -r '.[].number' "$TEMP_DIR/prs.json" | tr -d '\r')
jq -s '.' "$TEMP_DIR/pr-details.jsonl" > "$TEMP_DIR/pr-details.json"

echo 'Close済みIssueの閉鎖元を取得しています…' >&2
REPOSITORY_OWNER="${REPOSITORY%%/*}"
REPOSITORY_NAME="${REPOSITORY#*/}"
CLOSER_QUERY='query($owner:String!,$name:String!,$number:Int!){repository(owner:$owner,name:$name){issue(number:$number){timelineItems(itemTypes:CLOSED_EVENT,last:1){nodes{... on ClosedEvent{closer{... on PullRequest{number}}}}}}}}'
: > "$TEMP_DIR/issue-details.jsonl"
while IFS= read -r number; do
  issue="$(jq --argjson n "$number" '.[] | select(.number == $n)' "$TEMP_DIR/issues.json")"
  gh api --paginate --slurp "repos/${REPOSITORY}/issues/${number}/comments?per_page=100" |
    jq 'add // [] | map({user: .user.login, created_at, body, html_url})' > "$TEMP_DIR/issue-comments.json"
  closer='null'
  if [[ "$(jq -r '.closed_at // empty' <<<"$issue")" != '' ]]; then
    result="$(gh api graphql -f query="$CLOSER_QUERY" -f owner="$REPOSITORY_OWNER" -f name="$REPOSITORY_NAME" -F number="$number")"
    jq -e '.errors == null and .data.repository.issue != null' <<<"$result" >/dev/null || { echo "Issue #${number} のClose履歴を取得できません。" >&2; exit 1; }
    closer="$(jq '.data.repository.issue.timelineItems.nodes[-1].closer.number // null' <<<"$result")"
  fi
  jq -n --argjson item "$issue" --argjson closer "$closer" --slurpfile comments "$TEMP_DIR/issue-comments.json" \
    '$item + {closedByPr: $closer, comments: $comments[0]}' >> "$TEMP_DIR/issue-details.jsonl"
done < <(jq -r '.[].number' "$TEMP_DIR/issues.json" | tr -d '\r')
jq -s '.' "$TEMP_DIR/issue-details.jsonl" > "$TEMP_DIR/issue-details.json"

# 対象の作業が始まった日時以降のmain履歴を表示する。GitHubのPR関連付けも事前取得する。
SINCE="$(jq -r -s '[.[0][]?.created_at, .[1][]?.created_at] | map(select(. != null)) | min // empty' "$TEMP_DIR/issues.json" "$TEMP_DIR/prs.json")"
: > "$TEMP_DIR/main-commits.jsonl"
if [[ -n "$SINCE" ]]; then
  echo 'mainのコミット履歴を取得しています…' >&2
  gh api --paginate --slurp "repos/${REPOSITORY}/commits?sha=main&since=${SINCE}&per_page=100" | jq 'add // []' > "$TEMP_DIR/main-raw.json"
  while IFS= read -r sha; do
    gh api "repos/${REPOSITORY}/commits/${sha}/pulls?per_page=100" |
      jq '[.[] | {number, html_url, milestone: .milestone.title}]' > "$TEMP_DIR/associated-prs.json"
    jq -n --arg sha "$sha" --slurpfile commits "$TEMP_DIR/main-raw.json" --slurpfile associated "$TEMP_DIR/associated-prs.json" \
      '$commits[0][] | select(.sha == $sha) | {sha, html_url, message: .commit.message, author: (.author.login // .commit.author.name), date: .commit.committer.date, parentShas: [.parents[]?.sha], associatedPrs: $associated[0]}' \
      >> "$TEMP_DIR/main-commits.jsonl"
  done < <(jq -r '.[].sha' "$TEMP_DIR/main-raw.json" | tr -d '\r')
fi
jq -s '.' "$TEMP_DIR/main-commits.jsonl" > "$TEMP_DIR/main-commits.json"

GENERATED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
jq -n --arg repository "$REPOSITORY" --arg generatedAt "$GENERATED_AT" --arg since "$SINCE" \
  --slurpfile milestones "$TEMP_DIR/milestones.json" --slurpfile members "$TEMP_DIR/members.json" \
  --slurpfile issues "$TEMP_DIR/issue-details.json" --slurpfile prs "$TEMP_DIR/pr-details.json" \
  --slurpfile commits "$TEMP_DIR/main-commits.json" --slurpfile allIssues "$TEMP_DIR/all-issues.json" \
  '{repository:$repository, generatedAt:$generatedAt, historySince:$since, milestones:$milestones[0], members:$members[0], issues:$issues[0], prs:$prs[0], mainCommits:$commits[0], allIssueNumbers:[$allIssues[0][].number]}' \
  > "$TEMP_DIR/data.json"

mkdir -p "$(dirname "$OUTPUT")"
HTML_TEMP="$(mktemp "$(dirname "$OUTPUT")/.team-audit.XXXXXX")"
trap 'rm -rf -- "$TEMP_DIR"; rm -f -- "$HTML_TEMP"' EXIT
cat > "$HTML_TEMP" <<'HTML'
<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>チーム開発確認</title>
<style>
:root{font-family:system-ui,sans-serif;color:#172335;background:#f5f7fa}body{margin:0}header{background:#17365e;color:white;padding:1.4rem max(1rem,calc((100vw - 75rem)/2))}h1{margin:.1rem 0}.wrap{max-width:75rem;margin:auto;padding:1rem}section{background:white;border:1px solid #d8e0e8;border-radius:.5rem;padding:1rem;margin:1rem 0}h2{margin-top:0}label{font-weight:700}select{font:inherit;padding:.35rem;margin-left:.5rem}table{border-collapse:collapse;width:100%;font-size:.9rem}th,td{padding:.5rem;border-bottom:1px solid #d8e0e8;text-align:left;vertical-align:top}th{background:#e9f0f8;position:sticky;top:0}a{color:#075ca2}a:hover{text-decoration-thickness:2px}.scroll{overflow:auto;max-height:34rem}.muted{color:#526477}.body{white-space:pre-wrap;overflow-wrap:anywhere;max-height:19rem;overflow:auto;background:#f5f7fa;padding:.7rem}.row-detail{padding:.7rem;border-top:1px solid #d8e0e8}details{margin:.3rem 0}summary{cursor:pointer;font-weight:600}.preview{position:fixed;z-index:20;background:#10263f;color:white;border:2px solid #7dd3fc;border-radius:.5rem;padding:1rem;width:min(31rem,calc(100vw - 2rem));max-height:min(26rem,calc(100vh - 2rem));overflow:auto;box-shadow:0 1rem 2rem #0008}.preview[hidden]{display:none}.preview .body{background:#183958;color:white}.preview a{color:#a9e6ff}.chip{display:inline-block;background:#e9f0f8;border-radius:1rem;padding:.1rem .55rem;margin:.1rem} .empty{color:#526477}
</style></head><body><header><h1>チーム開発確認</h1><div id="meta"></div></header><main class="wrap">
<section><label for="filter">表示対象</label><select id="filter"></select><p class="muted">「すべて」は指定したMilestoneと未設定を各1件ずつ含みます。数値や記録を根拠に教員が確認してください。</p></section>
<section><h2>メンバー別件数</h2><div class="scroll" id="members"></div></section>
<section><h2>所要時間</h2><p class="muted">Issueは作成→Close、PRは作成→マージ（未マージでClose済みならClose）です。Openな項目は生成日時までの経過時間です。</p><div class="scroll" id="durations"></div></section>
<section><h2>Issue</h2><div class="scroll" id="issues"></div></section>
<section><h2>Pull Request</h2><div class="scroll" id="prs"></div></section>
<section><h2>mainのコミット履歴</h2><p class="muted" id="history-note"></p><div class="scroll" id="commits"></div></section>
<aside id="preview" class="preview" role="tooltip" hidden></aside>
</main><script id="audit-data" type="application/json">
HTML
jq -c . "$TEMP_DIR/data.json" | sed 's/</\\u003c/g' >> "$HTML_TEMP"
cat >> "$HTML_TEMP" <<'HTML'
</script><script>
HTML
cat "$SCRIPT_DIR/team-audit-ui.js" >> "$HTML_TEMP"
printf '\n</script></body></html>\n' >> "$HTML_TEMP"
mv -f -- "$HTML_TEMP" "$OUTPUT"
echo "作成しました: $OUTPUT"
