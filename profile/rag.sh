#!/usr/bin/env bash

shopt -s extdebug

__rag__var__sigexit='SOLOS:EXIT:1'
__rag__var__dir="${HOME}/.solos/rag"
__rag__var__config_dir="${__rag__var__dir}/config"
__rag__var__logs_dir="${__rag__var__dir}/logs"
__rag__var__std_dir="${__rag__var__dir}/std"
__rag__var__tmp_dir="${__rag__var__dir}/tmp"

__rag__fn__print_rag_help() {
  cat <<EOF

USAGE: rag [options] <command> | rag logs

DESCRIPTION:

Prompts the user to write a note. Any positional arguments supplied that are not \
valid options will be executed as a command. The output of the command is recorded \
along with the note for future reference.

The name "rag" was chosen because the notes we take along with the commands \
and their output will aid in a retrieval augmentation generation (RAG) system.

config: ${__rag__var__config_dir}
logs: ${__rag__var__logs_dir}
output: ${__rag__var__tmp_dir}

OPTIONS:

-n               Note only. Will not prompt for a tag.
-t               Tag only. Will not prompt for a note.
-c               Command only. Will not prompt for a note or a tag. Overrides -t and -n.

--help           Print this help message.

EOF
}

__rag__fn__init_fs() {
  mkdir -p "${__rag__var__config_dir}"
  mkdir -p "${__rag__var__logs_dir}"
  mkdir -p "${__rag__var__tmp_dir}"
  mkdir -p "${__rag__var__std_dir}"
  if [[ ! -f "${__rag__var__config_dir}/tags" ]]; then
    {
      echo "<none>"
      echo "<create>"
    } >"${__rag__var__config_dir}/tags"
  fi
}

__rag__fn__save_output() {
  local tmp_jq_output_file="$1"
  jq -c '.' <"${tmp_jq_output_file}" >>"${__rag__var__logs_dir}/commands.log"
  rm -f "${tmp_jq_output_file}"
  rm -rf "${__rag__var__tmp_dir}"
}

# Rules:
# - return 1 = execute the command while capturing everything
# - return 0 = execute the command without capturing anything
# - return 150 = we ran the command as is
# - return 151 = the preexec script failed before we could run the command
__rag__fn__preexec() {
  local prompt="${1}"

  # When the '- ' prefix is supplied in the SolOS shell prompt,
  # it means we want to avoid any and all preexec logic and run the thing as is
  # TODO: fix - doesn't this mask the true error code of the command?
  if [[ ${prompt} = "- "* ]]; then
    prompt="$(echo "${prompt}" | xargs | cut -d' ' -f2-)"
    eval "${prompt}"
    return 150
  fi

  # We have a list of commands (might need to add lots more idk) that we know
  # should never be captured, tracked, logged, you name it. Run them as is.
  # Think `clear`, working dir changes like cd, `exit`, that kind of thing.
  # Important: if a pipe operator exists, all bets are off and we assume that we
  # want to capture the output.
  for opt_out in "${__bashrc__var__preexec_dont_track_or_fuck_with_these[@]}"; do
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
    if [[ -f "${next_dir}/solos.exec.sh" ]]; then
      preexec_scripts=("${next_dir}/solos.exec.sh" "${preexec_scripts[@]}")
    fi
    next_dir="$(dirname "${next_dir}")"
  done
  for preexec_script in "${preexec_scripts[@]}"; do
    if ! "${preexec_script}"; then
      return 151
    fi
  done

  return 1
}

__rag__fn__digest() {
  local user_note="${1:-""}"
  local user_tag="${2:-""}"
  local should_collect_post_note="${3:-false}"

  local stdout_file="${__rag__var__tmp_dir}/.stdout"
  local stderr_file="${__rag__var__tmp_dir}/.stderr"
  local cmd_file="${__rag__var__tmp_dir}/.cmd"
  local exit_code_file="${__rag__var__tmp_dir}/.exit_code"
  local stdout_captured_file="${__rag__var__tmp_dir}/.stdout_captured"
  local stderr_captured_file="${__rag__var__tmp_dir}/.stderr_captured"

  local tmp_jq_output_file="$(mktemp)"
  local rag_id="$(date +%s%N)"
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
  mv "${stdout_file}" "${__rag__var__std_dir}/${rag_id}.stdout"
  mv "${stderr_file}" "${__rag__var__std_dir}/${rag_id}.stderr"
  jq '.stderr_rag = '"$(cat "${stderr_captured_file}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
  mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
  jq '.stdout_rag = '"$(cat "${stdout_captured_file}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
  mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
  if [[ ${should_collect_post_note} = true ]]; then
    local user_post_note="$(gum_bin input --placeholder "Post-run note:" || echo "${__rag__var__sigexit}")"
    if [[ ${user_post_note} != "${__rag__var__sigexit}" ]]; then
      jq '.user_post_note = '"$(echo "${user_post_note}" | jq -R -s '.')"'' "${tmp_jq_output_file}" >"${tmp_jq_output_file}.tmp"
      mv "${tmp_jq_output_file}.tmp" "${tmp_jq_output_file}"
    fi
  fi
  __rag__fn__save_output "${tmp_jq_output_file}"
}

