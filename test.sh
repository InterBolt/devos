#!/bin/bash

merged_processed_logs="$(mktemp)"
jq -c '.' "/root/.solos/src/processed.json" >>"${merged_processed_logs}"

cat "${merged_processed_logs}"
