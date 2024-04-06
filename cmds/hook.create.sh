#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit
if [ ! -f "hook.docs.sh" ]; then
  log.throw "hook.docs.sh doesn't exist"
fi
if [ ! -f "hook.alias.sh" ]; then
  log.throw "hook.docs.sh doesn't exist"
fi

# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-create" "Automates the creation of a new hook script."
fn_arg_accept 'n:' 'name' 'The name of the hook script.'
fn_arg_parse "$@"
name="$(fn_get_arg 'name')"

if [ -f "cmds/hook.$name.sh" ]; then
  log.info "Hook already exists"
  exit 0
fi

touch cmds/hook."$name".sh
echo "# . runtime.sh" >cmds/hook."$name".sh
chmod +x cmds/hook."$name".sh
code "cmds/hook.$name.sh"
cmds/hook.alias.sh
# shellcheck source=/root/.bashrc
. /root/.bashrc
cmds/hook.docs.sh
sed -i '/. runtime.sh/d' cmds/hook."$name".sh
log.info "$repo_dir/cmds/hook.$name.sh"