__rag__fn__run() {
  local cmd="${1}"
  if [[ ${cmd} = "rag logs" ]]; then
    local line_count="$(wc -l <"${__rag__var__logs_dir}/commands.log")"
    code -g "${__rag__var__logs_dir}/commands.log:${line_count}"
    return 0
  fi

  mkdir -p "${__rag__var__tmp_dir}"
  local stdout_file="${__rag__var__tmp_dir}/.stdout"
  local stderr_file="${__rag__var__tmp_dir}/.stderr"
  local cmd_file="${__rag__var__tmp_dir}/.cmd"
  local exit_code_file="${__rag__var__tmp_dir}/.exit_code"
  local stdout_captured_file="${__rag__var__tmp_dir}/.stdout_captured"
  local stderr_captured_file="${__rag__var__tmp_dir}/.stderr_captured"
  local return_code=1
  {
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
      > >(tee >(grep "^\[RAG\]" >>"${stdout_captured_file}") "${stdout_file}") \
      2> >(tee >(grep "^\[RAG\]" >>"${stderr_captured_file}") "${stderr_file}" >&2)
    eval "${1}"
    return_code="${?}"
    echo "${return_code}" >"${exit_code_file}"
  } | cat
  shift
  __rag__fn__digest "$@"
  return ${return_code}
}

__rag__fn__trap() {
  if [[ "${BASH_COMMAND}" = "__rag__var__detected_grouped_commands=true" ]]; then
    return 0
  fi
  if [[ -n "${__rag__var__detected_grouped_commands+set}" ]]; then
    unset __rag__var__detected_grouped_commands
    trap - DEBUG
    local prompt="$(history 1 | xargs | cut -d' ' -f2-)"
    # The rules for the preexec return code:
    # 0: the rag trap will immediately eval the prompt as is and avoid all tracking/capture logic.
    # 1: pass the prompt to the rag function for execution and output capturing.
    # 150: the prompt was already evaluated successfully in `preexec`
    # 151: the preexec script failed for the working directory that the command was run in
    # all other codes: unexpected error, fail and don't run rag logic
    #
    # Reminder: in the vast majority of cases, we expect already_returned_code to be
    # empty and the prompt to be run by rag.
    local already_returned_code=""
    local preexecs=()
    if [[ ! -z "${user_preexecs:-}" ]]; then
      preexecs=("${user_preexecs[@]}")
    fi
    if [[ -n ${preexecs[@]} ]]; then
      for preexec_fn in "${preexecs[@]}"; do
        if ! "${preexec_fn}" "${prompt}"; then
          already_returned_code="1"
          break
        fi
      done
    fi
    if __rag__fn__preexec "${prompt}"; then
      eval "${prompt}"
      already_returned_code="${?}"
    else
      local preexec_return="${?}"
      if [[ ${preexec_return} = "151" ]]; then
        echo "Aborting command execution due to failed internal preexec" >&2
        already_returned_code="1"
      elif [[ ${preexec_return} = "150" ]]; then
        already_returned_code="0"
      elif [[ ${preexec_return} != "1" ]]; then
        echo "Unexpected error: preexec returned an unhandled code: ${preexec_return}" >&2
        already_returned_code="1"
      fi
    fi
    if [[ -z "${already_returned_code}" ]]; then
      __rag__fn__run "${prompt}"
    fi
    trap '__rag__fn__trap' DEBUG
  fi
  return 1
}

__rag__fn__install() {
  __rag__fn__init_fs
  PROMPT_COMMAND='__rag__var__detected_grouped_commands=true'
  trap '__rag__fn__trap' DEBUG
}

__rag__fn__prompt_tag() {
  local newline=$'\n'
  local tags="$(cat "${__rag__var__config_dir}/tags")"
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
  local tag_choice="$(echo "${tags_file}" | gum_bin choose --limit 1 || echo "${__rag__var__sigexit}")"
  if [[ ${tag_choice} = "<none>" ]] || [[ -z ${tag_choice} ]]; then
    echo ""
  elif [[ ${tag_choice} = "<create>" ]]; then
    local new_tag="$(gum_bin input --placeholder "Type new tag" || echo "")"
    if [[ -n "${new_tag}" ]]; then
      sed -i '1s/^/'"${new_tag}"'\n/' "${__rag__var__config_dir}/tags"
      echo "${new_tag}"
    else
      __rag__fn__prompt_tag
    fi
  else
    echo "${tag_choice}"
  fi
}
__rag__fn__main() {
  local no_more_opts=false
  local opt_command_only=false
  local opt_tag_only=false
  local opt_note_only=false
  while [[ ${no_more_opts} = false ]]; do
    case $1 in
    --help)
      __rag__fn__print_rag_help
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
    user_pre_note="$(gum_bin input --placeholder "Type note" || echo "${__rag__var__sigexit}")"
    if [[ ${user_pre_note} = "${__rag__var__sigexit}" ]]; then
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
    user_tag="$(__rag__fn__prompt_tag)"
    if [[ ${user_tag} = "${__rag__var__sigexit}" ]]; then
      return 1
    fi
  fi
  local digest_args=(
    "${user_pre_note}"
    "${user_tag}"
    true # tells the digest function to collect a post note
  )
  __rag__fn__run ''"${cmd}"'' "${digest_args[@]}"
}
