#!/usr/bin/env bash

valid_milestone() { [[ "$1" =~ ^lec(0[6-9]|1[0-4])$ ]]; }

require_milestone() {
  local milestone="$1" repository="$2"
  [[ -n "$milestone" ]] || { echo 'エラー: Milestoneが空欄です。lec06～lec14を入力して再実行してください。' >&2; return 1; }
  valid_milestone "$milestone" || { echo "エラー: Milestoneはlec06～lec14から指定してください: $milestone" >&2; return 1; }
  gh api --paginate --slurp "repos/${repository}/milestones?state=all&per_page=100" |
    jq -e --arg title "$milestone" 'add // [] | any(.[]; .title == $title)' >/dev/null || {
      echo "エラー: Milestone '${milestone}' はGitHub上に存在しません。作成してから再実行してください。" >&2
      return 1
    }
}
