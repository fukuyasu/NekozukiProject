#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/milestone.sh"

for command_name in git gh jq; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "エラー: ${command_name} が見つかりません。PortableGit Bashを起動し直してください。" >&2
    exit 1
  }
done

BRANCH="$(git branch --show-current)"
[[ "$BRANCH" != "main" && -n "$BRANCH" ]] || { echo "エラー: mainからはPRを作成できません。" >&2; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "エラー: 先に変更をcommitしてください。" >&2; exit 1; }

if [[ "$BRANCH" =~ ^feat/issue-([0-9]+)- ]]; then
  ISSUE_NUMBER="${BASH_REMATCH[1]}"
else
  echo "エラー: ブランチ名からIssue番号を取得できません。feat/issue-<番号>-<名前> 形式のブランチで再実行してください。" >&2
  exit 1
fi
ISSUE_TITLE="$(gh issue view "$ISSUE_NUMBER" --json title --jq .title)"
ISSUE_MILESTONE="$(gh issue view "$ISSUE_NUMBER" --json milestone --jq '.milestone.title // empty')"
MILESTONE="${1:-}"
[[ "$#" -le 1 ]] || { echo "使い方: $0 lec06～lec14" >&2; exit 2; }
[[ -n "$MILESTONE" ]] || { echo 'エラー: Milestoneが空欄です。lec06～lec14を入力して再実行してください。' >&2; exit 1; }
[[ -n "$ISSUE_MILESTONE" ]] || { echo "エラー: 関連Issue #${ISSUE_NUMBER} にMilestoneがありません。GitHubで設定してから再実行してください。" >&2; exit 1; }
[[ "$MILESTONE" == "$ISSUE_MILESTONE" ]] || { echo "エラー: PRのMilestoneは関連Issue #${ISSUE_NUMBER} と同じ '${ISSUE_MILESTONE}' にしてください。" >&2; exit 1; }
REPOSITORY="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
require_milestone "$MILESTONE" "$REPOSITORY" || exit 1
DEFAULT_BODY="docs/temp/pr-${ISSUE_NUMBER}.md"
BODY_FILE="$DEFAULT_BODY"
[[ -f "$BODY_FILE" ]] || { echo "エラー: PR本文ファイルがありません: $BODY_FILE" >&2; exit 1; }
"${SCRIPT_DIR}/validate-body.sh" "$BODY_FILE" --check-related-issues
mapfile -t RELATED_NUMBERS < <(awk '
  $0 == "## 関連Issue" { in_section = 1; next }
  in_section && /^## / { exit }
  in_section { print }
' "$BODY_FILE" | grep -Eo '#[0-9]+' | tr -d '#' | sort -nu)
for number in "${RELATED_NUMBERS[@]}"; do
  related_milestone="$(gh issue view "$number" --json milestone --jq '.milestone.title // empty')"
  [[ "$related_milestone" == "$MILESTONE" ]] || {
    echo "エラー: 関連Issue #${number} のMilestone '${related_milestone}' とPRのMilestone '${MILESTONE}' が一致しません。" >&2
    exit 1
  }
done
find_open_pr() {
  gh api "repos/${REPOSITORY}/pulls?state=open&head=${REPOSITORY%%/*}:${BRANCH}&base=main&per_page=100" \
    --jq '.[0].number // empty'
}

ensure_pr_milestone() {
  local number="$1" url="$2" current milestone_number attempt
  for attempt in 1 2 3; do
    if current="$(gh api "repos/${REPOSITORY}/issues/${number}" --jq '.milestone.title // empty')"; then
      if [[ "$current" == "$MILESTONE" ]]; then
        echo "PR #${number} のMilestoneを確認しました: ${MILESTONE}"
        return 0
      fi
    else
      echo "警告: PR #${number} のMilestoneを取得できませんでした（${attempt}/3）。" >&2
    fi

    if [[ -z "${milestone_number:-}" ]]; then
      if ! milestone_number="$(gh api --paginate --slurp "repos/${REPOSITORY}/milestones?state=all&per_page=100" |
        jq -er --arg title "$MILESTONE" 'add // [] | map(select(.title == $title)) | .[0].number')"; then
        echo "エラー: Milestone '${MILESTONE}' の番号を取得できません。PRは作成済みの可能性があります: ${url}" >&2
        return 1
      fi
    fi
    if ! gh api -X PATCH "repos/${REPOSITORY}/issues/${number}" -F "milestone=${milestone_number}" >/dev/null; then
      echo "警告: PR #${number} へのMilestone設定に失敗しました（${attempt}/3）。" >&2
    fi
    [[ "$attempt" -eq 3 ]] || sleep 2
  done
  if current="$(gh api "repos/${REPOSITORY}/issues/${number}" --jq '.milestone.title // empty')" && [[ "$current" == "$MILESTONE" ]]; then
    echo "PR #${number} のMilestoneを確認しました: ${MILESTONE}"
    return 0
  fi
  echo "エラー: PR #${number} のMilestone '${MILESTONE}' を確認できませんでした: ${url}" >&2
  echo "GitHubのPR画面でMilestoneを確認するか、gh pr edit ${number} --repo ${REPOSITORY} --milestone ${MILESTONE} を実行してください。" >&2
  return 1
}

