#!/usr/bin/env bash

# Note: we're always inside the REPO dir when this script is run.

# shellcheck source=proxy-lib.sh
. bin/proxy-lib.sh

main --restricted-dev "$@"
