#!/usr/bin/env bash
# docs/project.md 内の PROJECT-CONFIG を読む共通関数。

project_config_file() {
  local repo_root="$1"
  printf '%s/docs/project.md' "$repo_root"
}

project_config_value() {
  local config_file="$1" key="$2"
  awk '
    $0 == "<!-- PROJECT-CONFIG" { in_config = 1; next }
    in_config && $0 == "-->" { exit }
    in_config && index($0, key "=") == 1 { sub(key "=", ""); print; exit }
  ' key="$key" "$config_file"
}

project_repository_name() {
  project_config_value "$1" repository_name
}

project_application_name() {
  project_config_value "$1" app_name
}

project_app_dir() {
  project_config_value "$1" app_dir
}

project_app_dir_is_safe() {
  local app_dir="$1"
  [[ -n "$app_dir" ]] || return 1
  [[ "$app_dir" != /* && "$app_dir" != *".."* ]] || return 1
  [[ "$app_dir" =~ ^[A-Za-z0-9._/-]+$ ]]
}
