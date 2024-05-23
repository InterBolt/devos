#!/usr/bin/env bash

shopt -s extdebug

# when the user spams control-c make sure we reset the trap
# We use the PROMPT_COMMAND to set a variable which will gate the trap logic for compound commands.
# Ie. cmd1 | cmd2 should not get captured for each command, but rather as a single command.
# We'll use the history command to determine the full prompt and then we'll eval it.
trap 'trap "__profile_rag__fn__trap" DEBUG' SIGINT

__profile_rag__sigexit='SOLOS:EXIT:1'
__profile_rag__dir="${HOME}/.solos/rag"
__profile_rag__config_dir="${__profile_rag__dir}/config"
__profile_rag__logs_dir="${__profile_rag__dir}/logs"
__profile_rag__std_dir="${__profile_rag__dir}/std"
__profile_rag__tmp_dir="${__profile_rag__dir}/tmp"

__profile_rag__fn__print_rag_help() {
  cat <<EOF

USAGE: rag [options] <command> | rag logs

DESCRIPTION:

Prompts the user to write a note. Any positional arguments supplied that are not \
valid options will be executed as a command. The output of the command is recorded \
along with the note for future reference.

The name "rag" was chosen because the notes we take along with the commands \
and their output will aid in a retrieval augmentation generation (RAG) system.

config: ${__profile_rag__config_dir}
logs: ${__profile_rag__logs_dir}
output: ${__profile_rag__tmp_dir}

OPTIONS:

-n               Note only. Will not prompt for a tag.
-t               Tag only. Will not prompt for a note.
-c               Command only. Will not prompt for a note or a tag. Overrides -t and -n.

--help           Print this help message.

EOF
}

__profile_rag__fn__init_fs() {
  mkdir -p "${__profile_rag__config_dir}"
  mkdir -p "${__profile_rag__logs_dir}"
  mkdir -p "${__profile_rag__tmp_dir}"
  mkdir -p "${__profile_rag__std_dir}"
  if [[ ! -f "${__profile_rag__config_dir}/tags" ]]; then
    {
      echo "<none>"
      echo "<create>"
    } >"${__profile_rag__config_dir}/tags"
  fi
}

__profile_rag__fn__save_output() {
  local tmp_jq_output_file="$1"
  jq -c '.' <"${tmp_jq_output_file}" >>"${__profile_rag__logs_dir}/commands.log"
  rm -f "${tmp_jq_output_file}"
  rm -rf "${__profile_rag__tmp_dir}"
}

# How the trap function handles each return code:
# - return 1   - trap fn should execute the command and capture the output
# - return 0   - execute the command without any tracking or capture
# - return 150 - the trap fn should do nothing and return 0 because it was run here.
# - return 151 - the trap fn might handle this in different ways going forward, but
#                for now it means that the preexec functions or scripts failed.
__profile_rag__fn__preexec() {
  local prompt="${1}"

  # When the '- ' prefix is supplied in the SolOS shell prompt,
  # it means we want to avoid any and all preexec logic and run the thing as is
  # TODO: fix - doesn't this mask the true error code of the command?
  if [[ ${prompt} = "- "* ]]; then
    prompt="$(echo "${prompt}" | tr -s ' ' | cut -d' ' -f2-)"
    eval "${prompt}"
    return 150
  fi

  # We have a list of commands (might need to add lots more idk) that we know
  # should never be captured, tracked, logged, you name it. Run them as is.
  # Think `clear`, working dir changes like cd, `exit`, that kind of thing.
  # Important: if a pipe operator exists, all bets are off and we assume that we
  # want to capture the output.
  for opt_out in "${__profile_bashrc__preexec_dont_track_or_fuck_with_these[@]}"; do
    if [[ ${prompt} = "${opt_out} "* ]] || [[ ${prompt} = "${opt_out}" ]]; then
      if [[ ${prompt} = *"|"* ]]; then
        break
      fi
      return 0
    fi
  done
  local preexec_scripts=()
  local next_dir="${PWD}"
  while [[ ${next_dir} != "${HOME}/.solos" ]]; do
    if [[ -f "${next_dir}/solos.preexec.sh" ]]; then
      preexec_scripts=("${next_dir}/solos.preexec.sh" "${preexec_scripts[@]}")
    fi
    next_dir="$(dirname "${next_dir}")"
  done
  for preexec_script in "${preexec_scripts[@]}"; do
    # Use tee to send stdout to the terminal and then process/supress the tee output
    # using cat. The result is a visible output that does not affect stdout or stdout in
    # unexpected ways.
    if ! "${preexec_script}"; then
      return 151
    fi
  done

  return 1
}

