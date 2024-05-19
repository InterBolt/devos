#!/usr/bin/env bash

# shopt -s extdebug

# gum_path="/root/.solos/src/pkgs/.installs/gum_0.13.0_Linux_x86_64/gum"

# another_func() {
#   "${gum_path}" --help
# }

# stdout_file="/tmp/stdout"
# stderr_file="/tmp/stderr"

# func() {
#   local tty_descriptor="$(tty)"
#   local cmd="${*}"
#   # send tty output to stdout/err
#   # exec 3<>"${tty_descriptor}" 4<>"${tty_descriptor}"
#   {

#     # pass the output of tty_descriptor to stdout and stderr

#     # exec 1<>3 3<>"${tty_descriptor}" 2<>4 4<>"${tty_descriptor}"
#     # exec > >(tee >(grep "^\[RAG\]" >/dev/null) "${stdout_file}") 2> >(tee >(grep "^\[RAG\]" >/dev/null) "${stderr_file}" >&2)
#     exec \
#       > >(tee "${stdout_file}") \
#       2> >(tee "${stderr_file}" >&2)
#     # we need the command to use the tty descriptor redirection and also send it's output to stdout/erro

#     # read from tty_descriptor
#     eval "${cmd}" <>"${tty_descriptor}" 2<>"${tty_descriptor}"
#     # \
#     #   > >(tee >(grep "^\[RAG\]" >/dev/null) "${stdout_file}" >&3) \
#     #   2> >(tee >(grep "^\[RAG\]" >/dev/null) "${stderr_file}" >&4)

#   } | cat
# }

# func 'another_func | grep "A tool"'

# cat "${stdout_file}"
