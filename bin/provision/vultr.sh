#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../bin.sh
. shared/empty.sh
# shellcheck source=../lib/utils.sh
. shared/empty.sh

vSELF_PROVISION_VULTR_API_ENDPOINT="https://api.lib.vultr.com/v2"

provision.vultr._launch_instance() {
  local pubkey="$1"
  local label="solos-${vPROJECT_ID}"
  local plan="voc-c-2c-4gb-50s-amd"
  local region="ewr"
  local os_id="2136"
  provision.vultr._get_pubkey_id "${pubkey}"
  local pubkey_id="${vPREV_RETURN[0]}"
  if [[ -z ${pubkey_id} ]]; then
    log.error "Unexpected error: no SSH public key found."
    exit 1
  fi
  # This function will launch an instance on vultr with the params supplied
  # and return the ip and instance id seperated by a space.
  # TODO[question]: what immediate status will we expect the server to be in after recieving a 201 response?
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/instances" \
    -X POST \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
      "region" : "'"${region}"'",
      "plan" : "'"${plan}"'",
      "label" : "'"${label}"'",
      "os_id" : '"${os_id}"',
      "backups" : "disabled",
      "tags": [
        "solos-project-'"${vPROJECT_NAME}"'"
      ],
      "sshkey_id": [
        "'"${pubkey_id}"'"
      ]
    }'
  lib.utils.curl.allows_error_status_codes "none"
  local ip="$(jq -r '.instance.main_ip' <<<"${vPREV_CURL_RESPONSE}")"
  local instance_id="$(jq -r '.instance.id' <<<"${vPREV_CURL_RESPONSE}")"
  vPREV_RETURN=("${ip}")
  vPREV_RETURN+=("${instance_id}")
}

provision.vultr._wait_for_instance() {
  local instance_id="$1"
  local expected_status="active"
  local expected_server_status="ok"
  local max_retries=30
  while true; do
    if [[ ${max_retries} -eq 0 ]]; then
      log.error "Unknown error: vultr instance: ${instance_id} did not reach the expected server status: ${expected_status} after 5 minutes."
      exit 1
    fi
    lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/instances/${instance_id}" \
      -X GET \
      -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}"
    lib.utils.curl.allows_error_status_codes "none"
    local queried_server_status="$(jq -r '.instance.server_status' <<<"${vPREV_CURL_RESPONSE}")"
    local queried_status="$(jq -r '.instance.status' <<<"${vPREV_CURL_RESPONSE}")"
    if [[ ${queried_server_status} = "${expected_server_status}" ]] && [[ ${queried_status} = "${expected_status}" ]]; then
      break
    fi
    max_retries=$((max_retries - 1))
    sleep 10
  done
}

provision.vultr._get_object_storage_id() {
  local label="solos-${vPROJECT_ID}"
  local object_storage_id=""
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/object-storage" \
    -X GET \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  local object_storage_labels=$(jq -r '.object_storages[].label' <<<"${vPREV_CURL_RESPONSE}")
  local object_storage_ids=$(jq -r '.object_storages[].id' <<<"${vPREV_CURL_RESPONSE}")
  for i in "${!object_storage_labels[@]}"; do
    if [[ ${object_storage_labels[$i]} = ${label} ]]; then
      object_storage_id="${object_storage_ids[$i]}"
      break
    fi
  done
  if [[ -n ${object_storage_id} ]]; then
    vPREV_RETURN=("${object_storage_id}")
  else
    vPREV_RETURN=()
  fi
}

provision.vultr._get_ewr_cluster_id() {
  local cluster_id=""
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/object-storage/clusters" \
    -X GET \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  local cluster_ids=$(jq -r '.clusters[].id' <<<"${vPREV_CURL_RESPONSE}")
  local cluster_regions=$(jq -r '.clusters[].region' <<<"${vPREV_CURL_RESPONSE}")
  for i in "${!cluster_regions[@]}"; do
    if [[ ${cluster_regions[$i]} = "ewr" ]]; then
      cluster_id="${cluster_ids[$i]}"
      break
    fi
  done
  vPREV_RETURN=("${cluster_id}")
  echo "$cluster_id"
}

