#!/usr/bin/env bash

. "${HOME}/.solos/src/bash/lib.sh" || exit 1

# This script defines some behavior associated with the *success* of various CLI commands when run on the host.
# Ex: when we run `solos app <app_name>`, we want to invoke the `code` command on the host.

# A utility function. There is not command called `determine_command`
cli_posthooks.determine_command() {
  # Strip flags to get the command name.
  while [[ $# -gt 0 ]] && [[ $1 = --* ]]; do
    shift
  done
  local host_post_fn=""
  if declare -f "cli_posthooks.${1}" >/dev/null; then
    host_post_fn="$1"
  fi
  echo "${host_post_fn}"
}
# Every function below defines some behavior associated with the *success* of a particular command.
cli_posthooks.checkout() {
  if [[ -z "${1}" ]]; then
    echo "Unexpected error: no project specified." >&2
    exit 1
  fi
  local project="${1}"
  local code_workspace_file="${HOME}/.solos/projects/${project}/.vscode/solos-${project}.code-workspace"
  if [[ ! -f "${code_workspace_file}" ]]; then
    echo "Unexpected error: no code workspace file found for project ${project}." >&2
    exit 1
  fi
  code "${code_workspace_file}"
}
cli_posthooks.app() {
  if [[ -z "${1}" ]]; then
    echo "Unexpected error: no app specified." >&2
    exit 1
  fi
  local app="${1}"
  local project="$(lib.checked_out_project)"
  if [[ -z ${project} ]]; then
    echo "Unexpected error: no project checked out." >&2
    exit 1
  fi
  local project_dir="${HOME}/.solos/projects/${project}"
  if [[ ! -d "${HOME}/.solos/projects/${project}" ]]; then
    echo "Unexpected error: no project exists." >&2
    exit 1
  fi
  local app_dir="${project_dir}/apps/${app}"
  if [[ ! -d "${app_dir}" ]]; then
    echo "Unexpected error: couldn't find - ${app_dir}" >&2
    exit 1
  fi
  local app_dir_preexec_script="${app_dir}/solos.preexec.sh"
  if [[ ! -f ${app_dir_preexec_script} ]]; then
    echo "No preexec script found for app ${app}." >&2
    exit 1
  fi
  code -r "${app_dir_preexec_script}"
}
cli_posthooks.setup() {
  local project="$(lib.checked_out_project)"
  if [[ -z ${project} ]]; then
    echo "Unexpected error: no project checked out." >&2
    exit 1
  fi
  bash -ic "solos checkout ${project}"
}
