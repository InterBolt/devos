#!/usr/bin/env bash

set -o pipefail
set -o errtrace

. shared/empty.sh

# Checking for the vSOLOS_STARTED_AT variable protects us against accidentally running
# a script that should almost always only be source directly.
if [[ ${vSOLOS_RUNTIME} = 1 ]]; then
  echo "You tried running this script directly."
  echo "This is either library script, or a script that makes too many damn assumptions."
  echo "Source (eg . <script>) this script instead."
  exit 1
fi
