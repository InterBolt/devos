#!/usr/bin/env bash

firejailed_collection_dirs="$(echo "one two thre   four  " | xargs)"

local i=0
for firejailed_collection_dir in ${firejailed_collection_dirs}; do
  echo "firejailed_collection_dirs ${i}: ${firejailed_collection_dir}"
  i=$((i + 1))
done
