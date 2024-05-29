#!/usr/bin/env bash

# This script defines some behavior associated with the *success* of various CLI commands when run on the host.
# Ex: when we run `solos app <app_name>`, we want to invoke the `code` command on the host.

# A utility function. There is not command called `determine_command`
__posthooks__fn__determine_command() {
  while [[ $# -gt 0 ]] && [[ $1 == --* ]]; do
    shift
  done
  local host_post_fn=""
  if declare -f "__posthooks__fn__${1}" >/dev/null; then
    host_post_fn="$1"
  fi
  echo "${host_post_fn}"
}

# Every function below defines some behavior associated with the *success* of a particular command.
__posthooks__fn__checkout() {
  if [[ -e /etc/solos ]]; then
    return 0
  fi
  if [[ -z "${1}" ]]; then
    echo "Unexpected error: no project specified." >&2
    exit 1
  fi
  local project=""
  while [[ $# -gt 0 ]]; do
    case $1 in
    --project=*)
      project="${1#*=}"
      shift
      ;;
    *)
      shift
      ;;
    esac
  done
  if [[ -z "${project}" ]]; then
    echo "Unexpected error: no project specified." >&2
    exit 1
  fi
  local code_workspace_file="${HOME}/.solos/projects/${project}/.vscode/solos-${project}.code-workspace"
  if [[ ! -f "${code_workspace_file}" ]]; then
    echo "Unexpected error: no code workspace file found for project ${project}." >&2
    exit 1
  fi
  code "${code_workspace_file}"
}

__posthooks__fn__app() {
  if [[ -e /etc/solos ]]; then
    return 0
  fi
  if [[ -z "${1}" ]]; then
    echo "Unexpected error: no project specified." >&2
    exit 1
  fi
  local project="$(cat "${HOME}/.solos/store/checked_out_project" | head -n 1)"
  local project_dir="${HOME}/.solos/projects/${project}"
  if [[ ! -d "${HOME}/.solos/projects/${project}" ]]; then
    echo "Unexpected error: no project specified." >&2
    exit 1
  fi
  local cmd=""
  local app=""
  while [[ $# -gt 0 ]]; do
    case $1 in
    --*)
      shift
      ;;
    *)
      if [[ -z "${cmd}" ]]; then
        cmd="$1"
      else
        app="$1"
        break
      fi
      shift
      ;;
    esac
  done
  local app_dir="${HOME}/.solos/projects/${project}/apps/${app}"
  if [[ ! -d "${app_dir}" ]]; then
    echo "Unexpected error: couldn't find - ${app_dir}" >&2
    exit 1
  fi
  code -r "${app_dir}/solos.preexec.sh"
}
