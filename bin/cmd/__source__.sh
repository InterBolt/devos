#!/usr/bin/env bash

# shellcheck source=backup.sh
. cmd/backup.sh
# shellcheck source=dev.sh
. cmd/dev.sh
# shellcheck source=create.sh
. cmd/create.sh
# shellcheck source=restore.sh
. cmd/restore.sh
# shellcheck source=test.sh
. cmd/test.sh
