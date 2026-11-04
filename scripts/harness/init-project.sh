#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${REPO_ROOT}/scripts/lib/project-config.sh"

MODE="${1:---check}"
[[ "$MODE" == "--check" || "$MODE" == "--initialize" ]] || {
  echo "使い方: $0 [--check|--initialize]" >&2
  exit 2
}

failures=0
warnings=0
app_dir=""
build_file=""
repository_name=""
application_name=""
repository_slug=""
github_ready=0
declare -a collaborators=()

pass() { printf 'OK: %s\n' "$1"; }
fail() { printf 'NG: %s\n' "$1" >&2; failures=$((failures + 1)); }
warn() { printf '要確認: %s\n' "$1" >&2; warnings=$((warnings + 1)); }

check_name_and_remote() {
  local local_name remote remote_name remote_alias candidate
  local_name="$(basename "$REPO_ROOT")"
  remote=""
  while IFS= read -r remote_alias; do
    candidate="$(git -C "$REPO_ROOT" remote get-url "$remote_alias" 2>/dev/null || true)"
    if [[ "$candidate" =~ ^git@[^:]+:.+\.git$ ]]; then
      remote="$candidate"
      break
    fi
  done < <(git -C "$REPO_ROOT" remote 2>/dev/null || true)
  if [[ ! "$remote" =~ ^git@[^:]+:.+\.git$ ]]; then
    fail "SSH remote（git@ホスト:owner/repository.git）が必要です。"
    return
  fi
  remote_name="${remote##*:}"
  remote_name="${remote_name##*/}"
  remote_name="${remote_name%.git}"
  if [[ "${local_name,,}" == "renameme" || "${remote_name,,}" == "renameme" ]]; then
    fail "配布用の仮名 RenameMe を変更してください（ローカル: ${local_name}、GitHub: ${remote_name}）。"
    return
  fi
  repository_name="$remote_name"
  pass "ローカル名=${local_name}、GitHub リポジトリ名=${remote_name}、SSH remote=${remote}"
}

check_github_cli() {
  command -v gh >/dev/null 2>&1 || { fail "gh が見つかりません。PortableGit Bashを起動し直してください。"; return; }
  gh auth status >/dev/null 2>&1 || { fail "GitHub CLI にログインできません。gh auth login を実行してください。"; return; }
  github_ready=1
  pass "GitHub CLI の認証"
}

check_collaborators() {
  local output_file
  [[ "$github_ready" -eq 1 ]] || return 0
  repository_slug="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
  if [[ -z "$repository_slug" ]]; then
    fail "GitHub リポジトリを特定できません。SSH remote とログイン先を確認してください。"
    return
  fi
  output_file="$(mktemp)"
  if ! gh api --paginate "repos/${repository_slug}/collaborators?per_page=100" --jq '.[].login' > "$output_file"; then
    rm -f "$output_file"
    fail "Collaborator 一覧を取得できません。GitHub の push 権限と認証を確認してください。"
    return
  fi
  mapfile -t collaborators < <(sort -u "$output_file")
  rm -f "$output_file"
  if [[ "${#collaborators[@]}" -eq 0 ]]; then
    fail "Collaborator が0人です。Collaborator を追加してから再実行してください。"
    return
  fi
  pass "Collaborator=${collaborators[*]}"
}

