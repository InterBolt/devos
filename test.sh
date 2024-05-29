#!/usr/bin/env bash

shopt -s extdebug

__profile_bashrc__enforce_restricted_fn_names() {
  echo "$BASH_COMMAND"
  return 0
}

trap '__profile_bashrc__enforce_restricted_fn_names' DEBUG

defining_a_fn() {
  echo "This is a function"
}

defining_a_fn
