#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/markdown-format.sh"
source "${SCRIPT_DIR}/../lib/milestone.sh"

for command_name in gh jq; do
  command -v "$command_name" >/dev/null 2>&1 || { echo "エラー: ${command_name} が見つかりません。PortableGit Bashを起動し直してください。" >&2; exit 1; }
done

INPUT_FILE="${1:-docs/temp/issues.md}"
[[ -f "$INPUT_FILE" ]] || { echo "エラー: Issue草案ファイルがありません: $INPUT_FILE" >&2; exit 1; }

TEMP_DIR="$(mktemp -d)"
trap 'rm -r -- "$TEMP_DIR"' EXIT
declare -a IDS TITLES ASSIGNEES MILESTONES DEPENDS BODY_FILES NUMBERS ACTIONS
declare -A SEEN_IDS SEEN_TITLES NUMBER_BY_ID

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  printf '%s' "${value%"${value##*[![:space:]]}"}"
}

add_issue() {
  local body_file
  [[ -n "$CURRENT_ID" && -n "$CURRENT_TITLE" && -n "$CURRENT_BODY" ]] || {
    echo "エラー: id、title、本文を含む完全なISSUEブロックが必要です。" >&2; exit 1;
  }
  [[ "$CURRENT_ID" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "エラー: 不正なid: $CURRENT_ID" >&2; exit 1; }
  [[ -z "${SEEN_IDS[$CURRENT_ID]:-}" ]] || { echo "エラー: idが重複しています: $CURRENT_ID" >&2; exit 1; }
  [[ -z "${SEEN_TITLES[$CURRENT_TITLE]:-}" ]] || { echo "エラー: titleが重複しています: $CURRENT_TITLE" >&2; exit 1; }
  body_file="${TEMP_DIR}/${CURRENT_ID}.md"
  printf '%s\n' "$CURRENT_BODY" > "$body_file"
  validate_issue_body "$body_file"
  IDS+=("$CURRENT_ID"); TITLES+=("$CURRENT_TITLE"); ASSIGNEES+=("$CURRENT_ASSIGNEE"); MILESTONES+=("$CURRENT_MILESTONE")
  DEPENDS+=("$CURRENT_DEPENDS"); BODY_FILES+=("$body_file")
  SEEN_IDS[$CURRENT_ID]=1; SEEN_TITLES[$CURRENT_TITLE]=1
}

IN_METADATA=0; IN_BODY=0; CURRENT_ID=""; CURRENT_TITLE=""; CURRENT_ASSIGNEE=""; CURRENT_MILESTONE=""; CURRENT_DEPENDS=""; CURRENT_BODY=""
while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ "$line" == "<!-- ISSUE" ]]; then
    [[ "$IN_METADATA" == 0 && "$IN_BODY" == 0 ]] || { echo "エラー: ISSUEブロックが入れ子です。" >&2; exit 1; }
    IN_METADATA=1; CURRENT_ID=""; CURRENT_TITLE=""; CURRENT_ASSIGNEE=""; CURRENT_MILESTONE=""; CURRENT_DEPENDS=""; CURRENT_BODY=""
  elif [[ "$line" == "-->" && "$IN_METADATA" == 1 ]]; then
    IN_METADATA=0; IN_BODY=1
  elif [[ "$line" == "<!-- END ISSUE -->" && "$IN_BODY" == 1 ]]; then
    add_issue; IN_BODY=0
  elif [[ "$IN_METADATA" == 1 ]]; then
    case "$line" in
      id:*) CURRENT_ID="$(trim "${line#id:}")" ;;
      title:*) CURRENT_TITLE="$(trim "${line#title:}")" ;;
      assignee:*) CURRENT_ASSIGNEE="$(trim "${line#assignee:}")" ;;
      milestone:*) CURRENT_MILESTONE="$(trim "${line#milestone:}")" ;;
      depends-on:*) CURRENT_DEPENDS="$(trim "${line#depends-on:}")" ;;
      "") ;;
      *) echo "エラー: 不明なメタデータ行: $line" >&2; exit 1 ;;
    esac
  elif [[ "$IN_BODY" == 1 ]]; then
    CURRENT_BODY+="${line}"$'\n'
  fi
