#!/bin/bash

install.log_info() {
  echo -e "\033[1;32mINFO \033[0m (INSTALLER) ${1}" >&2
}
install.log_warn() {
  echo -e "\033[1;33mWARN \033[0m (INSTALLER) ${1}" >&2
}
install.log_error() {
  echo -e "\033[1;31mERROR \033[0m (INSTALLER) ${1}" >&2
}

# test each function with various messages
install.log_info "This is an info message."
install.log_warn "This is a warning message."
install.log_error "This is an error message."
