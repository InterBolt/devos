#!/usr/bin/env bash

shopt -s extdebug

__profile_rag__gum_sigexit='SOLOS:EXIT:1'
# Rag logs don't need their own directory, place them in the shared logs folder for simpler processing.
__profile_rag__logs_dir="${HOME}/.solos/logs"
# Store state that is specific to RAG.
__profile_rag__rag_dir="${HOME}/.solos/rag"
__profile_rag__rag_config_dir="${__profile_rag__rag_dir}/config"
__profile_rag__rag_std_dir="${__profile_rag__rag_dir}/std"
__profile_rag__rag_tmp_dir="${__profile_rag__rag_dir}/tmp"

# Make sure that control-c will cancel the running command while also reseting the trap.
trap 'trap "__profile_rag__fn__trap" DEBUG; exit 1;' SIGINT

__profile_rag__get_blacklist() {
  local blacklist=(
    "source"
    "."
    "exit"
    "logout"
    "cd"
    "clear"
    "code"
    "cp"
    "rm"
    "mv"
    "touch"
    "mktemp"
    "mkdir"
    "rmdir"
    "ls"
    "pwd"
    "cat"
    "man"
    "help"
    "sleep"
    "uname"
  )
  for cmd in ${__profile_bashrc__pub_fns}; do
    blacklist+=("${cmd}")
  done
  echo "${blacklist[*]}"
}

__profile_rag__fn__print_help() {
  cat <<EOF

USAGE: rag [options] <command> | rag logs

DESCRIPTION:

Prompts the user to write a note. Any positional arguments supplied that are not \
valid options will be executed as a command. The output of the command is recorded \
along with the note for future reference.

The name "rag" was chosen because the notes we take along with the commands \
and their output will aid in a retrieval augmentation generation (RAG) system.

config: ${__profile_rag__rag_config_dir}
logs: ${__profile_rag__logs_dir}
output: ${__profile_rag__rag_tmp_dir}

OPTIONS:

-n               Note only. Will not prompt for a tag.
-t               Tag only. Will not prompt for a note.
-c               Command only. Will not prompt for a note or a tag. Overrides -t and -n.

--help           Print this help message.

EOF
}

__profile_rag__fn__init_fs() {
  mkdir -p "${__profile_rag__rag_config_dir}"
  mkdir -p "${__profile_rag__logs_dir}"
  mkdir -p "${__profile_rag__rag_std_dir}"
  if [[ ! -f "${__profile_rag__rag_config_dir}/tags" ]]; then
    {
      echo "<none>"
      echo "<create>"
    } >"${__profile_rag__rag_config_dir}/tags"
  fi
}

__profile_rag__fn__disgest_save() {
  local tmp_jq_output_file="$1"
  jq -c '.' <"${tmp_jq_output_file}" >>"${__profile_rag__logs_dir}/rag.log"
  rm -f "${tmp_jq_output_file}"
}

__profile_rag__fn__create_tmp_files() {
  rm -rf "${__profile_rag__rag_tmp_dir}"
  mkdir -p "${__profile_rag__rag_tmp_dir}"

  local stdout_file="${__profile_rag__rag_tmp_dir}/stdout"
  local stderr_file="${__profile_rag__rag_tmp_dir}/stderr"
  local cmd_file="${__profile_rag__rag_tmp_dir}/cmd"
  local return_code_file="${__profile_rag__rag_tmp_dir}/return_code"
  local stderr_rag_file="${__profile_rag__rag_tmp_dir}/stderr_rag"
  local stdout_rag_file="${__profile_rag__rag_tmp_dir}/stdout_rag"

  rm -f \
    "${stdout_file}" \
    "${stderr_file}" \
    "${cmd_file}" \
    "${return_code_file}" \
    "${stdout_rag_file}" \
    "${stderr_rag_file}"

  touch \
    "${stdout_file}" \
    "${stderr_file}" \
    "${cmd_file}" \
    "${return_code_file}" \
    "${stdout_rag_file}" \
    "${stderr_rag_file}"
}

