#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "$REPO_ROOT"

[[ -x /usr/local/bin/jq.exe ]] && export PATH="/usr/local/bin:${PATH}"

for command_name in gh git cygpath; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "エラー: ${command_name} が見つかりません。" >&2
    exit 1
  }
done

POWERSHELL_EXE="$(command -v powershell.exe || true)"
if [[ -z "$POWERSHELL_EXE" ]]; then
  for candidate in /c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe /c/Windows/SysWOW64/WindowsPowerShell/v1.0/powershell.exe; do
    [[ -x "$candidate" ]] || continue
    POWERSHELL_EXE="$candidate"
    break
  done
fi
[[ -n "$POWERSHELL_EXE" ]] || { echo 'エラー: Windows PowerShellが見つかりません。' >&2; exit 1; }

LOGIN="$(gh api user --jq .login)"
STUDENT="$LOGIN"
STUDENT_SPECIFIED=false
if [[ "${1:-}" == "--student" ]]; then
  [[ "$#" -ge 2 ]] || { echo 'エラー: --student にはGitHub名が必要です。' >&2; exit 2; }
  STUDENT="$2"
  STUDENT_SPECIFIED=true
  shift 2
fi
[[ "$STUDENT" =~ ^[A-Za-z0-9][A-Za-z0-9-]{0,38}$ ]] || { echo 'エラー: 学生のGitHub名が不正です。' >&2; exit 2; }
[[ "$#" -le 1 ]] || { echo "使い方: $0 [--student GitHub名] [JSONファイル]" >&2; exit 2; }
DATA_FILE="${1:-}"
if [[ "$DATA_FILE" =~ ^docs/weekly-summary-data/([A-Za-z0-9-]+)/[^/]+\.json$ ]]; then
  FILE_STUDENT="${BASH_REMATCH[1]}"
  if [[ "$STUDENT_SPECIFIED" == true && "$STUDENT" != "$FILE_STUDENT" ]]; then
    echo 'エラー: --student とJSONファイルの学生が一致しません。' >&2
    exit 2
  fi
  STUDENT="$FILE_STUDENT"
fi
REPORT_FILE="docs/weekly-summary_${STUDENT}.html"
DATA_DIR="docs/weekly-summary-data/${STUDENT}"

if [[ -z "$DATA_FILE" ]]; then
  latest="$(find "$DATA_DIR" -maxdepth 1 -type f -name 'lec*.json' -printf '%T@ %f\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2- || true)"
  [[ -n "$latest" ]] || { echo 'エラー: 表示できる週次JSONがありません。先に weekly-summary.sh を実行してください。' >&2; exit 1; }
  DATA_FILE="${DATA_DIR}/${latest}"
fi
[[ -f "$DATA_FILE" ]] || { echo "エラー: JSONが見つかりません: ${DATA_FILE}" >&2; exit 1; }
[[ -f "$REPORT_FILE" ]] || { echo "エラー: HTMLが見つかりません。先に weekly-summary.sh を実行してください。" >&2; exit 1; }

PORT="$((18000 + RANDOM % 1000))"
"$POWERSHELL_EXE" -NoProfile -ExecutionPolicy Bypass -File "${SCRIPT_DIR}/server-weekly-summary.ps1" -HtmlPath "$(pwd -W)/${REPORT_FILE}" -DataPath "$(pwd -W)/${DATA_FILE}" -GhPath "$(cygpath -w "$(command -v gh)")" -Port "$PORT" >/dev/null 2>&1 &
sleep 1
echo "表示するJSON: ${DATA_FILE}"
echo "URL: http://127.0.0.1:${PORT}/"
"$POWERSHELL_EXE" -NoProfile -Command "Start-Process 'http://127.0.0.1:${PORT}/'" >/dev/null 2>&1 || true
