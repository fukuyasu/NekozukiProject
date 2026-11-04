#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/markdown-format.sh"

TEMP_FILE=""
CHECK_RELATED_ISSUES=false
trap '[[ -z "$TEMP_FILE" ]] || rm -f -- "$TEMP_FILE"' EXIT

contains_number() {
  local sought="$1"; shift
  local value
  for value in "$@"; do [[ "$value" == "$sought" ]] && return 0; done
  return 1
}

if [[ "${1:-}" == "--stdin" ]]; then
  TEMP_FILE="$(mktemp)"
  cat > "$TEMP_FILE"
  BODY_FILE="$TEMP_FILE"
  shift
else
  BODY_FILE="${1:-}"
  [[ -n "$BODY_FILE" && -f "$BODY_FILE" ]] || {
    echo "使い方: $0 PR本文ファイル" >&2
    exit 2
  }
  shift
fi

if [[ "${1:-}" == "--check-related-issues" ]]; then
  CHECK_RELATED_ISSUES=true
  shift
fi
[[ "$#" -eq 0 ]] || { echo "使い方: $0 [--stdin] [--check-related-issues]" >&2; exit 2; }

if [[ "$CHECK_RELATED_ISSUES" == true ]]; then
  command -v gh >/dev/null 2>&1 || {
    echo "エラー: 関連Issueを検査するには gh が必要です。PortableGit Bashを起動し直してください。" >&2
    exit 1
  }
fi

validate_pr_body "$BODY_FILE"

if [[ "$CHECK_RELATED_ISSUES" == true ]]; then
  RELATED_SECTION="$(awk '
    $0 == "## 関連Issue" { in_section = 1; next }
    in_section && /^## / { exit }
    in_section { print }
  ' "$BODY_FILE")"

  if printf '%s\n' "$RELATED_SECTION" | grep -Eiq '(^|[^[:alnum:]])(fixes|resolves)[[:space:]]+#[0-9]+'; then
    echo "エラー: Issueを完了させる表記は『Closes #番号』だけを使ってください。" >&2
    exit 1
  fi

  mapfile -t RELATED_NUMBERS < <(printf '%s\n' "$RELATED_SECTION" | grep -Eo '#[0-9]+' | tr -d '#' | sort -nu || true)
  [[ "${#RELATED_NUMBERS[@]}" -gt 0 ]] || {
    echo "エラー: 『## 関連Issue』には実在するIssue番号を #12 の形式で少なくとも1件書いてください。" >&2
    exit 1
  }
  mapfile -t CLOSING_NUMBERS < <(printf '%s\n' "$RELATED_SECTION" | grep -Eio '(^|[^[:alnum:]])closes[[:space:]]+#[0-9]+' | grep -Eo '[0-9]+' | sort -nu || true)

  REPOSITORY="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
  for number in "${RELATED_NUMBERS[@]}"; do
    state="$(gh api "repos/${REPOSITORY}/issues/${number}" --jq .state 2>/dev/null)" || {
      echo "エラー: 関連Issue #${number} はこのリポジトリに存在しないか、参照できません。" >&2
      exit 1
    }
    pull_request_url="$(gh api "repos/${REPOSITORY}/issues/${number}" --jq '.pull_request.url // empty' 2>/dev/null)"
    [[ -z "$pull_request_url" ]] || {
      echo "エラー: #${number} はIssueではなくPull Requestです。関連Issueには指定できません。" >&2
      exit 1
    }
    if contains_number "$number" "${CLOSING_NUMBERS[@]}" && [[ "$state" != "open" ]]; then
      echo "エラー: Closes #${number} のIssueはOpenである必要があります（現在: ${state}）。" >&2
      exit 1
    fi
  done
fi

echo "PR本文の形式検査に成功しました。"
