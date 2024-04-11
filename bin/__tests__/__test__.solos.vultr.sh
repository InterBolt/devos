#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=../solos.vultr.sh
source "solos.vultr.sh"

__hook__.before_file() {
  log.info "__hook__.before_file"
}

__hook__.after_file() {
  log.info "running __hook__.after_file"
}

__hook__.before_fn() {
  log.info "running __hook__.before_fn $1"
}

__hook__.after_fn() {
  log.info "running __hook__.after_fn $1"
}

__hook__.after_fn_success() {
  log.info "__hook__.after_fn_success $1"
}

__hook__.after_fn_fails() {
  log.info "__hook__.after_fn_fails $1"
}

__hook__.after_file_success() {
  log.info "__hook__.after_file_success"
}

__hook__.after_file_fails() {
  log.info "__hook__.after_file_fails"
}

vENV_IP=""
vENV_PROVIDER_API_ENDPOINT=""
vENV_PROVIDER_API_KEY=""
vENV_S=""
vPREV_CURL_RESPONSE=""
vPREV_RETURN=""
vSTATIC_VULTR_INSTANCE_DEFAULTS=""

__test__.vultr.compute.create_instance() {
  log.error "vultr.compute.create_instance not implemented yet"
  return 1
}

__test__.vultr.compute.destroy_instance() {
  log.error "vultr.compute.destroy_instance not implemented yet"
  return 1
}

__test__.vultr.compute.find_existing_sshkey_id() {
  log.error "vultr.compute.find_existing_sshkey_id not implemented yet"
  return 1
}

__test__.vultr.compute.get_instance_id_from_ip() {
  log.error "vultr.compute.get_instance_id_from_ip not implemented yet"
  return 1
}

__test__.vultr.compute.instance_contains_tag() {
  log.error "vultr.compute.instance_contains_tag not implemented yet"
  return 1
}

__test__.vultr.compute.provision() {
  log.error "vultr.compute.provision not implemented yet"
  return 1
}

__test__.vultr.compute.wait_for_ready_instance() {
  log.error "vultr.compute.wait_for_ready_instance not implemented yet"
  return 1
}
