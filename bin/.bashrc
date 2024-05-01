#!/usr/bin/env bash

shopt -s extdebug

# Grab gum and go
__vBASHRC_ENTRY_DIR="${PWD}"
cd "${HOME}/.solos/src/bin"
source pkg/__source__.sh
cd "${__vBASHRC_ENTRY_DIR}"

# Initialize the rag directory
__vRAG_DIR="${HOME}/.solos/rag"
__vRAG_NOTES="${__vRAG_DIR}/notes"
__vRAG_RAGGED="${__vRAG_DIR}/ragged"
__vRAG_STDOUT="${__vRAG_DIR}/stdout"
mkdir -p "${__vRAG_DIR}"
if [[ ! -f "${__vRAG_NOTES}" ]]; then
  touch "${__vRAG_NOTES}"
fi
if [[ ! -f "${__vRAG_RAGGED}" ]]; then
  touch "${__vRAG_RAGGED}"
fi
if [[ ! -f "${__vRAG_STDOUT}" ]]; then
  touch "${__vRAG_STDOUT}"
fi

# Random notes we can take while we're working.
note() {
  local should_log=${1:-true}
  local user_note="$(pkg.gum input --placeholder "Type note")"
  if [[ ! -z ${user_note} ]] && [[ ${should_log} = true ]]; then
    if [[ ! -z $(cat "${__vRAG_NOTES}") ]]; then
      echo "" >>"${__vRAG_NOTES}"
      echo "---" >>"${__vRAG_NOTES}"
      echo "" >>"${__vRAG_NOTES}"
    fi
    echo "DATE: $(date)" >>"${__vRAG_NOTES}"
    echo "$(date): ${user_note}" >>"${__vRAG_NOTES}"
  fi
  echo "${user_note}"
}

# Attaches a note to a command and records it's entire output for
# post-processing.
rag() {
  local rag_note="$(note false)"
  local ragged_lines=$(wc -l <"${__vRAG_RAGGED}")
  if [[ ${ragged_lines} > 3 ]]; then
    echo "" >>"${__vRAG_RAGGED}"
    echo "---" >>"${__vRAG_RAGGED}"
    echo "" >>"${__vRAG_RAGGED}"
  fi
  echo "DATE: $(date)" >>"${__vRAG_RAGGED}"
  echo "COMMAND: ${*}" >>"${__vRAG_RAGGED}"
  echo "PRE-RUN NOTE: ${rag_note}" >>"${__vRAG_RAGGED}"
  echo "COMMAND OUTPUT:" >>"${__vRAG_RAGGED}"
  echo "\`\`\`" >>"${__vRAG_RAGGED}"
  "$@" | tee -a >(grep "^booger" >>"${__vRAG_STDOUT}") "${__vRAG_RAGGED}"
  echo "\`\`\`" >>"${__vRAG_RAGGED}"
  return 0
}
