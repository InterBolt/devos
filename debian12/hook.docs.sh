#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit
# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "h-docs" "Generates inline comments for copilot and README.md documentation."
fn_arg_parse "$@"

sed -i '/## Scripts/,$d' README.md
{
  echo "## Scripts"
  echo ""
  echo "The following aliased scripts are available in this repository:"
  echo ""
  for script in cmds/*.sh; do
    if [ ! -f "$script" ]; then
      break
    fi
    help_text="$($script --print-help)"
    # Escape any characters that don't work well in a markdown code block
    help_text="$(echo "${help_text}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    echo "\`\`\`"
    echo "$help_text"
    echo "\`\`\`"
    echo ""
  done
} >>README.md

n=$'\n'
runtime_docs_header="# - All exported variables from runtime.sh:"
doc_string="$runtime_docs_header$n"
for expected_runtime_variable in "${runtime_expectations[@]}"; do
  expected_runtime_variable_name="$(echo "$expected_runtime_variable" | cut -d "#" -f 1)"
  expected_runtime_variable_description="$(echo "$expected_runtime_variable" | cut -d "#" -f 2)"
  if [[ $expected_runtime_variable_name == "fn_"* ]]; then
    doc_string="$doc_string#   - exported function: \$$expected_runtime_variable_name: $expected_runtime_variable_description$n"
  else
    doc_string="$doc_string#   - exported variable: \$$expected_runtime_variable_name: $expected_runtime_variable_description$n"
  fi
done
for cmd_script in "$repo_dir/cmds"/*.sh; do
  if [ -n "$(echo "$cmd_script" | grep ".runtime")" ]; then
    continue
  fi
  start_delimiter="START OF CONTEXT FOR COPILOT"
  end_delimiter="END OF CONTEXT FOR COPILOT"
  start_d_for_sed="\# \[$start_delimiter\]"
  end_d_for_sed="\# \[$end_delimiter\]"
  start_d_for_print="# [$start_delimiter]"
  end_d_for_print="# [$end_delimiter]"

  context_comment="$start_d_for_print$n$doc_string$end_d_for_print"
  sed -i "/$start_d_for_sed/,/$end_d_for_sed/d" "$cmd_script"
  sed -i '/^#\!\/.*$/d' "$cmd_script"
  shebang_prefix="#!"
  new_script_contents="$context_comment$n$(cat "$cmd_script")"
  new_script_contents="$shebang_prefix/usr/bin/env bash$n$new_script_contents"
  echo "$new_script_contents" >"$cmd_script"
done

IFS=$OLD_IFS
