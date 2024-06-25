#!/usr/bin/env bash

# Skip command if we get an unsuccessful return code in the debug trap.
shopt -s extdebug
# When the shell exits, append to the history file instead of overwriting it.
shopt -s histappend
# Load this history file.
history -r
# Used for tracking stuff.
shopt -s extdebug

. "${HOME}/.solos/repo/src/shared/lib.sh" || exit 1
. "${HOME}/.solos/repo/src/shared/log.sh" || exit 1
. "${HOME}/.solos/repo/src/shared/gum.sh" || exit 1

log.use "${HOME}/.solos/data/shell/master.log"

shell__pub_fns=""
shell__users_home_dir="$(lib.home_dir_path)"

shell.log_info() {
  local message="(SHELL) ${1}"
  shift
  log.info "${message}" "$@"
}
shell.log_error() {
  local message="(SHELL) ${1}"
  shift
  log.error "${message}" "$@"
}
shell.log_warn() {
  local message="(SHELL) ${1}"
  shift
  log.warn "${message}" "$@"
}
shell.blacklist_cmds() {
  local blacklist=(
    "source"
    "."
    "exit"
    "logout"
    "cd"
    "clear"
    "pwd"
    "cat"
    "man"
    "help"
    "chroot"
    "popd"
    "pushd"
    "env"
  )
  local cmds=($(echo "${rc__pub_fns}" | xargs))
  for cmd in "${cmds[@]}"; do
    blacklist+=("${cmd}")
  done
  echo "${blacklist[*]}" | xargs
}
shell.setup_working_dir() {
  if [[ ${PWD} != "${HOME}/.solos/"* ]]; then
    cd "${HOME}/.solos" || exit 1
  else
    cd "${PWD}" || exit 1
  fi
}
shell.require_home_dir_path() {
  if [[ -z ${shell__users_home_dir} ]]; then
    lib.panics_add "missing_home_dir" <<EOF
No reference to the user's home directory was found in the folder: ~/.solos/data/store.
EOF
    lib.enter_to_exit
  fi
}
shell.set_ps1() {
  PS1='\[\033[0;32m\]SolOS\[\033[00m\]:\[\033[01;34m\]'"\${PWD/\$HOME/\~}"'\[\033[00m\]$ '
}

# These expect top-level access to shell.* commands.
. "${HOME}/.solos/repo/src/shells/bash/app.sh" || exit 1
. "${HOME}/.solos/repo/src/shells/bash/bash-completions.sh" || exit 1
. "${HOME}/.solos/repo/src/shells/bash/daemon.sh" || exit 1
. "${HOME}/.solos/repo/src/shells/bash/execs.sh" || exit 1
. "${HOME}/.solos/repo/src/shells/bash/github.sh" || exit 1
. "${HOME}/.solos/repo/src/shells/bash/info.sh" || exit 1
. "${HOME}/.solos/repo/src/shells/bash/panics.sh" || exit 1
. "${HOME}/.solos/repo/src/shells/bash/plugins.sh" || exit 1
. "${HOME}/.solos/repo/src/shells/bash/track.sh" || exit 1

# Public functions
# Note: for a few of these, I'm supporting plural and singular forms of the command.
shell.public_reload() {
  if lib.is_help_cmd "${1}"; then
    cat <<EOF

USAGE: reload

DESCRIPTION:

Reload the current shell session. Warning: exiting a reloaded shell will take you back \
to the version of the shell before the reload. \
So you might need to type \`exit\` a few times to completely exit the shell.

EOF
    return 0
  fi
  trap - DEBUG
  trap - SIGINT
  history -a
  if [[ -f "${HOME}/.solos/rcfiles/.shell" ]]; then
    bash --rcfile "${HOME}/.solos/rcfiles/.shell" -i
  else
    bash -i
  fi
}
shell.public_app() {
  app.cmd "$@"
}
shell.public_apps() {
  app.cmd "$@"
}
shell.public_track() {
  track.cmd "$@"
}
shell.public_info() {
  if lib.is_help_cmd "${1}"; then
    cat <<EOF
USAGE: info

DESCRIPTION:

Print info about this shell.

EOF
    return 0
  fi
  echo ""
  info.cmd "$@"
  echo ""
}
shell.public_preexec() {
  execs.cmd "preexec" "$@"
}
shell.public_postexec() {
  execs.cmd "postexec" "$@"
}
shell.public_plugin() {
  plugins.cmd "$@"
}
shell.public_plugins() {
  plugins.cmd "$@"
}
shell.public_daemon() {
  daemon.cmd "$@"
}
shell.public_panic() {
  panics.cmd "$@"
}
shell.public_panics() {
  panics.cmd "$@"
}
shell.public_github() {
  github.cmd "$@"
}
shell.public_install_solos() {
  panics.install
  execs.install
  shell.require_home_dir_path
  shell.setup_working_dir
  shell.set_ps1
  info.install
  github.install
  bash_completions.install
  track.install
}

shell__pub_fns=""
shell__found_pub_fns=($(declare -F | grep -o "shell.public_[a-z_]*" | xargs))
for found_pub_fn in "${shell__found_pub_fns[@]}"; do
  pub_func_renamed="${found_pub_fn#"shell.public_"}"
  eval "${pub_func_renamed}() { ${found_pub_fn} \"\$@\"; }"
  eval "declare -g -r -f ${pub_func_renamed}"
  eval "export -f ${pub_func_renamed}"
  shell__pub_fns="${pub_func_renamed} ${shell__pub_fns}"
done
