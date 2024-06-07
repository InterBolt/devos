#!/usr/bin/env bash

plugin__processed_file="${HOME}/processed.log"

plugin.failed() {
  echo "FAILED: ${*}"
  exit 1
}
plugin.passed() {
  echo "PASSED: ${*}"
}

if [[ ! -w "${plugin__processed_file}" ]]; then
  plugin.passed "The processed file is readonly."
else
  plugin.failed "The processed file is not readonly."
fi

exit 0