__profile_rag__fn__digest() {
  local rag_id="${1:-""}"
  local user_note="${2:-""}"
  local user_tag="${3:-""}"
  local should_collect_post_note="${3:-false}"

  local stdout_file="${__profile_rag__tmp_dir}/.stdout"
  local stderr_file="${__profile_rag__tmp_dir}/.stderr"
  local cmd_file="${__profile_rag__tmp_dir}/.cmd"
  local exit_code_file="${__profile_rag__tmp_dir}/.exit_code"
  local stdout_captured_file="${__profile_rag__tmp_dir}/.stdout_captured"
  local stderr_captured_file="${__profile_rag__tmp_dir}/.stderr_captured"

  local tmp_jq_output_file="$(mktemp)"
  echo '{
    "id": "'"${rag_id}"'",
    "date": "'"$(date)"'"
  }' | jq '.' >"${tmp_jq_output_file}"
  if [[ -n "${user_tag}" ]]; then
    jq '.user_tag = '"$(echo ''"${user_tag}"'' | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
    mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
  fi
  if [[ -n "${user_pre_note}" ]]; then
    jq '.user_pre_note = '"$(echo ''"${user_pre_note}"'' | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
    mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
  fi
  jq '.cmd = '"$(cat "${cmd_file}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
  mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
  jq '.exit_code = '"$(cat "${exit_code_file}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
  mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
  # Important: we have no control over what bytes are sent to stdout/stderr, so we must
  # assume that binary content is in play and avoid piping to jq's encoder directly. Hence the mv operation.
  # Remember, that no matter what happens we'll save at least the exit code, command, and id which means
  # even if this rag command fails after we move the files, we'll have a record with an id that
  # points to the stdout/stderr files.
  # It's up to post-processing tools to make sense of whether or not the stdout/stderr files contain binary
  # content. But that's pretty easy to do by simply inspecting the command that was run.
  mv "${stdout_file}" "${__profile_rag__std_dir}/${rag_id}.stdout"
  mv "${stderr_file}" "${__profile_rag__std_dir}/${rag_id}.stderr"
  jq '.stderr_rag = '"$(cat "${stderr_captured_file}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
  mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
  jq '.stdout_rag = '"$(cat "${stdout_captured_file}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
  mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
  if [[ ${should_collect_post_note} = true ]]; then
    local user_post_note="$(gum_bin input --placeholder "Post-run note:" || echo "${__profile_rag__sigexit}")"
    if [[ ${user_post_note} != "${__profile_rag__sigexit}" ]]; then
      jq '.user_post_note = '"$(echo "${user_post_note}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
      mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
    fi
  fi
  __profile_rag__fn__save_output "${tmp_jq_output_file}"
}

__profile_rag__fn__run() {
  local cmd="${1}"
  if [[ ${cmd} = "rag logs" ]]; then
    local line_count="$(wc -l <"${__profile_rag__logs_dir}/commands.log")"
    code -g "${__profile_rag__logs_dir}/commands.log:${line_count}"
    return 0
  fi

  mkdir -p "${__profile_rag__tmp_dir}"
  local stdout_file="${__profile_rag__tmp_dir}/.stdout"
  local stderr_file="${__profile_rag__tmp_dir}/.stderr"
  local cmd_file="${__profile_rag__tmp_dir}/.cmd"
  local exit_code_file="${__profile_rag__tmp_dir}/.exit_code"
  local stdout_captured_file="${__profile_rag__tmp_dir}/.stdout_captured"
  local stderr_captured_file="${__profile_rag__tmp_dir}/.stderr_captured"
  local rag_id="$(date +%s%N)"
  local return_code=1
  {
    local tty_descriptor="$(tty)"
    rm -f \
      "${stdout_file}" \
      "${stderr_file}" \
      "${cmd_file}" \
      "${stdout_captured_file}" \
      "${stderr_captured_file}"
    touch \
      "${stdout_file}" \
      "${stderr_file}" \
      "${stdout_captured_file}" \
      "${stderr_captured_file}"
    echo "${return_code}" >"${exit_code_file}"
    echo "${cmd}" >"${cmd_file}"
    exec \
      > >(tee >(grep "^\[RAG\]" >>"${stdout_captured_file}" >/dev/null) "${stdout_file}") \
      2> >(tee >(grep "^\[RAG\]" >>"${stderr_captured_file}" >/dev/null) "${stderr_file}" >&2)
    # Bind the command to the tty descriptor so that we can read from it.
    # Important for commands that require user input.
    if eval "${cmd}" <>"${tty_descriptor}" 2<>"${tty_descriptor}"; then
      return_code="${?}"
    fi
    echo "${return_code}" >"${exit_code_file}"
  } | cat
  shift
  __profile_rag__fn__digest "${rag_id}" "$@"
  return ${return_code}
}

