#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONSTRAINTS_FILE="${REPO_ROOT}/docs/template-constraints.md"

[[ -f "$CONSTRAINTS_FILE" ]] || { echo "エラー: 制約ファイルがありません: $CONSTRAINTS_FILE" >&2; exit 1; }

read_config() {
  local key="$1"
  sed -n "/^${key}=/s/^${key}=//p" "$CONSTRAINTS_FILE"
}

ISSUE_HEADINGS="$(read_config 'issue.headings')"
ISSUE_REQUIRED="$(read_config 'issue.required')"
PR_HEADINGS="$(read_config 'pr.headings')"
PR_REQUIRED="$(read_config 'pr.required')"
[[ -n "$ISSUE_HEADINGS" && -n "$ISSUE_REQUIRED" && -n "$PR_HEADINGS" && -n "$PR_REQUIRED" ]] || {
  echo 'エラー: HARNESS-CONFIG の4項目を設定してください。' >&2; exit 1;
}

IFS='|' read -r -a ISSUE_HEADING_ARRAY <<< "$ISSUE_HEADINGS"
IFS='|' read -r -a ISSUE_REQUIRED_ARRAY <<< "$ISSUE_REQUIRED"
IFS='|' read -r -a PR_HEADING_ARRAY <<< "$PR_HEADINGS"
IFS='|' read -r -a PR_REQUIRED_ARRAY <<< "$PR_REQUIRED"

contains() {
  local sought="$1"; shift
  local value
  for value in "$@"; do [[ "$value" == "$sought" ]] && return 0; done
  return 1
}

for heading in "${ISSUE_REQUIRED_ARRAY[@]}"; do contains "$heading" "${ISSUE_HEADING_ARRAY[@]}" || { echo "エラー: Issue必須項目が見出し一覧にありません: $heading" >&2; exit 1; }; done
for heading in "${PR_REQUIRED_ARRAY[@]}"; do contains "$heading" "${PR_HEADING_ARRAY[@]}" || { echo "エラー: PR必須項目が見出し一覧にありません: $heading" >&2; exit 1; }; done

mkdir -p "${REPO_ROOT}/scripts/lib" "${REPO_ROOT}/.github/ISSUE_TEMPLATE" "${REPO_ROOT}/.github/workflows"

{
  printf '%s\n' '#!/usr/bin/env bash' '' '# このファイルは scripts/harness/generate-template-harness.sh により生成される。' ''
  printf 'ISSUE_HEADINGS=('; printf ' %q' "${ISSUE_HEADING_ARRAY[@]}"; printf ' )\n'
  printf 'ISSUE_REQUIRED=('; printf ' %q' "${ISSUE_REQUIRED_ARRAY[@]}"; printf ' )\n'
  printf 'PR_HEADINGS=('; printf ' %q' "${PR_HEADING_ARRAY[@]}"; printf ' )\n'
  printf 'PR_REQUIRED=('; printf ' %q' "${PR_REQUIRED_ARRAY[@]}"; printf ' )\n\n'
  cat <<'EOF'
contains_heading() {
  local sought="$1"; shift
  local value
  for value in "$@"; do [[ "$value" == "$sought" ]] && return 0; done
  return 1
}

section_has_content() {
  local file="$1" heading="$2"
  awk -v heading="## ${heading}" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && $0 ~ /[^[:space:]]/ { found = 1 }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

validate_sections() {
  local file="$1" headings_name="$2" required_name="$3"
  local -n headings="$headings_name" required="$required_name"
  local heading count
  for heading in "${headings[@]}"; do
    count="$(awk -v heading="## ${heading}" '$0 == heading { count++ } END { print count + 0 }' "$file")"
    [[ "$count" -eq 1 ]] || { echo "エラー: 見出し『## ${heading}』は本文内に1回だけ必要です（現在: ${count}回）。" >&2; return 1; }
    if contains_heading "$heading" "${required[@]}"; then
      section_has_content "$file" "$heading" || { echo "エラー: 必須項目『## ${heading}』の本文を記入してください。" >&2; return 1; }
    fi
  done
}

validate_issue_body() { validate_sections "$1" ISSUE_HEADINGS ISSUE_REQUIRED; }
validate_pr_body() { validate_sections "$1" PR_HEADINGS PR_REQUIRED; }
EOF
} > "${REPO_ROOT}/scripts/lib/markdown-format.sh"

issue_description() {
  case "$1" in
    '機能の概要') printf 'できるようになること、今回しないこと、固有の語の意味を記述する。' ;;
    'AC（受け入れ基準）') printf 'Givenは人がどの画面でどの状態かを文で、Whenは人と具体的な操作、Thenは確認場所と結果を書く。' ;;
    '関連ファイル・変更境界') printf '変更予定のファイルと、変更してはいけない範囲を記述する。' ;;
    '実装計画') printf '変更予定ファイルと実装順序を記述する。' ;;
    '変更しないものとリスク') printf '変更範囲に含めないものと、注意すべきリスクを記述する。' ;;
  esac
}

{
  printf '%s\n' 'name: 新機能' 'description: 1人が短いPRで実装する利用者価値' 'title: "[Feature] "' 'body:'
  index=0
  for heading in "${ISSUE_HEADING_ARRAY[@]}"; do
    index=$((index + 1))
    printf '%s\n' '  - type: textarea' "    id: field-${index}" '    attributes:' "      label: ${heading}" "      description: $(issue_description "$heading")"
    if contains "$heading" "${ISSUE_REQUIRED_ARRAY[@]}"; then printf '%s\n' '    validations:' '      required: true'; fi
  done
  printf '%s\n' '  - type: input' '    id: dependencies' '    attributes:' '      label: 依存するIssue' '      description: "例: #12。OpenなIssue番号だけを記載する。草案から登録する場合はスクリプトが検査する。"'
  printf '%s\n' '  - type: dropdown' '    id: milestone' '    attributes:' '      label: Milestone' '      description: "選択後、GitHubのMilestone欄にも同じ値を設定する。"' '      options:'
  for number in {06..14}; do printf '        - lec%s\n' "$number"; done
  printf '%s\n' '    validations:' '      required: true'
} > "${REPO_ROOT}/.github/ISSUE_TEMPLATE/feature.yml"

{
  for heading in "${PR_HEADING_ARRAY[@]}"; do
    printf '## %s\n\n' "$heading"
  done
} > "${REPO_ROOT}/.github/pull_request_template.md"

cat > "${REPO_ROOT}/.github/workflows/validate-pr-body.yml" <<'EOF'
name: Validate pull request body

on:
  pull_request_target:
    types: [opened, edited, reopened, synchronize]

permissions:
  contents: read
  issues: read
  pull-requests: read

jobs:
  validate-pr-body:
    runs-on: ubuntu-latest
    steps:
      # PR側で検査を無効化できないよう、常にmainの検査スクリプトを使う。
      # PRのコードはcheckout・実行しない。
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.repository.default_branch }}
      - name: PR本文の必須項目を検査する
        env:
          GH_TOKEN: ${{ github.token }}
          PR_BODY: ${{ github.event.pull_request.body }}
        run: printf '%s' "$PR_BODY" | bash scripts/pr/validate-body.sh --stdin --check-related-issues
EOF

echo 'テンプレート・検査ライブラリ・PR本文検査Actionを生成しました。'
