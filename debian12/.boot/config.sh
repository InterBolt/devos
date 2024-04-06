#!/usr/bin/env bash

# this shouhld map the env variables into runtime variables for debian12

# ex: instead of generating multiple passwords via the bin script
# we're going to instead generate a single seed, then use that seed
# here to generate multiple passwords in a deterministic way.

cd "$(git rev-parse --show-toplevel)" || exit

# shellcheck source=../../.env.sh
. .env.sh
