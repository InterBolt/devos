#!/usr/bin/env bash

__rag__var__prev_return=()
# A string that internal functions can echo to signal an exit.
# Prefixed for debugging purposes.
__rag__var__sigexit='SOLOS:EXIT:1'
# Initialize the rag directory
__rag__var__dir="${HOME}/.solos/rag"
__rag__var__tags="${__rag__var__dir}/tags"
__rag__var__notes="${__rag__var__dir}/notes.log"
__rag__var__captured="${__rag__var__dir}/captured.log"
__rag__var__prev_exit_trap=""
mkdir -p "${__rag__var__dir}"
if [[ ! -f "${__rag__var__notes}" ]]; then
  touch "${__rag__var__notes}"
fi
if [[ ! -f "${__rag__var__tags}" ]]; then
  echo "<none>" >>"${__rag__var__tags}"
  echo "<create>" >>"${__rag__var__tags}"
fi
if [[ ! -f "${__rag__var__captured}" ]]; then
  touch "${__rag__var__captured}"
fi

__rag__fn__prompt_tag() {
  local newline=$'\n'
  local tags="$(cat "${__rag__var__tags}")"
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
      sed -i '1s/^/'"${new_tag}"'\n/' "${__rag__var__tags}"
      echo "${new_tag}"
    else
      __rag__fn__prompt_tag
    fi
  else
    echo "${tag_choice}"
  fi
}
__rag__fn__print_rag_help() {
  cat <<EOF

USAGE: rag [options] <command> | rag notes | rag captured

DESCRIPTION:

Prompts the user to write a note. Any positional arguments supplied that are not \
valid options will be executed as a command. The output of the command is recorded \
along with the note for future reference.

The name "rag" was chosen because the notes we take along with the commands \
and their outputs will aid in a retrieval augmentation generation (RAG) system.

See rag directory: ${__rag__var__dir}

OPTIONS:

-f <match>       Find a specific note via a match string.
-n               Note only. Will not prompt for a tag.
-t               Tag only. Will not prompt for a note.
-c               Command only. Will not prompt for a note or a tag. Overrides -t and -n.

--captured-only  Only capture stdout lines beginning with [RAG].
--help           Print this help message.

EOF
}
__rag__fn__find_rag_note() {
  echo "TODO"
  # local match_string="$1"
  # local iter="${2:-"1"}"
  # if [[ ${iter} = 1 ]]; then
  #   __rag__var__prev_return=()
  # fi
  # local block_start_line="${iter}"
  # if [[ ${block_start_line} -gt 1 ]]; then
  #   block_start_line=$(("$(grep -n "${__rag__var__delimiter}" "${__rag__var__notes}" | sed -n "$((iter - 1))p" | cut -d: -f1)"))
  # fi
  # local block_close_line=$(("$(grep -n "${__rag__var__delimiter}" "${__rag__var__notes}" | sed -n "$((iter))p" | cut -d: -f1)"))
  # local is_last=false
  # if [[ ${block_close_line} -eq 0 ]]; then
  #   block_close_line=$(wc -l <"${__rag__var__notes}" | xargs)
  #   is_last=true
  # fi

  # local found_match=false
  # local newline=$'\n'
  # local block_lines=""
  # local i=0
  # while IFS= read -r line; do
  #   if [[ ${line} = *"${__rag__var__delimiter}"* ]]; then
  #     continue
  #   fi
  #   if [[ ${i} -gt 0 ]]; then
  #     block_lines+="${newline}${line}"
  #   else
  #     block_lines+="${line}"
  #   fi
  #   i=$((i + 1))
  #   if [[ ${line} = *"${match_string}"* ]]; then
  #     found_match=true
  #   fi
  # done < <(sed -n "${block_start_line},${block_close_line}p" "${__rag__var__notes}")

  # if [[ ${found_match} = true ]]; then
  #   __rag__var__prev_return+=("${block_lines}")
  # fi
  # if [[ ${is_last} = false ]]; then
  #   __rag__fn__find_rag_note "${match_string}" $((iter + 1))
  # else
  #   for block in "${__rag__var__prev_return[@]}"; do
  #     echo "${block}"
  #   done
  #   __rag__var__prev_return=()
  # fi
}
__rag__fn__save() {
  local jq_output_file="$1"
  local status="$2"
  jq '.status = "'"${status}"'"' "${jq_output_file}" >"${jq_output_file}.tmp"
  mv "${jq_output_file}.tmp" "${jq_output_file}"
  jq -c '.' <"${jq_output_file}" >>"${__rag__var__notes}"
}
__rag__fn__main() {
  local command_was_supplied=false
  local no_more_opts=false
  local opt_captured_only=false
  local opt_command_only=false
  local opt_tag_only=false
  local opt_note_only=false
  while [[ ${no_more_opts} = false ]]; do
    case $1 in
    --help)
      __rag__fn__print_rag_help
      return 0
      ;;
    --captured-only)
      opt_captured_only=true
      opt_command_only=true
      shift
      ;;
    -f)
      __rag__fn__find_rag_note "$2"
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
    *)
      no_more_opts=true
      break
      ;;
    esac
  done
  local cmd=''
  if [[ $# > 0 ]]; then
    command_was_supplied=true
    cmd=''"${*}"''
  fi
  local note_pre=""
  if [[ ${opt_tag_only} = false ]] && [[ ${opt_command_only} = false ]]; then
    note_pre="$(gum_bin input --placeholder "Type note" || echo "${__rag__var__sigexit}")"
    if [[ ${note_pre} = "${__rag__var__sigexit}" ]]; then
      return 1
    fi
    if [[ -z ${note_pre} ]]; then
      if ! gum_bin confirm --default "Are you sure you don't want to include a note?" --affirmative="Continue" --negative="Cancel"; then
        rag
        return 0
      fi
    fi
    if [[ ${#note_pre} -lt 3 ]]; then
      if ! gum_bin confirm --default "Is this note correct: \`${note_pre}\`?" --affirmative="Continue" --negative="Cancel"; then
        rag
        return 0
      fi
    fi
  fi
  local user_tag=""
  if [[ ${opt_note_only} = false ]] && [[ ${opt_command_only} = false ]]; then
    user_tag="$(__rag__fn__prompt_tag)"
    if [[ ${user_tag} = "${__rag__var__sigexit}" ]]; then
      return 1
    fi
  fi
  if [[ ${command_was_supplied} = false ]] && [[ -z ${user_tag} ]] && [[ -z ${note_pre} ]] && [[ ${opt_captured_only} = false ]]; then
    echo "No command, tag, or note was supplied. Exiting."
    return 0
  fi
  local loglines=$(wc -l <"${__rag__var__notes}")
  local jq_output_file="$(mktemp)"
  __rag__var__prev_exit_trap=$(trap -p EXIT)
  trap '__rag__fn__save "'"${jq_output_file}"'" "INCOMPLETE"' EXIT
  echo '{
    "id": "'"$(date +%s%N)"'",
    "date": "'"$(date)"'"
  }' | jq '.' >"${jq_output_file}"
  if [[ -n "${user_tag}" ]]; then
    jq '.tag = '"$(echo ''"${user_tag}"'' | jq -R -s '.')"'' "${jq_output_file}" >"${jq_output_file}.tmp"
    mv "${jq_output_file}.tmp" "${jq_output_file}"
  fi
  if [[ -n "${note_pre}" ]]; then
    jq '.note_pre = '"$(echo ''"${note_pre}"'' | jq -R -s '.')"'' "${jq_output_file}" >"${jq_output_file}.tmp"
    mv "${jq_output_file}.tmp" "${jq_output_file}"
  fi
  if [[ ${command_was_supplied} = true ]]; then
    jq '.cmd = '"$(echo ''"${cmd}"'' | jq -R -s '.')"'' "${jq_output_file}" >"${jq_output_file}.tmp"
    mv "${jq_output_file}.tmp" "${jq_output_file}"
    local tmp_stdout_file="$(mktemp)"
    local tmp_stderr_file="$(mktemp)"
    local cmd_before_time="$(date +%s%N)"
    eval "${cmd}" |
      tee >(grep "^\[RAG\]" >>"${__rag__var__captured}") \
        1>"${tmp_stdout_file}" \
        2>"${tmp_stderr_file}" \
        1>/dev/tty \
        2>/dev/tty
    local cmd_exit_code="$(echo ${PIPESTATUS[0]})"
    local cmd_after_time=$(date +%s%N)
    jq '.cmd_time = '"$(("$((cmd_after_time - cmd_before_time))" / 1000000))"'' "${jq_output_file}" >"${jq_output_file}.tmp"
    mv "${jq_output_file}.tmp" "${jq_output_file}"
    jq '.cmd_exit_code = "'"${cmd_exit_code}"'"' "${jq_output_file}" >"${jq_output_file}.tmp"
    mv "${jq_output_file}.tmp" "${jq_output_file}"
    jq '.cmd_stdout = '"$(cat "${tmp_stdout_file}" | jq -R -s '.')"'' "${jq_output_file}" >"${jq_output_file}.tmp"
    mv "${jq_output_file}.tmp" "${jq_output_file}"
    jq '.cmd_stderr = '"$(cat "${tmp_stderr_file}" | jq -R -s '.')"'' "${jq_output_file}" >"${jq_output_file}.tmp"
    mv "${jq_output_file}.tmp" "${jq_output_file}"
    if [[ ${opt_captured_only} = false ]]; then
      local note_post="$(gum_bin input --placeholder "Post-run note:" || echo "${__rag__var__sigexit}")"
      if [[ ${note_post} != "${__rag__var__sigexit}" ]]; then
        jq '.note_post = '"$(echo "${note_post}" | jq -R -s '.')"'' "${jq_output_file}" >"${jq_output_file}.tmp"
        mv "${jq_output_file}.tmp" "${jq_output_file}"
      fi
    fi
  fi
  if [[ -z ${__rag__var__prev_exit_trap} ]]; then
    trap - EXIT
  else
    eval "${__rag__var__prev_exit_trap}"
  fi
  __rag__fn__save "${jq_output_file}" "COMPLETE"
}
