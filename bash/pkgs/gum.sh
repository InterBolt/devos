#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

gum__self_dir="${HOME}/.solos/src/bash/pkgs"
gum__self_dirname=".installs"

gum.get_release_file() {
  local gum_version="0.13.0"
  local gum_release_url="https://github.com/charmbracelet/gum/releases/download"
  local release=""
  if [[ $(uname) = 'Darwin' ]]; then
    if [[ $(uname -m) = 'arm64' ]]; then
      release="${gum_release_url}/v${gum_version}/gum_${gum_version}_Darwin_arm64.tar.gz"
    else
      release="${gum_release_url}/v${gum_version}/gum_${gum_version}_Darwin_x86_64.tar.gz"
    fi
  else
    if [[ $(uname -m) = 'arm64' ]]; then
      release="${gum_release_url}/v${gum_version}/gum_${gum_version}_Linux_arm64.tar.gz"
    else
      release="${gum_release_url}/v${gum_version}/gum_${gum_version}_Linux_x86_64.tar.gz"
    fi
  fi
  echo "${release}"
}

# PUBLIC FUNCTIONS:

gum_install() {
  local release="$(gum.get_release_file)"
  local release_download_dirname="$(basename "${release}" | sed 's/.tar.gz//')"
  local location_dir="${gum__self_dir}/${gum__self_dirname}/${release_download_dirname}"
  mkdir -p "${location_dir}"
  if [[ ! -f ${location_dir}/gum ]]; then
    curl -L --silent --show-error "${release}" | tar -xz -C "${location_dir}"
  fi
  echo "${location_dir}/gum"
}
gum_bin() {
  local executable_path="$(gum_install)"
  if [[ -f ${executable_path} ]]; then
    "${executable_path}" "$@"
  else
    echo "failed to install gum" >&2
    exit 1
  fi
}
gum_tag_category_choice() {
  local categories_file="$1"
  local categories="$(cat "${categories_file}")"
  local categories_file=""
  local i=0
  while IFS= read -r line; do
    if [[ -n "${line}" ]]; then
      if [[ ${i} -gt 0 ]]; then
        categories_file+="${newline}${line}"
      else
        categories_file+="${line}"
      fi
      i=$((i + 1))
    fi
  done <<<"${categories}"
  unset IFS
  local user_exit_str="SOLOS:EXIT:1"
  echo "${categories_file}" | gum_bin choose --limit 1 || echo "SOLOS:EXIT:1"
}
gum_post_cmd_note() {
  gum_bin input --placeholder "Post-command note:"
}
gum_tag_category_input() {
  gum_bin input --placeholder "Enter new tag:"
}
gum_pre_cmd_note_input() {
  gum_bin input --placeholder "Enter note"
}
gum_plugin_config_input() {
  local key="$1"
  local value="$(gum_bin input --placeholder "Enter ${key}:" || echo "SOLOS:EXIT:1")"
  if [[ -z ${value} ]]; then
    gum_plugin_config_input "${key}"
  else
    echo "${value}"
  fi
}
gum_shell_log() {
  local will_print="${1:-true}"
  local log_file="$2"
  local level="$3"
  local msg="$4"
  local source="$5"
  declare -A log_level_colors=(["info"]="#3B78FF" ["tag"]="#0F0" ["debug"]="#A0A" ["error"]="#F02" ["fatal"]="#F02" ["warn"]="#FA0")
  local date="$(date "+%F %T")"
  local source_args=()
  if [[ -n ${source} ]]; then
    source_args=(source "[${source}]")
  fi
  if [[ -t 1 ]] || [[ ${will_print} = true ]]; then
    gum_bin log \
      --level.foreground "${log_level_colors["${level}"]}" \
      --structured \
      --level "${level}" "${msg}"
  fi
  gum_bin log \
    --level.foreground "${log_level_colors["${level}"]}" \
    --file "${log_file}" \
    --structured \
    --level "${level}" "${msg}" "${source_args[@]}" date "${date}"
}
gum_github_token() {
  gum_bin input --password --placeholder "Enter Github access token:"
}
gum_github_email() {
  gum_bin input --placeholder "Enter Github email:"
}
gum_github_name() {
  gum_bin input --placeholder "Enter Github username:"
}
gum_repo_url() {
  gum_bin input --placeholder "Provide a github repo url:"
}
gum_confirm_new_app() {
  local project_name="$1"
  local project_app="$2"
  if gum_bin confirm \
    "Are you sure you want to create a new app called \`${project_app}\` in the project \`${project_name}\`?" \
    --affirmative="Yes" \
    --negative="No, exit without creating the app."; then
    echo "true"
  else
    echo "false"
  fi
}
gum_confirm_checkout_project() {
  if gum_bin confirm \
    "Would you like to checkout a project?" \
    --affirmative="Yes" \
    --negative="No, I'll do that later."; then
    echo "true"
  else
    echo "false"
  fi
}
gum_project_choices() {
  local choices_file=""
  local newline=$'\n'
  local i=0
  for arg in "$@"; do
    if [[ ${i} -gt 0 ]]; then
      choices_file+="${newline}${arg}"
    else
      choices_file+="${arg}"
    fi
    i=$((i + 1))
  done
  local project="$(echo "${choices_file}" | gum_bin choose --limit 1 || echo "SOLOS:EXIT:1")"
  if [[ "${project}" = "SOLOS:EXIT:1" ]]; then
    echo ""
  else
    echo "${project}"
  fi
}
gum_new_project_name_input() {
  gum_bin input --placeholder "Enter a new project name:"
}
gum_confirm_retry() {
  local project_name="$1"
  local project_app="$2"
  if gum_bin confirm \
    "Would you like to retry?" \
    --affirmative="Yes, retry." \
    --negative="No, I'll try again later."; then
    echo "true"
  else
    echo "false"
  fi
}
gum_confirm_overwriting_setup() {
  if gum_bin confirm \
    "After reviewing the current setup, are you sure you want to proceed?" \
    --affirmative="Yes, continue" \
    --negative="No."; then
    echo "true"
  else
    echo "false"
  fi
}
gum_confirm_ignore_panic() {
  if gum_bin confirm \
    "Would you like to ignore the panic file?" \
    --affirmative="Yes, I know what I'm doing" \
    --negative="No, exit now."; then
    echo "true"
  else
    echo "false"
  fi
}
gum_optional_openai_api_key_input() {
  gum_bin input --password --placeholder "Enter an API key associated with your OpenAI account (leave blank to opt-out of AI features):"
}
gum_danger_box() {
  local terminal_width=$(tput cols)
  gum_bin style \
    --foreground "#F02" --border-foreground "#F02" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}
gum_success_box() {
  local terminal_width=$(tput cols)
  gum_bin style \
    --foreground "#0F0" --border-foreground "#0F0" --border thick \
    --width "$((terminal_width - 2))" --align left --margin ".5" --padding "1 2" \
    "$@"
}
