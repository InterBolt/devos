#!/usr/bin/env bash

shopt -s extdebug

# A delimiter that SHOULD NEVER CHANGE!
# Used to parse sections of the notes file.
__s__SECTION_DELIMITER='cca07f6cb9d2e1f8ff1dd8c79d508727'
# A string that internal functions can echo to signal an exit.
# Prefixed for debugging purposes.
__s__SIGEXIT='SOLOS:SIGEXIT:60854c1d118ce5b9ba7c50996d3b81cb'

# Grab gum by cd'ing into the bin directory and sourcing the source file.
# The cd'ing isn't ideal but I decided to treat ever file in the bin directory
# as if it were being run from the bin directory for simplicity.
__s__BASHRC_ENTRY_DIR="${PWD}"
cd "${HOME}/.solos/src/bin"
source pkg/__source__.sh
cd "${__s__BASHRC_ENTRY_DIR}"

# Initialize the rag directory
__s__RAG_DIR="${HOME}/.solos/rag"
__s__RAG_TAGS="${__s__RAG_DIR}/tags"
__s__RAG_NOTES="${__s__RAG_DIR}/notes"
__s__RAG_CAPTURED="${__s__RAG_DIR}/captured"
mkdir -p "${__s__RAG_DIR}"
if [[ ! -f "${__s__RAG_NOTES}" ]]; then
  touch "${__s__RAG_NOTES}"
fi
if [[ ! -f "${__s__RAG_TAGS}" ]]; then
  echo "none" >>"${__s__RAG_TAGS}"
  echo "create" >>"${__s__RAG_TAGS}"
fi
if [[ ! -f "${__s__RAG_CAPTURED}" ]]; then
  touch "${__s__RAG_CAPTURED}"
fi

__s__prompt_tag() {
  local newline=$'\n'
  local tags="$(cat "${__s__RAG_TAGS}")"
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
  local tag_choice="$(echo "${tags_file}" | pkg.gum choose --limit 1 || echo "${__s__SIGEXIT}")"
  if [[ ${tag_choice} = "none" ]] || [[ -z ${tag_choice} ]]; then
    echo ""
  elif [[ ${tag_choice} = "create" ]]; then
    local new_tag="$(pkg.gum input --placeholder "Type new tag" || echo "")"
    if [[ -n "${new_tag}" ]]; then
      sed -i '1s/^/'"${new_tag}"'\n/' "${__s__RAG_TAGS}"
      echo "${new_tag}"
    else
      __s__prompt_tag
    fi
  else
    echo "${tag_choice}"
  fi
}

__s__print_rag_help() {
  cat <<EOF
Usage: rag [options] ...

Description:
  Prompts the user to write a note. Any positional arguments supplied that are 
  not valid options will be executed as a command. The output of the command is
  recorded along with the note for future reference.
  
  The name "rag" was chosen because the notes we take along with
  the commands we run will aid in a retrieval augmentation generation
  (RAG) system.

  Notes file: ${__s__RAG_NOTES}

Options:
  -f=<match>  Find a specific note via a match string.
  -n          Note only. Will not prompt for a tag.
  -t          Tag only. Will not prompt for a note.
  -c          Command only. Will not prompt for a note or a tag. Overrides -t and -n.
EOF
}

__s__find_rag_note() {
  echo ""
}

rag() {
  local command_was_supplied=false
  local no_more_opts=false
  local opt_command_only=false
  local opt_tag_only=false
  local opt_note_only=false
  while [[ ${no_more_opts} = false ]]; do
    case $1 in
    --help)
      __s__print_rag_help
      return 0
      ;;
    -h)
      __s__print_rag_help
      return 0
      ;;
    -f)
      __s__find_rag_note "$2"
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
    -f=)
      # the match_string is the right hand value in -f=match
      local match_string="${1#*=}"
      __s__find_rag_note "${match_string}"
      return 0
      ;;
    help)
      __s__print_rag_help
      return 0
      ;;
    *)
      no_more_opts=true
      break
      ;;
    esac
  done
  if [[ $# > 0 ]]; then
    command_was_supplied=true
  fi
  local user_note=""
  if [[ ${opt_tag_only} = false ]] && [[ ${opt_command_only} = false ]]; then
    user_note="$(pkg.gum input --placeholder "Type note" || echo "${__s__SIGEXIT}")"
    if [[ ${user_note} = "${__s__SIGEXIT}" ]]; then
      return 1
    fi
    if [[ -z ${user_note} ]]; then
      if ! pkg.gum confirm --default "Are you sure you don't want to include a note?" --affirmative="Continue" --negative="Cancel"; then
        rag
        return 0
      fi
    fi
    if [[ ${#user_note} -lt 3 ]]; then
      if ! pkg.gum confirm --default "Is this note correct: \`${user_note}\`?" --affirmative="Continue" --negative="Cancel"; then
        rag
        return 0
      fi
    fi
  fi
  local user_tag=""
  if [[ ${opt_note_only} = false ]] && [[ ${opt_command_only} = false ]]; then
    user_tag="$(__s__prompt_tag)"
    if [[ ${user_tag} = "${__s__SIGEXIT}" ]]; then
      return 1
    fi
  fi
  if [[ ${command_was_supplied} = false ]] && [[ -z ${user_tag} ]] && [[ -z ${user_note} ]]; then
    echo "No command, tag, or note was supplied. Exiting."
    return 0
  fi
  local loglines=$(wc -l <"${__s__RAG_NOTES}")
  if [[ ${loglines} -gt 3 ]]; then
    echo "--- ${__s__SECTION_DELIMITER} ---" >>"${__s__RAG_NOTES}"
  fi
  echo "(ID) $(date +%s%N)" >>"${__s__RAG_NOTES}"
  echo "(DATE) $(date)" >>"${__s__RAG_NOTES}"
  if [[ -n "${user_tag}" ]] && [[ ${opt_command_only} = false ]]; then
    echo "(TAG) ${user_tag}" >>"${__s__RAG_NOTES}"
  fi
  if [[ -n "${user_note}" ]] && [[ ${opt_command_only} = false ]]; then
    echo "(NOTE) ${user_note}" >>"${__s__RAG_NOTES}"
  fi
  if [[ ${command_was_supplied} = true ]]; then
    echo "(COMMAND) ${*}" >>"${__s__RAG_NOTES}"
    echo "(OUTPUT)" >>"${__s__RAG_NOTES}"
    # Will run our comand using the same RC file as the user would normally and
    # will capture some output: the note/tag > notes file, and any stdout lines that start with [RAG] > captured file.
    # Paranoid note: I filter the delimiter from the output before saving the notes file.
    # Since the delimiter is a hash, I only expect to remove it when somehow the source code
    # for this script makes its way into the output.
    /bin/bash --rcfile /root/.solos/.bashrc -i -c "$@" |
      tee -a >(grep "^\[RAG\]" >>"${__s__RAG_CAPTURED}") >(sed "s/${__s__SECTION_DELIMITER}//g" >>"${__s__RAG_NOTES}")
  fi
}