done < "$INPUT_FILE"
[[ "$IN_METADATA" == 0 && "$IN_BODY" == 0 && "${#IDS[@]}" -gt 0 ]] || { echo "エラー: ISSUEブロックの終了が不足しています。" >&2; exit 1; }

REPOSITORY="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
declare -A CHECKED_MILESTONES
for index in "${!IDS[@]}"; do
  milestone="${MILESTONES[$index]}"
  [[ -n "$milestone" ]] || { echo "エラー: ${IDS[$index]} のMilestoneが空欄です。lec06～lec14を入力して再実行してください。" >&2; exit 1; }
  if [[ -z "${CHECKED_MILESTONES[$milestone]:-}" ]]; then
    require_milestone "$milestone" "$REPOSITORY" || exit 1
    CHECKED_MILESTONES[$milestone]=1
  fi
done

for index in "${!IDS[@]}"; do
  for dependency_id in ${DEPENDS[$index]//,/ }; do
    [[ -z "$dependency_id" ]] && continue
    if [[ -n "${SEEN_IDS[$dependency_id]:-}" ]]; then
      continue
    fi
    [[ "$dependency_id" =~ ^[0-9]+$ ]] || {
      echo "エラー: ${IDS[$index]} のdepends-onは、この草案のidまたは既存Open Issue番号で指定してください: ${dependency_id}" >&2; exit 1;
    }
    dependency_state="$(gh issue view "$dependency_id" --json state --jq .state 2>/dev/null)" || {
      echo "エラー: ${IDS[$index]} が指定した依存Issue #${dependency_id} は存在しないか、参照できません。" >&2; exit 1;
    }
    [[ "$dependency_state" == "OPEN" ]] || {
      echo "エラー: ${IDS[$index]} が指定した依存Issue #${dependency_id} はOpenではありません（${dependency_state}）。" >&2; exit 1;
    }
    NUMBER_BY_ID[$dependency_id]="$dependency_id"
  done
  [[ -n "${ASSIGNEES[$index]}" ]] || {
    echo "エラー: ${IDS[$index]} の担当者（assignee）が未記入です。草案を修正して再実行してください。" >&2; exit 1;
  }
done

EXISTING="$(gh issue list --state all --limit 1000 --json number,title --jq '.[] | [.number, .title] | @tsv')"
for index in "${!IDS[@]}"; do
  found_number=""
  while IFS=$'\t' read -r number title; do
    [[ "$title" == "${TITLES[$index]}" ]] && { found_number="$number"; break; }
  done <<< "$EXISTING"
  if [[ -n "$found_number" ]]; then
    echo "エラー: タイトルが重複するIssueが既にあります: #${found_number} ${TITLES[$index]}。草案を修正して再実行してください。" >&2
    exit 1
  else
    ACTIONS[$index]="新規登録"; NUMBERS[$index]=""
  fi
done

echo "検査に成功しました。Issueを登録します。"

for index in "${!IDS[@]}"; do
  [[ "${ACTIONS[$index]}" == "新規登録" ]] || continue
  url="$(gh issue create --title "${TITLES[$index]}" --body-file "${BODY_FILES[$index]}" --assignee "${ASSIGNEES[$index]}" --milestone "${MILESTONES[$index]}")"
  number="${url##*/}"
  [[ "$number" =~ ^[0-9]+$ ]] || { echo "エラー: Issue番号を取得できませんでした: $url" >&2; exit 1; }
  NUMBERS[$index]="$number"; NUMBER_BY_ID[${IDS[$index]}]="$number"
  echo "作成: #$number ${TITLES[$index]}"
done

for index in "${!IDS[@]}"; do
  for dependency_id in ${DEPENDS[$index]//,/ }; do
    [[ -z "$dependency_id" ]] && continue
    issue_number="${NUMBER_BY_ID[${IDS[$index]}]}"; dependency_number="${NUMBER_BY_ID[$dependency_id]}"
    already_blocked="$(gh issue view "$issue_number" --json blockedBy --jq ".blockedBy[] | select(.number == ${dependency_number}) | .number" || true)"
    if [[ -z "$already_blocked" ]]; then
      gh issue edit "$issue_number" --add-blocked-by "$dependency_number" >/dev/null
      echo "依存関係を設定: #$issue_number は #$dependency_number に依存"
    fi
  done
done

echo "完了しました。次は bash scripts/issue/ready.sh を実行して、着手できるIssueを確認してください。"
