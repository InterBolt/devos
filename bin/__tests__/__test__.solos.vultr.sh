#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=../solos.vultr.sh
. "solos.vultr.sh"

__hook__.before_file() {
  log.error "__hook__.before_file"
  return 0
}

__hook__.after_file() {
  log.error "running __hook__.after_file"
  return 0
}

__hook__.before_fn() {
  log.error "running __hook__.before_fn $1"
  return 0
}

__hook__.after_fn() {
  log.error "running __hook__.after_fn $1"
  return 0
}

__hook__.after_fn_success() {
  log.error "__hook__.after_fn_success $1"
  return 0
}

__hook__.after_fn_fails() {
  log.error "__hook__.after_fn_fails $1"
  return 0
}

__hook__.after_file_success() {
  log.error "__hook__.after_file_success"
  return 0
}

__hook__.after_file_fails() {
  log.error "__hook__.after_file_fails"
  return 0
}

vENV_IP=""
vENV_PROVIDER_API_ENDPOINT=""
vENV_PROVIDER_API_KEY=""
vENV_S3_ACCESS_KEY=""
vENV_S3_HOST=""
vENV_S3_OBJECT_STORE=""
vENV_S3_SECRET=""
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
