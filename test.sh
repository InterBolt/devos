#!/bin/bash

archives_dir="/root/.solos/data/daemon/archives"

archives=($(ls -t "${archives_dir}"))
archives_to_delete=("${archives[@]:5}")
for archive in "${archives_to_delete[@]}"; do
  echo "WOULD REMOVE ${archives_dir}/${archive}"
done
