#!/usr/bin/env bash

# shellcheck source=backup.sh
. cmd/backup.sh
# shellcheck source=checkout.sh
. cmd/checkout.sh
# shellcheck source=health.sh
. cmd/health.sh
# shellcheck source=provision.sh
. cmd/provision.sh
# shellcheck source=restore.sh
. cmd/restore.sh
# shellcheck source=teardown.sh
. cmd/teardown.sh
# shellcheck source=test.sh
. cmd/test.sh
# shellcheck source=try.sh
. cmd/try.sh
