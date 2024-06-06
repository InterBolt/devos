#!/usr/bin/env bash

secrets=()

daemon_scrub__users_home_dir="$(cat "${HOME}/.solos/data/store/users_home_dir" 2>/dev/null || echo "" | head -n 1 | xargs)"

tmp_dir="/root/.solos/data/daemon/tmp/NjZmMjRlNDdjNzllYWMwOTk1NjMxYWE3"
tmp_dir_on_host="${tmp_dir/\/root\//${daemon_scrub__users_home_dir}/}"

tmp_trufflehog_outfile="$(mktemp)"
# trufflehog will output lines like this:
# {"SourceMetadata":{"Data":{"Filesystem":{"file":"/data/data/track/std/1717685008498189280.out","line":6}}},"SourceID":1,"SourceType":15,"SourceName":"trufflehog - filesystem","DetectorType":16,"DetectorName":"Stripe","DecoderName":"PLAIN","Verified":false,"Raw":"sk_live_12345678901234567890123456789012","RawV2":"","Redacted":"","ExtraData":{"rotation_guide":"https://howtorotate.com/docs/tutorials/stripe/"},"StructuredData":null}
# grab the raw secrets at the "Raw" field
docker run --rm -it -v "${tmp_dir_on_host}:/data" trufflesecurity/trufflehog:latest filesystem /data --help