if ! EXISTING_PR="$(find_open_pr)"; then
  echo 'エラー: 既存のPRを確認できません。PRを新規作成せず終了します。' >&2
  exit 1
fi
if [[ -n "$EXISTING_PR" ]]; then
  echo "このブランチのOpen Pull Request #${EXISTING_PR} を確認しました。Milestoneを検査します。"
  ensure_pr_milestone "$EXISTING_PR" "https://github.com/${REPOSITORY}/pull/${EXISTING_PR}" || exit 1
  echo '次は /review-pr Promptを起動して、作成したPRのレビューを始めてください。'
  exit 0
fi

echo "--- 作成するPR ---"
echo "ブランチ: $BRANCH"
echo "関連Issue: #$ISSUE_NUMBER"
echo "Milestone: $MILESTONE"
echo "題名: $ISSUE_TITLE"
echo "本文ファイル: $BODY_FILE"
git push -u origin "$BRANCH"
CREATE_STATUS=0
CREATE_OUTPUT="$(gh pr create --base main --head "$BRANCH" --title "$ISSUE_TITLE" --body-file "$BODY_FILE" --milestone "$MILESTONE")" || CREATE_STATUS=$?
[[ -z "$CREATE_OUTPUT" ]] || printf '%s\n' "$CREATE_OUTPUT"
PR_NUMBER=''
PR_URL=''
while IFS= read -r line; do
  if [[ "$line" =~ ^https?://[^/]+/[^/]+/[^/]+/pull/([0-9]+)/?$ ]]; then
    PR_NUMBER="${BASH_REMATCH[1]}"
    PR_URL="$line"
  fi
done <<< "$CREATE_OUTPUT"
if [[ -z "$PR_NUMBER" ]]; then
  if ! PR_NUMBER="$(find_open_pr)"; then
    echo 'エラー: PR作成後の状態を確認できません。再実行する前にGitHub上でこのブランチのPRを確認してください。' >&2
    exit 1
  fi
  if [[ -z "$PR_NUMBER" ]]; then
    echo 'エラー: PRの作成を確認できません。再実行する前にGitHub上でこのブランチのPRを確認してください。' >&2
    exit 1
  fi
  PR_URL="https://github.com/${REPOSITORY}/pull/${PR_NUMBER}"
  echo "作成済みのPRを検出しました: ${PR_URL}"
fi
if [[ "$CREATE_STATUS" -ne 0 ]]; then
  echo "警告: gh pr create の後処理が失敗しました。作成済みのPR #${PR_NUMBER} を確認して復旧します。" >&2
fi
ensure_pr_milestone "$PR_NUMBER" "$PR_URL" || exit 1
echo "次は /review-pr Promptを起動して、作成したPRのレビューを始めてください。"
