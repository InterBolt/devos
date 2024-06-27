#!/bin/bash

parent_pid=$$
lock=false

trap 'trap - SIGTERM && cleanup;' SIGTERM EXIT

cleanup() {
  if [[ ${lock} = "true" ]]; then
    echo "PREVENTED NEW CLEANUP" >&2
    return 0
  fi
  lock=true
  echo "CLEANING FOR 4 SECONDS" >&2
  sleep 4
  echo "CLEANED" >&2
  kill -9 "${parent_pid}"
}

exit_after_five_seconds() {
  local i=0
  while true; do
    if [[ ${i} -eq 5 ]]; then
      kill -SIGTERM "${parent_pid}"
      break
    fi
    sleep 1
    i=$((i + 1))
  done
}

exit_after_five_seconds &

outer_i=0
# Keep the parent alive until "exit_after_five_seconds" forces an exit.
while true; do
  echo "${outer_i}"
  if [[ ${outer_i} -eq 50 ]]; then
    echo "ATTEMPTING EXIT FROM PARENT: this should NOT trigger a new trap exec" >&2
    exit 1
  fi
  sleep .1
  outer_i=$((outer_i + 1))
done
