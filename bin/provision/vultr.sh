#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../solos.sh
. shared/empty.sh
# shellcheck source=../lib/utils.sh
. shared/empty.sh

vSELF_PROVISION_VULTR_API_ENDPOINT="https://api.lib.vultr.com/v2"

provision.vultr._destroy_instance() {
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/instances/${instance_id}" \
    -X DELETE \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
}

provision.vultr._launch_instance() {
  local sshkey_id="$1"
  local plan="voc-c-2c-4gb-50s-amd"
  local region="ewr"
  local os_id="2136"
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
        "source_solos"
        "'"ssh_${sshkey_id}"'"
      ],
      "sshkey_id": [
        "'"${sshkey_id}"'"
      ]
    }'
  lib.utils.curl.allows_error_status_codes "none"
  local ip="$(jq -r '.instance.main_ip' <<<"${vPREV_CURL_RESPONSE}")"
  local instance_id="$(jq -r '.instance.id' <<<"${vPREV_CURL_RESPONSE}")"
  vPREV_RETURN=("$ip" "$instance_id")
  echo "$ip $instance_id"
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
  local label="$1"
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
  local label="$1"
  local cluster_id="$2"
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

provision.vultr.server_tag_exists() {
  local instance_id="$1"
  local tag="$2"
  local tags
  local found=false
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/instances/${instance_id}" \
    -X GET \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  tags=$(jq -r '.instance.tags' <<<"${vPREV_CURL_RESPONSE}")
  for i in "${!tags[@]}"; do
    if [[ ${tags[$i]} = "${tag}" ]]; then
      found=true
    fi
  done
  vPREV_RETURN=("$found")
  echo "$found"
}

provision.vultr.save_pubkey() {
  local label="$1"
  local pubkey="$2"
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/ssh-keys" \
    -X POST \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
          "name" : "'"${label}"'",
          "ssh_key" : "'"${pubkey}"'"
        }'
  lib.utils.curl.allows_error_status_codes "none"
  pubkey_id="$(jq -r '.ssh_key.id' <<<"${vPREV_CURL_RESPONSE}")"
  if [[ -z ${pubkey_id} ]]; then
    log.error "Unexpected error: failed to create an SSH keypair on Vultr."
    sleep 1
    exit 1
  fi
  echo "${pubkey_id}"
}

provision.vultr.get_pubkey_id() {
  local pub_key="$1"
  local found_ssh_keys
  local found_ssh_key_names
  local match_exists=false
  local matching_ssh_key_found=false
  local matching_ssh_key_name_found=false
  local matching_sshkey_id=""
  # This function will loop through the existing ssh keys on vultr
  # and ask, "is the name and public key the same as the one we have?"
  # If so, we echo the ssh key id and exit. We'll echo an empty
  # string if the key doesn't exist.
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/ssh-keys" \
    -X GET \
    -H "Authorization: Bearer ${vSUPPLIED_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  found_sshkey_ids=$(jq -r '.ssh_keys[].id' <<<"${vPREV_CURL_RESPONSE}")
  found_ssh_keys=$(jq -r '.ssh_keys[].ssh_key' <<<"${vPREV_CURL_RESPONSE}")
  found_ssh_key_names=$(jq -r '.ssh_keys[].name' <<<"${vPREV_CURL_RESPONSE}")
  for i in "${!found_ssh_keys[@]}"; do
    if [[ "solos" = "${found_ssh_key_names[$i]}" ]]; then
      matching_ssh_key_name_found=true
    fi
    if [[ ${pub_key} = ${found_ssh_keys[$i]} ]]; then
      matching_ssh_key_found=true
    fi
    if [[ ${matching_ssh_key_found} = true ]] && [[ ${matching_ssh_key_name_found} = true ]]; then
      match_exists=true
      matching_sshkey_id="${found_sshkey_ids[$i]}"
      break
    fi
  done
  # Catch conflicts where a matching ssh key exists, but it's name is different.
  # Or where a matching ssh key name exists, but it's public key contents are different.
  # Note: technically we could just say "if match_exists=false" error and exit.
  # But the extra info is nice for debugging.
  if [[ ${match_exists} = false ]] && [[ ${matching_ssh_key_found} = true ]]; then
    log.error "a conflict was found where a matching ssh key exists, but it's name is different."
    for i in "${!found_ssh_keys[@]}"; do
      log.error "found_sshkey_id: ${found_sshkey_ids[$i]} found_sshkey_name: ${found_ssh_key_names[$i]}"
    done
    exit 1
  fi
  if [[ ${match_exists} = false ]] && [[ ${matching_ssh_key_name_found} = true ]]; then
    log.error "a conflict was found where a matching ssh key name exists, but it's public key contents are different."
    for i in "${!found_ssh_keys[@]}"; do
      log.error "found_sshkey_id: ${found_sshkey_ids[$i]} found_sshkey_name: ${found_ssh_key_names[$i]}"
    done
    exit 1
  fi
  if [[ -n ${matching_sshkey_id} ]]; then
    vPREV_RETURN=("$matching_sshkey_id")
    echo "${matching_sshkey_id}"
  else
    vPREV_RETURN=()
    echo ""
  fi
}

provision.vultr.create_server() {
  local project_name="$1"
  local ssh_pubkey="$2"
  if [[ -z ${project_name} ]]; then
    log.error "Unexpected error: empty project name supplied."
    exit 1
  fi
  local label="solos-${project_name}"
  provision.vultr._launch_instance "${label}" "${created_sshkey_id}"
  next_ip="${vPREV_RETURN[0]}"
  instance_id="${vPREV_RETURN[1]}"
  provision.vultr._wait_for_instance "${instance_id}"

  vPREV_RETURN=("${next_ip}")
}

provision.vultr.s3() {
  local project_name="$1"
  if [[ -z ${project_name} ]]; then
    log.error "Unexpected error: empty project name supplied."
    exit 1
  fi
  local object_storage_id=""
  local label="solos-${project_name}"
  provision.vultr._get_object_storage_id "${label}"
  object_storage_id="${vPREV_RETURN[0]}"
  if [[ -n ${object_storage_id} ]]; then
    log.error "Unexpected error: Vultr object storage with the label: ${label} already exists."
    exit 1
  else
    local cluster_id="$(provision.vultr._get_ewr_cluster_id)"
    object_storage_id="$(provision.vultr._create_storage "${label}" "${cluster_id}")"
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
