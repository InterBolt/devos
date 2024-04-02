#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit
if [ ! -f "hook.docs.sh" ]; then
  log.throw "hook.docs.sh doesn't exist"
fi
if [ ! -f "hook.alias.sh" ]; then
  log.throw "hook.docs.sh doesn't exist"
fi

# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-create" "Automates the creation of a new hook script."
runtime_fn_arg_accept 'n:' 'name' 'The name of the hook script.'
runtime_fn_arg_parse "$@"
name="$(runtime_fn_get_arg 'name')"

if [ -f "scripts/aliased/hook.$name.sh" ]; then
  log.info "Hook already exists"
  exit 0
fi

touch scripts/aliased/hook."$name".sh
echo "# source runtime.sh" >scripts/aliased/hook."$name".sh
chmod +x scripts/aliased/hook."$name".sh
code "scripts/aliased/hook.$name.sh"
scripts/aliased/hook.alias.sh
# shellcheck source=/root/.bashrc
source /root/.bashrc
scripts/aliased/hook.docs.sh
sed -i '/source runtime.sh/d' scripts/aliased/hook."$name".sh
log.info "$runtime_repo_dir/scripts/aliased/hook.$name.sh"
