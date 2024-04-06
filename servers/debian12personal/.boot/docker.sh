#!/usr/bin/env bash

# WARNING: the lack of initial "cd" is intentional.
# This script is strictly meant to be sourced from the scp'd bootstrap script.
# Refer to installer/boot/bootstrap.sh for the working directory.

# shellcheck source=shared.packages.sh
. shared.packages.sh
# shellcheck source=../install.node.sh
. ../install.node.sh
# shellcheck source=../hook.alias.sh
. ../hook.alias.sh
# shellcheck source=../install.clone-repos.sh
. ../install.clone-repos.sh
# shellcheck source=../install.apps.sh
. ../install.apps.sh
# shellcheck source=../hook.docs.sh
. ../hook.docs.sh
