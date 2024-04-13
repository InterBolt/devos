#!/usr/bin/env bash

# shellcheck source=backup.sh
. cmd/backup.sh
# shellcheck source=checkout.sh
. cmd/checkout.sh
# shellcheck source=code.sh
. cmd/code.sh
# shellcheck source=launch.sh
. cmd/launch.sh
# shellcheck source=restore.sh
. cmd/restore.sh
# shellcheck source=sync_config.sh
. cmd/sync_config.sh
# shellcheck source=tests.sh
. cmd/tests.sh
