#!/usr/bin/env bash

# このファイルは scripts/harness/generate-template-harness.sh により生成される。

ISSUE_HEADINGS=( 機能の概要 AC（受け入れ基準） 関連ファイル・変更境界 実装計画 変更しないものとリスク )
ISSUE_REQUIRED=( 機能の概要 AC（受け入れ基準） )
PR_HEADINGS=( 関連Issue 変更内容 AC確認結果 テスト結果 )
PR_REQUIRED=( 関連Issue 変更内容 AC確認結果 テスト結果 )

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
