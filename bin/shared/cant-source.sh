#!/usr/bin/env bash
# shellcheck disable=SC2103,SC2164
set -o pipefail
set -o errtrace

# Checking for the vSOLOS_STARTED_AT variable protects us against accidentally running
# a script that should almost always only be source directly.
if [[ $((vSOLOS_STARTED_AT)) != 0 ]]; then
  echo "Error: you tried sourcing this script."
  echo "This is not a solos library script. Run this script directly."
  exit 1
fi
