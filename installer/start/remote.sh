#!/usr/bin/env bash

# WARNING: the lack of initial "cd" is intentional.
# This script is strictly meant to be sourced from the scp'd bootstrap script.
# Refer to installer/boot/bootstrap.sh for the working directory.

# shellcheck source=shared.packages.sh
source installer/start/shared.packages.sh
# shellcheck source=../../scripts/aliased/install.docker.sh
source scripts/aliased/install.docker.sh
# shellcheck source=../../scripts/aliased/install.node.sh
source scripts/aliased/install.node.sh
# shellcheck source=../../scripts/aliased/install.caprover.sh
source scripts/aliased/install.caprover.sh
# shellcheck source=../../scripts/aliased/install.webmin.sh
source scripts/aliased/install.webmin.sh
