#!/usr/bin/env bash

. "${HOME}"/.solos/src/host/docker.sh || exit 1
. "${HOME}"/.solos/src/host/bin-post-hook.sh || exit 1

__bin__fn__run() {
  local post_behavior="$(__bin_post_hook__fn__determine_command "$@")"
  if __docker__fn__run /root/.solos/src/cli/solos.sh "$@"; then
    if [[ -n ${post_behavior} ]]; then
      "__bin_post_hook__fn__${post_behavior}" "$@"
    fi
  fi
}

__bin__fn__main() {
  local curr_project="$(
    head -n 1 "${HOME}"/.solos/store/checked_out_project 2>/dev/null || echo ""
  )"
  local restricted_flags=()
  while [[ $# -gt 0 ]]; do
    if [[ ${1} = --restricted-* ]]; then
      restricted_flags+=("${1}")
      shift
    else
      break
    fi
  done
  if [[ $# -eq 0 ]]; then
    if [[ -z ${curr_project} ]]; then
      echo "No project is currently checked out."
      exit 1
    fi
    __bin__fn__run checkout "${restricted_flags[@]}" --project="${curr_project}"
  else
    local next_project="$(
      head -n 1 "${HOME}"/.solos/store/checked_out_project 2>/dev/null || echo ""
    )"
    if [[ ${curr_project} != "${next_project}" ]]; then
      __docker__fn__destroy
    fi
    __bin__fn__run "${restricted_flags[@]}" "$@"
  fi
}

__bin__fn__main "$@"
