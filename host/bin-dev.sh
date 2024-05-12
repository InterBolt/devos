#!/usr/bin/env bash

. "${HOME}"/.solos/src/host/docker.sh || exit 1
. "${HOME}"/.solos/src/host/bin-post-hook.sh || exit 1

__bin_dev__fn__main() {
  local post_behavior="$(__bin_post_hook__fn__determine_command "$@")"
  if __docker__fn__run /root/.solos/src/bin/solos.sh --restricted-developer "$@"; then
    if [[ -n ${post_behavior} ]]; then
      "__bin_post_hook__fn__${post_behavior}" "$@"
    fi
  fi
}

if [[ $# -eq 0 ]]; then
  __bin_dev__var__checked_out_project="$(head -n 1 "${HOME}"/.solos/store/checked_out_project)"
  if [[ -z ${__bin_dev__var__checked_out_project} ]]; then
    echo "No project is currently checked out."
    exit 1
  fi
  __bin__fn__main checkout --project="${__bin_dev__var__checked_out_project}"
else
  __bin__fn__main "$@"
fi
