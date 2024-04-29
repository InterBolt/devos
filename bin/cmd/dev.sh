#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../solos.sh
. shared/empty.sh
# shellcheck source=../lib/ssh.sh
. shared/empty.sh
# shellcheck source=../lib/status.sh
. shared/empty.sh
# shellcheck source=../lib/store.sh
. shared/empty.sh
# shellcheck source=../lib/utils.sh
. shared/empty.sh
# shellcheck source=../lib/vultr.sh
. shared/empty.sh

cmd.dev() {
  solos.use_checked_out_project

  if ! command -v "code" &>/dev/null; then
    log.error "vscode is not installed to your path. cannot continue."
  fi

  log.warn "would open vscode"
}