__profile_rag__fn__digest() {
  local rag_id="${1:-""}"
  local user_note="${2:-""}"
  local user_tag="${3:-""}"
  local should_collect_post_note="${3:-false}"

  local stdout_file="${__profile_rag__rag_tmp_dir}/stdout"
  local stderr_file="${__profile_rag__rag_tmp_dir}/stderr"
  local cmd_file="${__profile_rag__rag_tmp_dir}/cmd"
  local return_code_file="${__profile_rag__rag_tmp_dir}/return_code"

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
  # If the user did not supply a command, they are probably just taking a note via
  # the "rag" command. In this case, only build the json that applies to the notes
  # so that it's more obvious in post processing that no command was run.
  local cmd="$(cat "${cmd_file}" | jq -R -s '.')"
  if [[ -n "${cmd}" ]]; then
    jq '.cmd = '"${cmd}"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
    mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
    jq '.return_code = '"$(cat "${return_code_file}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
    mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
    # We have no control over what bytes are sent to stdout/stderr, so we must
    # assume that binary content is in play and avoid piping to jq's encoder directly.
    # Ex: some image processing tools will output binary data to stdout/stderr.
    mv "${stdout_file}" "${__profile_rag__rag_std_dir}/${rag_id}.out"
    mv "${stderr_file}" "${__profile_rag__rag_std_dir}/${rag_id}.err"
    if [[ ${should_collect_post_note} = true ]]; then
      local user_post_note="$(gum_bin input --placeholder "Post-run note:" || echo "${__profile_rag__gum_sigexit}")"
      if [[ ${user_post_note} != "${__profile_rag__gum_sigexit}" ]]; then
        jq '.user_post_note = '"$(echo "${user_post_note}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
        mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
      fi
    fi
  fi
  __profile_rag__fn__disgest_save "${tmp_jq_output_file}"
}

__profile_rag__fn__trap_eval() {
  local rag_id="${1}"
  local cmd="${2}"

  local stdout_file="${__profile_rag__rag_tmp_dir}/stdout"
  local stderr_file="${__profile_rag__rag_tmp_dir}/stderr"
  local cmd_file="${__profile_rag__rag_tmp_dir}/cmd"
  local return_code_file="${__profile_rag__rag_tmp_dir}/return_code"
  local return_code=1
  echo "${return_code}" >"${return_code_file}"
  {
    local tty_descriptor="$(tty)"
    touch \
      "${stdout_file}" \
      "${stderr_file}"
    echo "${return_code}" >"${return_code_file}"
    if [[ -n ${cmd} ]]; then
      echo "${cmd}" >"${cmd_file}"
    fi
    exec \
      > >(tee "${stdout_file}") \
      2> >(tee "${stderr_file}" >&2)
    if eval ''"${cmd}"'' <>"${tty_descriptor}" 2<>"${tty_descriptor}"; then
      return_code="${?}"
    fi
    echo "${return_code}" >"${return_code_file}"
  } | cat
  return ${return_code}
}

