#!/usr/bin/env bash

# WARNING: the lack of initial "cd" is intentional.
# This script is strictly meant to be sourced from the scp'd bootstrap script.
# Refer to installer/boot/bootstrap.sh for the working directory.

# shellcheck source=shared.packages.sh
. installer/start/shared.packages.sh
# shellcheck source=../../cmds/install.docker.sh
. cmds/install.docker.sh
# shellcheck source=../../cmds/install.node.sh
. cmds/install.node.sh
# shellcheck source=../../cmds/install.caprover.sh
. cmds/install.caprover.sh
# shellcheck source=../../cmds/install.webmin.sh
. cmds/install.webmin.sh
#
# Maybe clean this up, but the idea is to automatically install
# the cli we use to bootstrap the system on our laptop.
#
SOFTWARE_NAME="solos"
BIN_PATH="/usr/local/bin/$SOFTWARE_NAME"
if [ -f "$BIN_PATH" ]; then
  rm -f "$BIN_PATH"
fi
{
  echo "#!/usr/bin/env bash"
  echo ""
  echo "# This script is a placeholder to make sure and provide a helpful warning when we try to use the solos"
  echo "# command on our remote server. It's not meant to be run here."
  echo ""
  echo "echo \"This script is not meant to be run on the remote server. It's meant to be run on your local machine or docker container.\" && exit 1"
} >>"$BIN_PATH"
chmod +x "$BIN_PATH"
