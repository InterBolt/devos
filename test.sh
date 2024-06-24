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

fn.test() {
  local next_dir="/root/.solos"
  # local next_dir="/root/othershit"
  if [[ ${next_dir} != "${HOME}/.solos"* ]]; then
    echo "HISDHF"
  fi
}

fn.test
