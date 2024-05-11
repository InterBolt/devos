#!/usr/bin/env bash

# shellcheck source=docker.sh
. "${HOME}"/.solos/src/bin/docker.sh || exit 1
# shellcheck source=shared/bin-host-post-fn.sh
. "${HOME}"/.solos/src/shared/bin-host-post-fn.sh || exit 1

__bin_dev__fn__main() {
  local post_behavior="$(__bin_host_post_fn__fn__determine_host_post_fn "$@")"
  if __docker__fn__run /root/.solos/src/bin/solos.sh --restricted-developer "$@"; then
    if [[ -n ${post_behavior} ]]; then
      "__bin_host_post_fn__fn__${post_behavior}" "$@"
    fi
  fi
}

__bin_dev__fn__main "$@"
