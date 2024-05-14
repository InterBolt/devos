#!/usr/bin/env bash

__rag__var__PREV_RETURN=()
# A delimiter that SHOULD NEVER CHANGE!
# Used to parse sections of the notes file.
__rag__var__DELIMITER='cca07f6cb9d2e1f8ff1dd8c79d508727'
# A string that internal functions can echo to signal an exit.
# Prefixed for debugging purposes.
__rag__var__SIGEXIT='SOLOS:EXIT:1'
# Initialize the rag directory
__rag__var__RAG_DIR="${HOME}/.solos/rag"
__rag__var__RAG_TAGS="${__rag__var__RAG_DIR}/tags"
__rag__var__RAG_NOTES="${__rag__var__RAG_DIR}/notes"
__rag__var__RAG_CAPTURED="${__rag__var__RAG_DIR}/captured"
mkdir -p "${__rag__var__RAG_DIR}"
if [[ ! -f "${__rag__var__RAG_NOTES}" ]]; then
  touch "${__rag__var__RAG_NOTES}"
fi
if [[ ! -f "${__rag__var__RAG_TAGS}" ]]; then
  echo "<none>" >>"${__rag__var__RAG_TAGS}"
  echo "<create>" >>"${__rag__var__RAG_TAGS}"
fi
if [[ ! -f "${__rag__var__RAG_CAPTURED}" ]]; then
  touch "${__rag__var__RAG_CAPTURED}"
fi