detect_app() {
  local relative_build
  local -a candidates=()
  while IFS= read -r candidate; do candidates+=("$candidate"); done < <(
    find "$REPO_ROOT" -type f \( -name build.gradle -o -name build.gradle.kts \) \
      ! -path "$REPO_ROOT/.git/*" \
      ! -path "$REPO_ROOT/docs/ref/*" \
      ! -path '*/build/*' | sort
  )
  if [[ "${#candidates[@]}" -eq 0 ]]; then
    fail "Spring Boot プロジェクトの build.gradle または build.gradle.kts が見つかりません。"
    return
  fi
  if [[ "${#candidates[@]}" -ne 1 ]]; then
    fail "Spring Boot プロジェクト候補が複数あります: ${candidates[*]#$REPO_ROOT/}"
    return
  fi
  build_file="${candidates[0]}"
  relative_build="${build_file#$REPO_ROOT/}"
  if [[ "$relative_build" == */* ]]; then
    app_dir="${relative_build%/*}"
  else
    app_dir="."
  fi
  if [[ ! -f "$REPO_ROOT/$app_dir/gradlew" || ! -f "$REPO_ROOT/$app_dir/gradlew.bat" ]]; then
    fail "${app_dir}/ に gradlew と gradlew.bat が必要です。"
    return
  fi
  if [[ ! -d "$REPO_ROOT/$app_dir/src/main" ]]; then
    fail "${app_dir}/src/main が見つかりません。"
    return
  fi
  if ! grep -Eq 'org\.springframework\.boot' "$build_file"; then
    fail "${build_file#$REPO_ROOT/} に Spring Boot plugin が見つかりません。"
    return
  fi
  local settings_file=""
  if [[ -f "$REPO_ROOT/$app_dir/settings.gradle" ]]; then
    settings_file="$REPO_ROOT/$app_dir/settings.gradle"
  elif [[ -f "$REPO_ROOT/$app_dir/settings.gradle.kts" ]]; then
    settings_file="$REPO_ROOT/$app_dir/settings.gradle.kts"
  fi
  if [[ -n "$settings_file" ]]; then
    application_name="$(sed -n -E 's/^[[:space:]]*rootProject\.name[[:space:]]*=[[:space:]]*//p' "$settings_file" | head -n 1 | tr -d " '\"")"
  fi
  application_name="${application_name:-$(basename "$REPO_ROOT/$app_dir")}"
  pass "Spring Boot アプリ=${app_dir}（${build_file#$REPO_ROOT/}）"
  pass "アプリ名=${application_name}"
}

check_gradle_test() {
  [[ -n "$app_dir" ]] || return
  if (cd "$REPO_ROOT/$app_dir" && ./gradlew test); then
    pass "${app_dir}/ で ./gradlew test"
  else
    fail "${app_dir}/ の ./gradlew test が失敗しました。"
  fi
}

check_main_protection() {
  local repository rules protection
  [[ "$github_ready" -eq 1 ]] || return 0
  repository="${repository_slug:-$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)}"
  [[ -n "$repository" ]] || { warn "GitHub リポジトリ設定を取得できません。"; return; }
  rules="$(gh api "repos/${repository}/rules/branches/main" 2>/dev/null || true)"
  protection="$(gh api "repos/${repository}/branches/main/protection" 2>/dev/null || true)"
  if printf '%s\n%s\n' "$rules" "$protection" | grep -Eq 'pull_request|required_pull_request_reviews'; then
    pass "main の Pull Request 保護設定"
  else
    warn "main の Pull Request 保護設定を GitHub の Ruleset または Branch protection で確認してください。"
  fi
}

write_config() {
  local config_file temp_file collaborator_file count start_count end_count
  config_file="$(project_config_file "$REPO_ROOT")"
  count="$(awk '$0 == "<!-- PROJECT-CONFIG" { count++ } END { print count + 0 }' "$config_file")"
  [[ "$count" -eq 1 ]] || { echo "NG: ${config_file#$REPO_ROOT/} に PROJECT-CONFIG が1つ必要です。" >&2; exit 1; }
  start_count="$(awk '$0 == "<!-- COLLABORATORS: START -->" { count++ } END { print count + 0 }' "$config_file")"
  end_count="$(awk '$0 == "<!-- COLLABORATORS: END -->" { count++ } END { print count + 0 }' "$config_file")"
  [[ "$start_count" -eq 1 && "$end_count" -eq 1 ]] || { echo "NG: ${config_file#$REPO_ROOT/} に COLLABORATORS マーカーが各1つ必要です。" >&2; exit 1; }
  collaborator_file="$(mktemp)"
  printf '%s\n' "${collaborators[@]}" > "$collaborator_file"
  temp_file="$(mktemp)"
  awk -v repository_name="$repository_name" -v application_name="$application_name" -v app_dir="$app_dir" -v collaborator_file="$collaborator_file" '
    $0 == "<!-- PROJECT-CONFIG" { in_config = 1 }
    in_config && /^repository_name=/ { print "repository_name=" repository_name; next }
    in_config && /^app_name=/ { print "app_name=" application_name; next }
    in_config && /^app_dir=/ { print "app_dir=" app_dir; next }
    $0 == "<!-- COLLABORATORS: START -->" {
      print
      while ((getline login < collaborator_file) > 0) print "- " login
      close(collaborator_file)
      in_collaborators = 1
      next
    }
    in_collaborators && $0 == "<!-- COLLABORATORS: END -->" { in_collaborators = 0; print; next }
    in_collaborators { next }
    { print }
    in_config && $0 == "-->" { in_config = 0 }
  ' "$config_file" > "$temp_file"
  rm -f "$collaborator_file"
  mv "$temp_file" "$config_file"
  pass "docs/project.md にプロジェクト設定と Collaborator 一覧を設定"
}

collaborators_are_current() {
  local config_file
  config_file="$(project_config_file "$REPO_ROOT")"
  diff -q \
    <(awk '
      $0 == "<!-- COLLABORATORS: START -->" { in_collaborators = 1; next }
      $0 == "<!-- COLLABORATORS: END -->" { exit }
      in_collaborators && /^- / { sub(/^- /, ""); print }
    ' "$config_file" | sort -u) \
    <(printf '%s\n' "${collaborators[@]}" | sort -u) >/dev/null
}

echo "--- init-project: ${MODE} ---"
check_name_and_remote
check_github_cli
check_collaborators
detect_app
check_gradle_test
check_main_protection

if [[ "$failures" -gt 0 ]]; then
  echo "初期化できません。NG項目を解消してから再実行してください。" >&2
  exit 1
fi

configured_app_dir="$(project_app_dir "$(project_config_file "$REPO_ROOT")")"
configured_repository_name="$(project_repository_name "$(project_config_file "$REPO_ROOT")")"
configured_application_name="$(project_application_name "$(project_config_file "$REPO_ROOT")")"
collaborators_current=0
if collaborators_are_current; then collaborators_current=1; fi
if [[ "$MODE" == "--initialize" ]]; then
  write_config
elif [[ "$configured_repository_name" == "$repository_name" && "$configured_application_name" == "$application_name" && "$configured_app_dir" == "$app_dir" && "$collaborators_current" -eq 1 ]]; then
  pass "docs/project.md のプロジェクト設定と Collaborator 一覧は検出結果と一致"
else
  echo "設定候補: repository_name=${repository_name}、app_name=${application_name}、app_dir=${app_dir}"
  echo "Collaborator: ${collaborators[*]}"
  echo "設定するには: bash scripts/harness/init-project.sh --initialize"
fi

[[ "$warnings" -eq 0 ]] || echo "要確認項目があります。GitHub リポジトリ設定を確認してください。" >&2
echo "初期化検査に成功しました。"
