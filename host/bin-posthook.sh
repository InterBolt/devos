#!/usr/bin/env bash

# A utility function. There is not command called `determine_host_post_fn`
__bin_posthook__fn__determine_command() {
  while [[ $# -gt 0 ]] && [[ $1 == --* ]]; do
    shift
  done
  local host_post_fn=""
  if declare -f "__bin_posthook__fn__${1}" >/dev/null; then
    host_post_fn="$1"
  fi
  echo "${host_post_fn}"
}

# Every function below defines some behavior associated with the success of a particular command.
# Examples:
# `solos dev` => __bin_posthook__fn__dev
# `solos test` => __bin_posthook__fn__test
# ...etc, etc
#
# Note: these are necessary because there are some things that are always better to do on
# the host machine, but ONLY after the command makes any necessary changes to the container,
# the FS, etc.
__bin_posthook__fn__checkout() {
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

__bin_posthook__fn__app() {
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
