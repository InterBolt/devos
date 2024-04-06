#!/usr/bin/env bash

# this shouhld map the env variables into runtime variables for debian12

# ex: instead of generating multiple passwords via the bin script
# we're going to instead generate a single seed, then use that seed
# here to generate multiple passwords in a deterministic way.

cd "$(git rev-parse --show-toplevel)" || exit

# shellcheck source=../../.env.sh
. .env.sh

#
# DUMMY: I removed the below config file from the source code.
#
# domain=newsletter.interbolt.org
# repo=newsletter
# cname=newsletter.captain.interbolt.org
# zone=db32bc8508aeb83d9ef0e0862a0e8061

# domain=semanticcachehit.com
# repo=semantic-cache-hit-demo
# cname=semanticcachehit.captain.interbolt.org
# zone=db32bc8508aeb83d9ef0e0862a0e8061

# domain=tearabledots.com
# repo=tearable-dots
# cname=tearabledots.captain.interbolt.org
# zone=db32bc8508aeb83d9ef0e0862a0e8061

# domain=waku.land
# repo=waku-land
# cname=waku-land.captain.interbolt.org
# zone=db32bc8508aeb83d9ef0e0862a0e8061
