#!/bin/bash

some.fn() {
  local curr_time="$(date +%s)"
  sleep 1
  sleep 1
  sleep 1
  local next_time="$(date +%s)"
  echo "DIFF: $((next_time - curr_time))"
}
some.heavy_background_fn() {
  while true; do
    echo "scale=500; 4*a(1)" | bc -l >/dev/null 2>&1
    sleep .1
  done
}

some.heavy_background_fn &
pipipi=$!
some.fn
some.fn
some.fn
some.fn
some.fn
some.fn

kill -9 "${pipipi}"