__rag__fn__prompt_tag() {
  local newline=$'\n'
  local tags="$(cat "${__rag__var__RAG_TAGS}")"
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
  local tag_choice="$(echo "${tags_file}" | gum_bin choose --limit 1 || echo "${__rag__var__SIGEXIT}")"
  if [[ ${tag_choice} = "<none>" ]] || [[ -z ${tag_choice} ]]; then
    echo ""
  elif [[ ${tag_choice} = "<create>" ]]; then
    local new_tag="$(gum_bin input --placeholder "Type new tag" || echo "")"
    if [[ -n "${new_tag}" ]]; then
      sed -i '1s/^/'"${new_tag}"'\n/' "${__rag__var__RAG_TAGS}"
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

See rag directory: ${__rag__var__RAG_DIR}

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
  local match_string="$1"
  local iter="${2:-"1"}"
  if [[ ${iter} = 1 ]]; then
    __rag__var__PREV_RETURN=()
  fi
  local block_start_line="${iter}"
  if [[ ${block_start_line} -gt 1 ]]; then
    block_start_line=$(("$(grep -n "${__rag__var__DELIMITER}" "${__rag__var__RAG_NOTES}" | sed -n "$((iter - 1))p" | cut -d: -f1)"))
  fi
  local block_close_line=$(("$(grep -n "${__rag__var__DELIMITER}" "${__rag__var__RAG_NOTES}" | sed -n "$((iter))p" | cut -d: -f1)"))
  local is_last=false
  if [[ ${block_close_line} -eq 0 ]]; then
    block_close_line=$(wc -l <"${__rag__var__RAG_NOTES}" | xargs)
    is_last=true
  fi

  local found_match=false
  local newline=$'\n'
  local block_lines=""
  local i=0
  while IFS= read -r line; do
    if [[ ${line} = *"${__rag__var__DELIMITER}"* ]]; then
      continue
    fi
    if [[ ${i} -gt 0 ]]; then
      block_lines+="${newline}${line}"
    else
      block_lines+="${line}"
    fi
    i=$((i + 1))
    if [[ ${line} = *"${match_string}"* ]]; then
      found_match=true
    fi
  done < <(sed -n "${block_start_line},${block_close_line}p" "${__rag__var__RAG_NOTES}")

  if [[ ${found_match} = true ]]; then
    __rag__var__PREV_RETURN+=("${block_lines}")
  fi
  if [[ ${is_last} = false ]]; then
    __rag__fn__find_rag_note "${match_string}" $((iter + 1))
  else
    for block in "${__rag__var__PREV_RETURN[@]}"; do
      echo "${block}"
    done
    __rag__var__PREV_RETURN=()
  fi
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
  local user_note=""
  if [[ ${opt_tag_only} = false ]] && [[ ${opt_command_only} = false ]]; then
    user_note="$(gum_bin input --placeholder "Type note" || echo "${__rag__var__SIGEXIT}")"
    if [[ ${user_note} = "${__rag__var__SIGEXIT}" ]]; then
      return 1
    fi
    if [[ -z ${user_note} ]]; then
      if ! gum_bin confirm --default "Are you sure you don't want to include a note?" --affirmative="Continue" --negative="Cancel"; then
        rag
        return 0
      fi
    fi
    if [[ ${#user_note} -lt 3 ]]; then
      if ! gum_bin confirm --default "Is this note correct: \`${user_note}\`?" --affirmative="Continue" --negative="Cancel"; then
        rag
        return 0
      fi
    fi
  fi
  local user_tag=""
  if [[ ${opt_note_only} = false ]] && [[ ${opt_command_only} = false ]]; then
    user_tag="$(__rag__fn__prompt_tag)"
    if [[ ${user_tag} = "${__rag__var__SIGEXIT}" ]]; then
      return 1
    fi
  fi
  if [[ ${command_was_supplied} = false ]] && [[ -z ${user_tag} ]] && [[ -z ${user_note} ]] && [[ ${opt_captured_only} = false ]]; then
    echo "No command, tag, or note was supplied. Exiting."
    return 0
  fi
  local loglines=$(wc -l <"${__rag__var__RAG_NOTES}")
  if [[ ${opt_captured_only} = false ]]; then
    if [[ ${loglines} -gt 3 ]]; then
      echo "" >>"${__rag__var__RAG_NOTES}"
      echo "--- ${__rag__var__DELIMITER} ---" >>"${__rag__var__RAG_NOTES}"
    fi
    echo "[ID] $(date +%s%N)" >>"${__rag__var__RAG_NOTES}"
    echo "[DATE] $(date)" >>"${__rag__var__RAG_NOTES}"
    if [[ -n "${user_tag}" ]] && [[ ${opt_command_only} = false ]]; then
      echo "[TAG] ${user_tag}" >>"${__rag__var__RAG_NOTES}"
    fi
    if [[ -n "${user_note}" ]] && [[ ${opt_command_only} = false ]]; then
      echo "[NOTE] ${user_note}" >>"${__rag__var__RAG_NOTES}"
    fi
    if [[ ${command_was_supplied} = true ]]; then
      echo "[COMMAND] ${*}" >>"${__rag__var__RAG_NOTES}"
      echo "[OUTPUT]" >>"${__rag__var__RAG_NOTES}"
      # Capture some output: the note/tag > notes file, and any stdout lines that start with [RAG] > captured file.
      # Paranoid note: I filter the delimiter from the output before saving the notes file.
      # Since the delimiter is a hash, I only expect to remove it when somehow the source code
      # for this script makes its way into the output.
      eval "${cmd}" |
        tee -a >(grep "^\[RAG\]" >>"${__rag__var__RAG_CAPTURED}") >(sed "s/${__rag__var__DELIMITER}//g" >>"${__rag__var__RAG_NOTES}")
      local post_run_note="$(gum_bin input --placeholder "Post-run note:" || echo "${__rag__var__SIGEXIT}")"
      if [[ ${post_run_note} = "${__rag__var__SIGEXIT}" ]]; then
        return 1
      elif [[ -n "${post_run_note}" ]]; then
        echo "[POST] ${post_run_note}" >>"${__rag__var__RAG_NOTES}"
      fi
    fi
  else
    eval "${cmd}" |
      tee -a >(grep "^\[RAG\]" >>"${__rag__var__RAG_CAPTURED}")
  fi
}