provision.vultr._create_storage() {
  local cluster_id="$1"
  local label="solos-${vPROJECT_ID}"
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/object-storage" \
    -X POST \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
        "label" : "'"${label}"'",
        "cluster_id" : '"${cluster_id}"'
      }'
  lib.utils.curl.allows_error_status_codes "none"
  local object_storage_id=$(jq -r '.object_storage.id' <<<"${vPREV_CURL_RESPONSE}")
  vPREV_RETURN=("${object_storage_id}")
  echo "${object_storage_id}"
}

provision.vultr._get_pubkey_id() {
  local pubkey="$1"
  local found_pubkey_id=""
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/ssh-keys" \
    -X GET \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  local found_pubkey_ids=$(jq -r '.ssh_keys[].id' <<<"${vPREV_CURL_RESPONSE}")
  local found_pubkeys=$(jq -r '.ssh_keys[].ssh_key' <<<"${vPREV_CURL_RESPONSE}")
  # We don't care what the public key is labelled as, simply if it exists.
  # Each public key should inherently be unique to the project.
  for i in "${!found_pubkeys[@]}"; do
    if [[ ${pubkey} = ${found_pubkeys[$i]} ]]; then
      found_pubkey_id="${found_pubkey_ids[$i]}"
      break
    fi
  done
  vPREV_RETURN=("${found_pubkey_id}")
}

provision.vultr.save_pubkey() {
  local pubkey="$1"
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/ssh-keys" \
    -X POST \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
          "name" : "solos-'"$(date +%s)"'",
          "ssh_key" : "'"${pubkey}"'"
        }'
  lib.utils.curl.allows_error_status_codes "none"
  pubkey_id="$(jq -r '.ssh_key.id' <<<"${vPREV_CURL_RESPONSE}")"
  if [[ -z ${pubkey_id} ]]; then
    log.error "Unexpected error: failed to create an SSH keypair on Vultr."
    sleep 1
    exit 1
  fi
  vPREV_RETURN=("${pubkey_id}")
}

provision.vultr.find_pubkey() {
  local pubkey="$1"
  local exists=true
  provision.vultr._get_pubkey_id "${pubkey}"
  local pubkey_id="${vPREV_RETURN[0]:-""}"
  if [[ -z ${pubkey_id} ]]; then
    exists=false
  fi
  vPREV_RETURN=("${exists}")
}

provision.vultr.create_server() {
  local pubkey="$1"
  provision.vultr._launch_instance "${pubkey}"
  next_ip="${vPREV_RETURN[0]}"
  instance_id="${vPREV_RETURN[1]}"
  provision.vultr._wait_for_instance "${instance_id}"

  vPREV_RETURN=("${next_ip}")
}

provision.vultr.s3() {
  # See if we can skip the provisioning proccess for S3 if the object storage
  # with a matching label already exists.
  provision.vultr._get_object_storage_id
  local object_storage_id="${vPREV_RETURN[0]}"
  if [[ -z ${object_storage_id} ]]; then
    # Create the storage is the EWR region (east I think?)
    local ewr_cluster_id="$(provision.vultr._get_ewr_cluster_id)"
    object_storage_id="$(provision.vultr._create_storage "${ewr_cluster_id}")"
  fi
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/object-storage/${object_storage_id}" \
    -X GET \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"

  vPREV_RETURN=()
  vPREV_RETURN+=("$(jq -r '.object_storage.s3_hostname' <<<"${vPREV_CURL_RESPONSE}")")
  vPREV_RETURN+=("$(jq -r '.object_storage.s3_access_key' <<<"${vPREV_CURL_RESPONSE}")")
  vPREV_RETURN+=("$(jq -r '.object_storage.s3_secret_key' <<<"${vPREV_CURL_RESPONSE}")")
  vPREV_RETURN+=("$(jq -r '.object_storage.label' <<<"${vPREV_CURL_RESPONSE}")")
}
