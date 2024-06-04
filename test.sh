#!/usr/bin/env bash

# user_preexecs=()

# confirm that user_preexecs is a defined and empty array
if declare -p user_preexecs >/dev/null 2>&1; then
  echo "user_preexecs is defined"
else
  echo "user_preexecs is not defined"
fi
