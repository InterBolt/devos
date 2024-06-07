#!/usr/bin/env bash

plugin__scrubbed_copy="${HOME}/.solos"
plugin__collections_dir="${HOME}/collections"

plugin.failed() {
  echo "FAILED: ${*}"
  exit 1
}
plugin.passed() {
  echo "PASSED: ${*}"
}

if [[ ! -w "${plugin__scrubbed_copy}" ]]; then
  plugin.passed "The scrubbed copy directory is readonly."
else
  plugin.failed "The scrubbed copy directory is not readonly."
fi
if [[ -d "${plugin__collections_dir}" ]]; then
  if [[ -w "${plugin__collections_dir}" ]]; then
    if [[ -z "$(ls -A "${plugin__collections_dir}")" ]]; then
      plugin.passed "The collections directory is empty and writable."
    else
      plugin.failed "The collections directory is not empty."
    fi
  else
    plugin.failed "The collections directory is not writable."
  fi
else
  plugin.failed "The collections directory does not exist."
fi

exit 0