__profile_rag__fn__trap() {
  if [[ ${BASH_COMMAND} = "__profile_rag__trap_gate_open=t" ]]; then
    return 0
  fi
  # Ensure no recursive funkyness.
  trap - DEBUG
  # If the COMP_LINE is set, then we know that the user is in the middle of typing a command.
  if [[ -n "${COMP_LINE}" ]]; then
    trap '__profile_rag__fn__trap' DEBUG
    return 0
  fi
  local tty_descriptor="$(tty)"
  # Will include the entire string we submitted to the shell prompt.
  # Pipes, operators, and all.
  local submitted_cmd_prompt="$(history 1 | tr -s " " | cut -d" " -f3-)"
  # Anything that we prefix with '- ' should skip all the RAG logic.
  if [[ ${submitted_cmd_prompt} = "- "* ]]; then
    unset __profile_rag__trap_gate_open
    eval "$(echo "${submitted_cmd_prompt}" | tr -s ' ' | cut -d' ' -f2-)" <>"${tty_descriptor}" 2<>"${tty_descriptor}"
    trap '__profile_rag__fn__trap' DEBUG
    return 1
  fi
  # When the gate is set, we proceed. We do this because when we enter a prompt like this:
  # ls | grep "foo" | less, we would normally hit this trap function 3 times, one for each command.
  # But what we really want is to hit the trap once for all the piped commands and execute them all
  # at once so that we can intelligently capture the output of the total command.
  if [[ -n "${__profile_rag__trap_gate_open+set}" ]]; then
    # So using the example above, when we issue the command `ls | grep "foo" | less`, the "ls"
    # command will hit this first. By immediately setting the gate to false, we ensure that when the
    # grep and less commands hit this trap function, we'll skip them.
    unset __profile_rag__trap_gate_open

    # The rules for the preexec return code:
    # 0: the rag trap will immediately eval the prompt as is and avoid all tracking/capture logic.
    # 1: pass the prompt to the rag function for execution and output capturing.
    # 150: the prompt was already evaluated successfully in `preexec`
    # 151: the preexec script failed for the working directory that the command was run in
    # all other codes: unexpected error, fail and don't run rag logic
    #
    # Reminder: in the vast majority of cases, we expect already_returned_code to be
    # empty and the prompt to be run by rag.

    # Perform any preexec functions that the user has defined.
    local already_returned_code=""
    local preexecs=()
    if [[ ! -z "${user_preexecs:-}" ]]; then
      preexecs=("${user_preexecs[@]}")
    fi
    if [[ -n ${preexecs[@]} ]]; then
      for preexec_fn in "${preexecs[@]}"; do
        if ! "${preexec_fn}" "${submitted_cmd_prompt}" 2>&1 | tee >/dev/tty | cat - 1>/dev/null 2>/dev/null; then
          already_returned_code="1"
          break
        fi
      done
    fi

    # Perform the internal preexec logic which walks up the directory tree starting at
    # the PWD and looks for a `solos.preexec.sh` file. It will then run each script from
    # the highest directory to the lowest.
    __profile_rag__fn__preexec "${submitted_cmd_prompt}" 2>&1 | tee >/dev/tty | cat - 1>/dev/null 2>/dev/null
    preexec_return="${PIPESTATUS[0]}"
    if [[ ${preexec_return} -eq 0 ]]; then
      eval "${submitted_cmd_prompt}" <>"${tty_descriptor}" 2<>"${tty_descriptor}"
      already_returned_code="${?}"
    elif [[ ${preexec_return} -eq 151 ]]; then
      echo "Aborting command execution due to failed internal preexec" >&2
      already_returned_code="1"
    elif [[ ${preexec_return} -eq 150 ]]; then
      already_returned_code="0"
    elif [[ ${preexec_return} -ne 1 ]]; then
      echo "Unexpected error: preexec returned an unhandled code: ${preexec_return}" >&2
      already_returned_code="${preexec_return}"
    fi

    # If we set already_returned_code to any value that's our way of saying, "hey something happened
    # so don't actually run the command." Think pre-exec failures, commands that opt-out of tracking,
    # etc.
    if [[ -z "${already_returned_code}" ]]; then
      __profile_rag__fn__run "${submitted_cmd_prompt}"
    fi
    local postexecs=()
    if [[ ! -z "${user_postexecs:-}" ]]; then
      postexecs=("${user_postexecs[@]}")
    fi
    if [[ -n ${postexecs[@]} ]]; then
      for postexec_fn in "${postexecs[@]}"; do
        "${postexec_fn}" "${submitted_cmd_prompt}" 2>&1 | tee >/dev/tty | cat - 1>/dev/null 2>/dev/null || true
      done
    fi
  fi

  # Finally reset the trap since we're all done and make sure the original command
  # that was trapped is skipped.
  trap '__profile_rag__fn__trap' DEBUG
  return 1
}

