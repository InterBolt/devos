#!/usr/bin/env bash

# shellcheck source=backup.sh
. backup.sh
# shellcheck source=checkout.sh
. checkout.sh
# shellcheck source=code.sh
. code.sh
# shellcheck source=launch.sh
. launch.sh
# shellcheck source=precheck.sh
. precheck.sh
# shellcheck source=restore.sh
. restore.sh
# shellcheck source=sync_config.sh
. sync_config.sh
# shellcheck source=tests.sh
. tests.sh
# shellcheck source=gen.sh
. gen.sh
