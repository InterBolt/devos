 #!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o errtrace

cd "$(git rev-parse --show-toplevel 2>/dev/null)/bin"

 # shellcheck source=../vultr.sh
. "lib/vultr.sh"

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
__test__.vultr.s3.bucket_exists() {
  log.error "vultr.s3.bucket_exists not implemented yet"
  return 1
}
__test__.vultr.s3.create_bucket() {
  log.error "vultr.s3.create_bucket not implemented yet"
  return 1
}
__test__.vultr.s3.create_storage() {
  log.error "vultr.s3.create_storage not implemented yet"
  return 1
}
__test__.vultr.s3.get_ewr_cluster_id() {
  log.error "vultr.s3.get_ewr_cluster_id not implemented yet"
  return 1
}
__test__.vultr.s3.get_object_storage_id() {
  log.error "vultr.s3.get_object_storage_id not implemented yet"
  return 1
}
__test__.vultr.s3.provision() {
  log.error "vultr.s3.provision not implemented yet"
  return 1
}
