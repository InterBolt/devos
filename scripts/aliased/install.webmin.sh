#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "i-webmin" "Installs Webmin."
runtime_fn_arg_parse "$@"

mkdir -p tmp
cd tmp || exit

SETUP_SCRIPT_URL="https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh"
SETUP_SCRIPT_NAME="$(basename "$SETUP_SCRIPT_URL")"

cleanup() {
  rm "$SETUP_SCRIPT_NAME" || true
  cd ..
  rm -rf tmp || true
}

runtime_fn_fail_on_used_port 10000

ufw allow 10000/tcp

# don't keep a one-off script around if something fails
trap 'cleanup' ERR

curl -o "$SETUP_SCRIPT_NAME" "$SETUP_SCRIPT_URL"
sh "$SETUP_SCRIPT_NAME" --force

DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends webmin

sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf
/usr/bin/webmin restart
log.info "disabled https for webmin since we're forwarding port from our local machine"
cleanup
log.info "Webmin is now installed and running at http://localhost:10000"
