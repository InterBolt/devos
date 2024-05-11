#!/usr/bin/env bash

. "${HOME}"/.solos/src/bin/shared/helpers.sh || exit 1

# A utility function. There is not command called `determine_host_post_fn`
__bin_host_post_fn__fn__determine_host_post_fn() {
  while [[ $# -gt 0 ]] && [[ $1 == --* ]]; do
    shift
  done
  local host_post_fn=""
  if declare -f "__bin_host_post_fn__fn__${1}" >/dev/null; then
    host_post_fn="$1"
  fi
  echo "${host_post_fn}"
}

# Every function below defines some behavior associated with the success of a particular command.
# Examples:
# `solos dev` => __bin_host_post_fn__fn__dev
# `solos test` => __bin_host_post_fn__fn__test
# ...etc, etc
#
# Note: these are necessary because there are some things that are always better to do on
# the host machine, but ONLY after the command makes any necessary changes to the container,
# the FS, etc.
__bin_host_post_fn__fn__checkout() {
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
  local code_workspace_file="/root/.solos/src/.vscode/solos-${project}.code-workspace"
  if [[ ! -f "${code_workspace_file}" ]]; then
    echo "Unexpected error: no code workspace file found for project ${project}." >&2
    exit 1
  fi
  code "/root/.solos/src/.vscode/solos-${project}.code-workspace"
}
