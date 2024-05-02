#!/usr/bin/env bash
# shellcheck disable=SC2103,SC2164

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../bin.sh
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
# shellcheck source=../task/boot.sh
. shared/empty.sh

cmd.try() {
  solos.use_checked_out_project
  log.warn "TODO: implementation needed"
}
