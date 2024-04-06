#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
. ../../.env.sh
# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-alias" "Build alias commands and save them into the .bashrc file"
fn_arg_parse "$@"

old_ifs=$IFS

get_script_types() {
  IFS=$old_ifs
  aliased=$(ls cmds/*)
  script_types_array=()
  for script in $aliased; do
    FILENAME="$(basename "$script")"
    dot_delimited_filename_prefix="${FILENAME%%.*}"
    script_types_array+=("$dot_delimited_filename_prefix")
  done
  script_types_array=($(echo "${script_types_array[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

  # If the first character of two different string elements in $script_types_array are equal we should throw
  # an error and exit the script.
  for script_type in "${script_types_array[@]}"; do
    first_char=$(echo "$script_type" | head -c 1)
    for script_type_2 in "${script_types_array[@]}"; do
      first_char_2=$(echo "$script_type_2" | head -c 1)
      if [ "$first_char" '==' "$first_char_2" ] && [ "$script_type" != "$script_type_2" ]; then
        log.throw "The first character of $script_type and $script_type_2 are equal."
      fi
    done
  done

  echo "${script_types_array[@]}"
}

# Build the alias commands for each script type.
for script_type in $(get_script_types); do
  log.info "Building alias commands for $script_type aliased."
  delimiter="# REMOTE_SSH_aliased_$script_type"
  IFS=$'\n'

  if grep -q "$delimiter" ~/.bashrc; then
    sed -i "/$delimiter/,/$delimiter/d" ~/.bashrc
  fi

  alias_prefix=$(echo "$script_type" | head -c 1)

  echo "$delimiter" >>~/.bashrc
  for script_name in "cmds/$script_type"*.sh; do
    if [ ! -f "$script_name" ]; then
      break
    fi
    IFS=$old_ifs
    filepath="$(pwd)"/"$script_name"
    filename=$(basename "$script_name")
    filename_without_ext="${filename%.sh}"
    name=$(echo "$filename_without_ext" | sed "s/$script_type//" | sed 's/\.//g')
    if [[ $name == *"__test__"* ]]; then
      continue
    fi
    alias_command="alias $alias_prefix-$name='bash \"$filepath\"'"
    echo "$alias_command" >>~/.bashrc
  done
  echo "alias s=\". /root/.bashrc\"" >>~/.bashrc
  echo "$delimiter" >>~/.bashrc
done

log.info "Building alias command to reload the custom extension."
delimiter="# REMOTE_SSH_RELOAD_EXTENSION_$script_type"
if grep -q "$delimiter" ~/.bashrc; then
  sed -i "/$delimiter/,/$delimiter/d" ~/.bashrc
fi
alias_command="PREV_DIR=\$(pwd) && $repo_dir/scripts/lib/runtime.sh && cd $repo_dir/extension && npm run sync && cd \$PREV_DIR"
{
  echo "$delimiter"
  echo "alias ext='$alias_command'"
  echo "alias s=\". /root/.bashrc\""
  echo "$delimiter"
} >>~/.bashrc
log.info "Run 's' to . the .bashrc"
