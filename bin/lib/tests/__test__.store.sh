#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

# shellcheck source=../store.sh
. "lib/store.sh"
# shellcheck source=../../shared/static.sh
. "shared/static.sh"
vLIB_STORE_DIR=""
vOPT_PROJECT_DIR=""

__hook__.before_file() {
  log.error "__hook__.before_file"
  return 1
}

__hook__.after_file() {
  log.error "running __hook__.after_file"
  return 1
}

__hook__.before_fn() {
  log.error "running __hook__.before_fn $1"
  return 1
}

__hook__.after_fn() {
  log.error "running __hook__.after_fn $1"
  return 1
}

__hook__.after_fn_success() {
  log.error "__hook__.after_fn_success $1"
  return 1
}

__hook__.after_fn_fails() {
  log.error "__hook__.after_fn_fails $1"
  return 1
}

__hook__.after_file_success() {
  log.error "__hook__.after_file_success"
  return 1
}

__hook__.after_file_fails() {
  log.error "__hook__.after_file_fails"
  return 1
}

__test__.store._del() {
  log.error "store._del not implemented yet"
  return 1
}
__test__.store._get() {
  log.error "store._get not implemented yet"
  return 1
}
__test__.store._prompt() {
  log.error "store._prompt not implemented yet"
  return 1
}
__test__.store._set() {
  log.error "store._set not implemented yet"
  return 1
}
__test__.store._set_on_empty() {
  log.error "store._set_on_empty not implemented yet"
  return 1
}
__test__.store.global.del() {
  log.error "store.global.del not implemented yet"
  return 1
}
__test__.store.global.get() {
  log.error "store.global.get not implemented yet"
  return 1
}
__test__.store.global.prompt() {
  log.error "store.global.prompt not implemented yet"
  return 1
}
__test__.store.global.set() {
  log.error "store.global.set not implemented yet"
  return 1
}
__test__.store.global.set_on_empty() {
  log.error "store.global.set_on_empty not implemented yet"
  return 1
}
__test__.store.project.del() {
  log.error "store.project.del not implemented yet"
  return 1
}
__test__.store.project.get() {
  log.error "store.project.get not implemented yet"
  return 1
}
__test__.store.project.prompt() {
  log.error "store.project.prompt not implemented yet"
  return 1
}
__test__.store.project.set() {
  log.error "store.project.set not implemented yet"
  return 1
}
__test__.store.project.set_on_empty() {
  log.error "store.project.set_on_empty not implemented yet"
  return 1
}
