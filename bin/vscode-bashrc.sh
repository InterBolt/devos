#!/usr/bin/env bash

shopt -s extdebug

# Grab gum and go
vrcBASHRC_ENTRY_DIR="${PWD}"
cd "${HOME}/.solos/src/bin"
source pkg/__source__.sh
cd "${vrcBASHRC_ENTRY_DIR}"

# Initialize the rag directory
vrcRAG_DIR="${HOME}/.solos/rag"
vrcRAG_NOTES="${vrcRAG_DIR}/notes"
vrcRAG_RAGGED="${vrcRAG_DIR}/ragged"
vrcRAG_STDOUT="${vrcRAG_DIR}/stdout"
mkdir -p "${vrcRAG_DIR}"
if [[ ! -f "${vrcRAG_NOTES}" ]]; then
  touch "${vrcRAG_NOTES}"
fi
if [[ ! -f "${vrcRAG_RAGGED}" ]]; then
  touch "${vrcRAG_RAGGED}"
fi
if [[ ! -f "${vrcRAG_STDOUT}" ]]; then
  touch "${vrcRAG_STDOUT}"
fi

# Random notes we can take while we're working.
note() {
  local should_log=${1:-true}
  local user_note="$(pkg.gum input --placeholder "Type note")"
  if [[ ! -z ${user_note} ]] && [[ ${should_log} = true ]]; then
    if [[ ! -z $(cat "${vrcRAG_NOTES}") ]]; then
      echo "" >>"${vrcRAG_NOTES}"
      echo "---" >>"${vrcRAG_NOTES}"
      echo "" >>"${vrcRAG_NOTES}"
    fi
    echo "DATE: $(date)" >>"${vrcRAG_NOTES}"
    echo "$(date): ${user_note}" >>"${vrcRAG_NOTES}"
  fi
  echo "${user_note}"
}

# Attaches a note to a command and records it's entire output for
# post-processing.
rag() {
  local rag_note="$(note false)"
  local ragged_lines=$(wc -l <"${vrcRAG_RAGGED}")
  if [[ ${ragged_lines} > 3 ]]; then
    echo "" >>"${vrcRAG_RAGGED}"
    echo "---" >>"${vrcRAG_RAGGED}"
    echo "" >>"${vrcRAG_RAGGED}"
  fi
  echo "DATE: $(date)" >>"${vrcRAG_RAGGED}"
  echo "COMMAND: ${*}" >>"${vrcRAG_RAGGED}"
  echo "PRE-RUN NOTE: ${rag_note}" >>"${vrcRAG_RAGGED}"
  echo "COMMAND OUTPUT:" >>"${vrcRAG_RAGGED}"
  echo "\`\`\`" >>"${vrcRAG_RAGGED}"
  "$@" | tee -a >(grep "^booger" >>"${vrcRAG_STDOUT}") "${vrcRAG_RAGGED}"
  echo "\`\`\`" >>"${vrcRAG_RAGGED}"
  return 0
}