__profile_rag__fn__install() {
  __profile_rag__fn__init_fs
  PROMPT_COMMAND='__profile_rag__trap_gate_open=t'
  trap '__profile_rag__fn__trap' DEBUG
}

__profile_rag__fn__prompt_tag() {
  local newline=$'\n'
  local tags="$(cat "${__profile_rag__config_dir}/tags")"
  local tags_file=""
  local i=0
  while IFS= read -r line; do
    if [[ -n "${line}" ]]; then
      if [[ ${i} -gt 0 ]]; then
        tags_file+="${newline}${line}"
      else
        tags_file+="${line}"
      fi
      i=$((i + 1))
    fi
  done <<<"${tags}"
  local tag_choice="$(echo "${tags_file}" | gum_bin choose --limit 1 || echo "${__profile_rag__sigexit}")"
  if [[ ${tag_choice} = "<none>" ]] || [[ -z ${tag_choice} ]]; then
    echo ""
  elif [[ ${tag_choice} = "<create>" ]]; then
    local new_tag="$(gum_bin input --placeholder "Type new tag" || echo "")"
    if [[ -n "${new_tag}" ]]; then
      sed -i '1s/^/'"${new_tag}"'\n/' "${__profile_rag__config_dir}/tags"
      echo "${new_tag}"
    else
      __profile_rag__fn__prompt_tag
    fi
  else
    echo "${tag_choice}"
  fi
}
__profile_rag__fn__main() {
  local no_more_opts=false
  local opt_command_only=false
  local opt_tag_only=false
  local opt_note_only=false
  while [[ ${no_more_opts} = false ]]; do
    case $1 in
    --help)
      __profile_rag__fn__print_rag_help
      return 0
      ;;
    -c)
      opt_command_only=true
      shift
      ;;
    -t)
      opt_tag_only=true
      shift
      ;;
    -n)
      opt_note_only=true
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      return 1
      ;;
    *)
      no_more_opts=true
      break
      ;;
    esac
  done
  local cmd=""
  if [[ $# > 0 ]]; then
    cmd=''"${*}"''
  fi
  local user_pre_note=""
  if [[ ${opt_tag_only} = false ]]; then
    user_pre_note="$(gum_bin input --placeholder "Type note" || echo "${__profile_rag__sigexit}")"
    if [[ ${user_pre_note} = "${__profile_rag__sigexit}" ]]; then
      return 1
    fi
    if [[ -z ${user_pre_note} ]]; then
      if ! gum_bin confirm --default "Are you sure you don't want to include a note?" --affirmative="Continue" --negative="Cancel"; then
        rag
        return 0
      fi
    fi
    if [[ ${#user_pre_note} -lt 3 ]]; then
      if ! gum_bin confirm --default "Is this note correct: \`${user_pre_note}\`?" --affirmative="Continue" --negative="Cancel"; then
        rag
        return 0
      fi
    fi
  fi
  local user_tag=""
  if [[ ${opt_note_only} = false ]]; then
    user_tag="$(__profile_rag__fn__prompt_tag)"
    if [[ ${user_tag} = "${__profile_rag__sigexit}" ]]; then
      return 1
    fi
  fi
  local digest_args=(
    "${user_pre_note}"
    "${user_tag}"
    true # tells the digest function to collect a post note
  )
  __profile_rag__fn__run ''"${cmd}"'' "${digest_args[@]}"
}
