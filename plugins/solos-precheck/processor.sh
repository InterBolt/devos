#!/usr/bin/env bash

plugin__collections_dir="${HOME}/collections"
plugin__processed_file="${HOME}/processed.log"

plugin.failed() {
  echo "FAILED: ${*}"
  exit 1
}
plugin.passed() {
  echo "PASSED: ${*}"
}

if [[ ! -d "${plugin__collections_dir}" ]]; then
  plugin.failed "The collections directory does not exist."
fi
if [[ ! -w "${plugin__collections_dir}" ]]; then
  plugin.passed "The collections directory is readonly."
else
  plugin.failed "The collections directory is not readonly."
fi
if [[ -f "${plugin__processed_file}" ]]; then
  if [[ -w "${plugin__processed_file}" ]]; then
    if [[ -z "$(cat "${plugin__processed_file}")" ]]; then
      plugin.passed "The processed file is empty and writable."
    else
      plugin.failed "The processed file is not empty."
    fi
  else
    plugin.failed "The processed file is not writable."
  fi
else
  plugin.failed "The processed file does not exist."
fi

exit 0
