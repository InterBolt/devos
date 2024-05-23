#!/usr/bin/env bash

. "${HOME}"/.solos/src/host/shell.sh || exit 1
. "${HOME}"/.solos/src/host/bin-posthook.sh || exit 1

__bin__fn__run() {
  local post_behavior="$(__bin_posthook__fn__determine_command "$@")"
  if __bridge__fn__cmd /root/.solos/src/container/cli.sh "$@"; then
    if [[ -n ${post_behavior} ]]; then
      "__bin_posthook__fn__${post_behavior}" "$@"
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
    if [[ -n ${curr_project} ]]; then
      __bin__fn__run checkout "${restricted_flags[@]}" --project="${curr_project}"
    fi
  else
    local next_project="$(
      head -n 1 "${HOME}"/.solos/store/checked_out_project 2>/dev/null || echo ""
    )"
    if [[ ${curr_project} != "${next_project}" ]]; then
      __bridge__fn__destroy
    fi
    __bin__fn__run "${restricted_flags[@]}" "$@"
  fi
}

__bin__fn__main "$@"
