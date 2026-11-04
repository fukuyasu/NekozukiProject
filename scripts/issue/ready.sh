#!/usr/bin/env bash
set -euo pipefail

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "エラー: $1 が見つかりません。PortableGit Bashを起動し直してください。" >&2
    exit 1
  }
}

for command_name in git gh; do require_command "$command_name"; done

is_executable() {
  local number="$1" state_json blockers_json state blockers
  # GitHub CLIの版によっては --json <項目> に対する --jq の入力が
  # オブジェクトではなく配列になる。そのため--jqを使わず、生のJSONを調べる。
  state_json="$(gh issue view "$number" --json state)"
  if printf '%s\n' "$state_json" | grep -Eq '"state"[[:space:]]*:[[:space:]]*"OPEN"|"OPEN"'; then
    state="OPEN"
  else
    state="OTHER"
  fi
  blockers_json="$(gh issue view "$number" --json blockedBy)"
  blockers="$(printf '%s\n' "$blockers_json" | grep -Eo '"state"[[:space:]]*:[[:space:]]*"(OPEN|CLOSED)"' | grep -vc '"CLOSED"' || true)"
  [[ "$state" == "OPEN" && "$blockers" == "0" ]]
}

git diff --quiet && git diff --cached --quiet || {
  echo "停止: 未コミットの変更があります。先に変更を確認してcommitしてください。" >&2
  git status --short
  exit 1
}

echo "--- 着手可能なIssue（OpenかつOpenの依存Issueなし） ---"
candidate_count=0
while IFS=$'\t' read -r number title assignees; do
  if is_executable "$number"; then
    echo "#$number  $title  担当: ${assignees:-未割当}"
    candidate_count=$((candidate_count + 1))
  fi
done < <(gh issue list --state open --limit 1000 --json number,title,assignees --jq '.[] | [.number, .title, ([.assignees[].login] | join(","))] | @tsv')

[[ "$candidate_count" -gt 0 ]] || { echo "着手可能なIssueはありません。"; exit 0; }
read -r -p "開始するIssue番号を # なしで入力してください: " ISSUE_NUMBER
[[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]] || { echo "停止: Issue番号は数字で入力してください。" >&2; exit 1; }
is_executable "$ISSUE_NUMBER" || { echo "停止: Issue #$ISSUE_NUMBER は着手可能ではありません。" >&2; exit 1; }

CURRENT_USER="$(gh api user --jq .login)"
ASSIGNEES="$(gh issue view "$ISSUE_NUMBER" --json assignees --jq '[.assignees[].login] | join(",")')"
if [[ ",$ASSIGNEES," != *",$CURRENT_USER,"* ]]; then
  echo "停止: Issue #$ISSUE_NUMBER の担当者は ${ASSIGNEES:-未割当} です。GitHub上で担当者を確認・変更してから再実行してください。" >&2
  exit 1
fi

read -r -p "ブランチ名の末尾を英小文字・数字・ハイフンで入力してください（例: game-page）: " BRANCH_SUFFIX
[[ "$BRANCH_SUFFIX" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "停止: 不正なブランチ名です。" >&2; exit 1; }
BRANCH_NAME="feat/issue-${ISSUE_NUMBER}-${BRANCH_SUFFIX}"
git show-ref --verify --quiet "refs/heads/$BRANCH_NAME" && { echo "停止: ブランチ $BRANCH_NAME は既に存在します。" >&2; exit 1; }

echo "--- 実行内容の確認 ---"
echo "Issue: #$ISSUE_NUMBER"
echo "担当者: $CURRENT_USER"
echo "作成するブランチ: $BRANCH_NAME"
echo "起点: origin/main"
read -r -p "origin/main を取得してブランチを作成しますか? [y/N] " CONFIRM
[[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]] || { echo "中止しました。"; exit 0; }

git fetch origin main
git switch -c "$BRANCH_NAME" origin/main

echo "--- 実施内容 ---"
echo "実行済み: git fetch origin main"
echo "実行済み: git switch -c $BRANCH_NAME origin/main"
echo "現在のブランチ: $(git branch --show-current)"
echo "現在のcommit: $(git log -1 --oneline)"
