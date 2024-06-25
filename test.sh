#!/bin/bash

fn.seed() {
  local data_dir="${HOME}/.solos/data/daemon/archives"
  rm -rf "${data_dir}"
  mkdir -p "${data_dir}"
  mkdir -p "${data_dir}/folder1"
  mkdir -p "${data_dir}/folder2"
  dd if=/dev/zero of="${data_dir}/folder1/file1" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/folder1/file2" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/folder2/file3" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/folder2/file4" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file5" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file6" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file7" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file8" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file9" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file10" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file11" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file12" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file13" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file14" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file15" bs=1M count=10
  dd if=/dev/zero of="${data_dir}/file16" bs=1M count=10
}

declare -A bind_store=()

fn.test() {
  {
    echo "RUNNING FIRST BACKGROUND PROCESS"
    sleep 1
    exit 0
  } &
  echo "pid: $!"
  {
    echo "RUNNING SECOND LONGER BACKGROUND PROCESS"
    sleep 2
    exit 0
  } &
  sleep 4
  local found_backgrounded_processes=false
  for pid in $(jobs -p); do
    found_backgrounded_processes=true
  done
  if [[ ${found_backgrounded_processes} = true ]]; then
    echo "There are still some background jobs running. Waiting 10 seconds before handling requests." >&2
    sleep 10
  fi
}

fn.test
