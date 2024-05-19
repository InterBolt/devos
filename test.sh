#!/usr/bin/env bash

shopt -s extdebug

gum_path="/root/.solos/src/pkgs/.installs/gum_0.13.0_Linux_x86_64/gum"

intercept_fn() {
  trap - DEBUG
  local stdout_captured_file="/tmp/stdout_captured_file"
  local stderr_captured_file="/tmp/stderr_captured_file"
  local stdout_file="/tmp/stdout_file"
  local stderr_file="/tmp/stderr_file"
  # despite the fact that we're running our command through a subshell, it should still be interactive and print correctly, including colors
  {
    exec \
      > >(tee >(grep "^\[RAG\]" >>"${stdout_captured_file}") "${stdout_file}") \
      2> >(tee >(grep "^\[RAG\]" >>"${stderr_captured_file}") "${stderr_file}" >&2)
    eval "${BASH_COMMAND}"
  }
  trap 'intercept_fn' DEBUG
  return 1
}

sleep 1

gum_confirm_new_app() {
  local project_name="$1"
  local project_app="$2"
  if "${gum_path}" confirm \
    "Are you sure you want to create a new app called \`${project_app}\` in the project \`${project_name}\`?" \
    --affirmative="Yes" \
    --negative="No, exit without creating the app."; then
    echo "true"
  else
    echo "false"
  fi
}

stdout_captured_file="/tmp/stdout_captured_file"
stderr_captured_file="/tmp/stderr_captured_file"
stdout_file="/tmp/stdout_file"
stderr_file="/tmp/stderr_file"
exit_code_file="/tmp/exit_code_file"

exec 3>&1 4>&2
exec \
  > >(tee "${stdout_file}") \
  2> >(tee "${stderr_file}" >&2)
"${gum_path}" confirm \
  "Are you sure you want to create a new app called \`${project_app}\` in the project \`${project_name}\`?" \
  --affirmative="Yes" \
  --negative="No, exit without creating the app." >&3 2>&4
