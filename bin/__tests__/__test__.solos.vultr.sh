#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

 # shellcheck source=../solos.vultr.sh
source "solos.vultr.sh"

testhook.before_file() {
  log.info "testhook.before_file"
}

testhook.after_file() {
  log.info "running testhook.after_file"
}

testhook.before_fn() {
  log.info "running testhook.before_fn"
}

testhook.after_fn() {
  log.info "running testhook.after_fn"
}

testhook.after_fn_success() {
  log.info "testhook.after_fn_success"
}

testhook.after_fn_fails() {
  log.info "testhook.after_fn_fails"
}

testhook.after_file_success() {
  log.info "testhook.after_file_success"
}

testhook.after_file_fails() {
  log.info "testhook.after_file_fails"
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
