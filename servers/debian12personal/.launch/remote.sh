#!/usr/bin/env bash

# WARNING: the lack of initial "cd" is intentional.
# This script is strictly meant to be sourced from the scp'd bootstrap script.
# Refer to installer/boot/bootstrap.sh for the working directory.

vSERVER_NAME="debian12personal"

# shellcheck source=shared.packages.sh
. "servers/$vSERVER_NAME/.boot/shared.packages.sh"
# shellcheck source=../install.docker.sh
. "servers/$vSERVER_NAME/install.docker.sh"
# shellcheck source=../install.node.sh
. "servers/$vSERVER_NAME/install.node.sh"
# shellcheck source=../install.caprover.sh
. "servers/$vSERVER_NAME/install.caprover.sh"
# shellcheck source=../install.webmin.sh
. "servers/$vSERVER_NAME/install.webmin.sh"
