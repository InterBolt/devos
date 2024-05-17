#!/usr/bin/env bash

tmp_stdout=$(mktemp)
tmp_stderr=$(mktemp)

{
  exec > >(tee -a ${tmp_stdout}) 2> >(tee -a ${tmp_stderr} >&2)
  eval 'echo "Hello, World!" >&2'
} | cat

echo "CATTING"
cat ${tmp_stdout}
echo "CATTING"
cat ${tmp_stderr}