__profile_rag__fn__trap_preexec_scripts() {
  local prompt="${1}"

  # Avoid rag/tracking stuff for blacklisted commands.
  # Ex: all pub_* functions in the bashrc will be blacklisted.
  local blacklist="$(__profile_rag__get_blacklist | xargs)"
  for opt_out in ${blacklist}; do
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
    if ! "${preexec_script}" >"${tty_descriptor}" 2>&1; then
      return 151
    fi
  done

  return 1
}
__profile_rag__fn__trap() {
  # Prevent the trap from applying to the PROMPT_COMMAND script.
  if [[ ${BASH_COMMAND} = "__profile_rag__trap_gate_open=t" ]]; then
    return 0
  fi

  # Prevent recursive bugs.
  trap - DEBUG

  # The existence of the COMP_LINE variable implies that a bash completion is taking place.
  if [[ -n "${COMP_LINE}" ]]; then
    trap '__profile_rag__fn__trap' DEBUG
    return 0
  fi

  # Consider the prompt: `ls | grep "foo" | less`:
  # In a normal DEBUG trap, this prompt would trigger three trap invocations, one per - ls, grep, and less.
  # But what we really want is to hit the trap one time for the *entire* set of commands.
  # To do this, we unset some arbitrary variable on the first trapped command, ie - our 'ls'
  # command, so that all other piped commands will not execute until the arbitrary variable is set again.
  # And since the arbitrary variable will not get reset until the next prompt is submitted, we can be sure
  # that the trap will only be hit once per prompt.
  if [[ -n "${__profile_rag__trap_gate_open+set}" ]]; then
    unset __profile_rag__trap_gate_open

    if [[ -n "${__profile_bashrc__loaded_project}" ]]; then
      local checked_out_project="$(cat "${HOME}/.solos/store/checked_out_project" 2>/dev/null || echo "" | head -n 1)"
      if [[ "${__profile_bashrc__loaded_project}" != "${checked_out_project}" ]]; then
        echo "You have changed projects (${__profile_bashrc__loaded_project} => ${checked_out_project}) and your shell is no longer up to date." >&2
        echo "Please exit and re-open your terminal." >&2
        trap '__profile_rag__fn__trap' DEBUG
        return 1
      fi
    fi

    # Pretty sure eval'd commands don't get a tty so we have to manually attach it.
    local tty_descriptor="$(tty)"

    # Remember: $BASH_COMMAND is only going to be the first command in any set of piped commands.
    # So instead of using $BASH_COMMAND, we'll use the history command to get the entire prompt.
    local submitted_prompt="$(history 1 | tr -s " " | cut -d" " -f3-)"

    # Using the "-" prefix tells our shell to skip the trap logic below and run as is. Useful if
    # something goes awry and we need to quickly determine whether or not the trap logic is the issue.
    if [[ ${submitted_prompt} = "- "* ]]; then
      eval "$(echo "${submitted_prompt}" | tr -s ' ' | cut -d' ' -f2-)" <>"${tty_descriptor}" 2<>"${tty_descriptor}"
      trap '__profile_rag__fn__trap' DEBUG
      return 1
    fi

    # Run user defined preexec functions. If any of them fail, return with the exit code
    # and skip the rest of the trap logic, including the remaining preexec functions.
    local preexecs=()
    if [[ ! -z "${user_preexecs:-}" ]]; then
      preexecs=("${user_preexecs[@]}")
    fi
    if [[ -n ${preexecs[@]} ]]; then
      for preexec_fn in "${preexecs[@]}"; do
        # Fail early since the submitted cmd could depend on setup stuff in preexecs.
        if ! "${preexec_fn}" "${submitted_prompt}" >"${tty_descriptor}" 2>&1; then
          local failed_return_code="${?}"
          trap '__profile_rag__fn__trap' DEBUG
          return "${failed_return_code}"
        fi
      done
    fi

    # Execute the preexec scripts associated with the user's working directory.
    # These scripts run in the order of their directory structures, where parents
    # are executed first and children are executed last.
    __profile_rag__fn__trap_preexec_scripts "${submitted_prompt}" >"${tty_descriptor}" 2>&1
    local preexec_return="${PIPESTATUS[0]}"
    local should_skip_rag=false
    # 0 - implies that we are running a blacklisted command and should skip the rag tracking.
    if [[ ${preexec_return} -eq 0 ]]; then
      eval "${submitted_prompt}" <>"${tty_descriptor}" 2<>"${tty_descriptor}"
      should_skip_rag=true
    # 151 - implies that one of the preexec scripts failed.
    elif [[ ${preexec_return} -eq 151 ]]; then
      should_skip_rag=true
    # Internal error so we should not proceed.
    elif [[ ${preexec_return} -ne 1 ]]; then
      echo "Unexpected error: preexec returned an unhandled code: ${preexec_return}" >&2
      trap '__profile_rag__fn__trap' DEBUG
      return "${preexec_return}"
    fi

    # Initialize the tmp files, evaluate the submitted command, and digest the results.
    if [[ ${should_skip_rag} = false ]]; then
      local rag_id="$(date +%s%N)"
      __profile_rag__fn__create_tmp_files
      __profile_rag__fn__trap_eval "${rag_id}" "${submitted_prompt}"
      __profile_rag__fn__digest "${rag_id}"
    fi

    # User defined postexec functions. If one of them fails, do not execute the rest.
    # But don't allow a failure to revise the final return code.
    local postexecs=()
    if [[ ! -z "${user_postexecs:-}" ]]; then
      postexecs=("${user_postexecs[@]}")
    fi
    if [[ -n ${postexecs[@]} ]]; then
      for postexec_fn in "${postexecs[@]}"; do
        if ! "${postexec_fn}" "${submitted_prompt}" >"${tty_descriptor}" 2>&1; then
          break
        fi
      done
    fi
  fi

  # All done, reset the trap and ensure $BASH_COMMAND does not execute.
  trap '__profile_rag__fn__trap' DEBUG
  return 1
}
__profile_rag__fn__install() {
  # Make sure that if the user messes with the PROMPT_COMMAND or debug trap that we
  # fail in an obvious way. If they need these things, the best path forward is to
  # not install the SolOS shell. Not great, but it's the best we can do.
  if [[ -n "${PROMPT_COMMAND}" ]]; then
    echo "PROMPT_COMMAND is already set. Will not track command outputs." >&2
    return 1
  fi
  if [[ "$(trap -p DEBUG)" != "" ]]; then
    echo "DEBUG trap is already set. Will not track command outputs." >&2
    return 1
  fi
  __profile_rag__fn__init_fs
  PROMPT_COMMAND='__profile_rag__trap_gate_open=t'
  trap '__profile_rag__fn__trap' DEBUG
}
__profile_rag__fn__apply_tag() {
  local newline=$'\n'
  local tags="$(cat "${__profile_rag__rag_config_dir}/tags")"
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
  local tag_choice="$(echo "${tags_file}" | gum_bin choose --limit 1 || echo "${__profile_rag__gum_sigexit}")"
  if [[ ${tag_choice} = "<none>" ]] || [[ -z ${tag_choice} ]]; then
    echo ""
  elif [[ ${tag_choice} = "<create>" ]]; then
    local new_tag="$(gum_bin input --placeholder "Type new tag" || echo "")"
    if [[ -n "${new_tag}" ]]; then
      sed -i '1s/^/'"${new_tag}"'\n/' "${__profile_rag__rag_config_dir}/tags"
      echo "${new_tag}"
    else
      __profile_rag__fn__apply_tag
    fi
  else
    echo "${tag_choice}"
  fi
}
# This is the "rag" function implementation.
__profile_rag__fn__main() {
  local no_more_opts=false
  local opt_command_only=false
  local opt_tag_only=false
  local opt_note_only=false
  while [[ ${no_more_opts} = false ]]; do
    case $1 in
    --help)
      __profile_rag__fn__print_help
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
    user_pre_note="$(gum_bin input --placeholder "Type note" || echo "${__profile_rag__gum_sigexit}")"
    if [[ ${user_pre_note} = "${__profile_rag__gum_sigexit}" ]]; then
      return 1
    fi
  fi
  local user_tag=""
  if [[ ${opt_note_only} = false ]]; then
    user_tag="$(__profile_rag__fn__apply_tag)"
    if [[ ${user_tag} = "${__profile_rag__gum_sigexit}" ]]; then
      return 1
    fi
  fi
  local digest_args=(
    "${user_pre_note}"
    "${user_tag}"
    true # tells the digest function to collect a post note
  )
  __profile_rag__fn__create_tmp_files
  local rag_id="$(date +%s%N)"
  if [[ -n "${cmd}" ]]; then
    __profile_rag__fn__trap_eval "${rag_id}" "${cmd}"
  fi
  __profile_rag__fn__digest "${rag_id}" "${digest_args[@]}"
}
