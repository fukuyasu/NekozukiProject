#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/milestone.sh"

ISSUE_NUMBER="${1:-}"
[[ "$#" -eq 1 && "$ISSUE_NUMBER" =~ ^[1-9][0-9]*$ ]] || {
  echo "使い方: $0 Issue番号" >&2
  exit 2
}
command -v gh >/dev/null 2>&1 || { echo 'エラー: gh が見つかりません。' >&2; exit 1; }
REPOSITORY="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
if ! MILESTONE="$(gh api "repos/${REPOSITORY}/issues/${ISSUE_NUMBER}" --jq '.milestone.title // empty')"; then
  echo "エラー: Issue #${ISSUE_NUMBER} のMilestoneを取得できません。" >&2
  exit 1
fi
if ! valid_milestone "$MILESTONE"; then
  echo "::error::Issue #${ISSUE_NUMBER} にGitHub上のMilestone lec06～lec14を設定してください。Issue Formの選択欄だけでは設定されません。" >&2
  exit 1
fi
echo "Issue #${ISSUE_NUMBER} のMilestoneを確認しました: ${MILESTONE}"
