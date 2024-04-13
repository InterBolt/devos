#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh
# --------------------------------------------------------------------------------------------
#
# VULTR FUNCTIONS
#
lib.vultr.compute.instance_contains_tag() {
  vPREV_RETURN=()
  #
  # This function is useful for checking if an instance has the matching
  # SSH tag. Might use it for other tags in the future.
  #
  local tag="$1"
  local instance_id="$2"
  local tags
  local found=false
  lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/instances/${instance_id}" \
    -X GET \
    -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  tags=$(jq -r '.instance.tags' <<<"$vPREV_CURL_RESPONSE")
  for i in "${!tags[@]}"; do
    if [ "${tags[$i]}" == "${tag}" ]; then
      found=true
    fi
  done
  vPREV_RETURN=("$found")
  echo "$found"
}
lib.vultr.compute.destroy_instance() {
  vPREV_RETURN=()

  local instance_id="$1"
  if [ -z "${instance_id}" ]; then
    log.error "you supplied an empty instance id as the first argument to lib.vultr.compute.destroy_instance"
    exit 1
  fi
  lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/instances/$instance_id" \
    -X DELETE \
    -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
}
lib.vultr.compute.create_instance() {
  vPREV_RETURN=()

  local plan="$1"
  local region="$2"
  local os_id="$3"
  local sshkey_id="$4"
  #
  # This function will launch an instance on vultr with the params supplied
  # and return the ip and instance id seperated by a space.
  # TODO[question]: what immediate status will we expect the server to be in after recieving a 201 response?
  #
  lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/instances" \
    -X POST \
    -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}" \
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
  local ip="$(jq -r '.instance.main_ip' <<<"$vPREV_CURL_RESPONSE")"
  local instance_id="$(jq -r '.instance.id' <<<"$vPREV_CURL_RESPONSE")"
  vPREV_RETURN=("$ip" "$instance_id")
  echo "$ip $instance_id"
}
lib.vultr.compute.get_instance_id_from_ip() {
  vPREV_RETURN=()

  local ip="$1"
  lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/instances?main_ip=${ip}" \
    -X GET \
    -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  local instance_id="$(jq -r '.instances[0].id' <<<"$vPREV_CURL_RESPONSE")"
  vPREV_RETURN=("$instance_id")
}
lib.vultr.compute.find_existing_sshkey_id() {
  vPREV_RETURN=()

  local found_ssh_keys
  local found_ssh_key_names
  local match_exists=false
  local matching_ssh_key_found=false
  local matching_ssh_key_name_found=false
  local matching_sshkey_id=""
  #
  # This function will loop through the existing ssh keys on vultr
  # and ask, "is the name and public key the same as the one we have?"
  # If so, we echo the ssh key id and exit. We'll echo an empty
  # string if the key doesn't exist.
  #
  lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/ssh-keys" \
    -X GET \
    -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  found_sshkey_ids=$(jq -r '.ssh_keys[].id' <<<"$vPREV_CURL_RESPONSE")
  found_ssh_keys=$(jq -r '.ssh_keys[].ssh_key' <<<"$vPREV_CURL_RESPONSE")
  found_ssh_key_names=$(jq -r '.ssh_keys[].name' <<<"$vPREV_CURL_RESPONSE")
  for i in "${!found_ssh_keys[@]}"; do
    if [ "solos" == "${found_ssh_key_names[$i]}" ]; then
      matching_ssh_key_name_found=true
    fi
    if [ "$(lib.ssh.cat_pubkey.self)" == "${found_ssh_keys[$i]}" ]; then
      matching_ssh_key_found=true
    fi
    if [ "$matching_ssh_key_found" == true ] && [ "$matching_ssh_key_name_found" == true ]; then
      match_exists=true
      matching_sshkey_id="${found_sshkey_ids[$i]}"
      break
    fi
  done
  #
  # Catch conflicts where a matching ssh key exists, but it's name is different.
  # Or where a matching ssh key name exists, but it's public key contents are different.
  # Note: technically we could just say "if match_exists=false" error and exit.
  # But the extra info is nice for debugging.
  #
  if [ "$match_exists" == false ] && [ "$matching_ssh_key_found" == true ]; then
    log.error "a conflict was found where a matching ssh key exists, but it's name is different."
    for i in "${!found_ssh_keys[@]}"; do
      log.error "found_sshkey_id: ${found_sshkey_ids[$i]} found_sshkey_name: ${found_ssh_key_names[$i]}"
    done
    exit 1
  fi
  if [ "$match_exists" == false ] && [ "$matching_ssh_key_name_found" == true ]; then
    log.error "a conflict was found where a matching ssh key name exists, but it's public key contents are different."
    for i in "${!found_ssh_keys[@]}"; do
      log.error "found_sshkey_id: ${found_sshkey_ids[$i]} found_sshkey_name: ${found_ssh_key_names[$i]}"
    done
    exit 1
  fi
  if [ -n "${matching_sshkey_id}" ]; then
    vPREV_RETURN=("$matching_sshkey_id")
    echo "${matching_sshkey_id}"
  else
    vPREV_RETURN=()
    echo ""
  fi
}
lib.vultr.compute.wait_for_ready_instance() {
  vPREV_RETURN=()

  local instance_id="$1"
  local expected_status="active"
  local expected_server_status="ok"
  local max_retries=30
  while true; do
    if [ "${max_retries}" -eq 0 ]; then
      log.error "instance: ${instance_id} did not reach the expected server status: ${expected_status} after 5 minutes."
      exit 1
    fi
    log.warn "pinging the instance: ${instance_id} to check if it has reached the expected server status: ${expected_status}"
    lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/instances/${instance_id}" \
      -X GET \
      -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}"
    lib.utils.curl.allows_error_status_codes "none"
    local queried_server_status="$(jq -r '.instance.server_status' <<<"$vPREV_CURL_RESPONSE")"
    local queried_status="$(jq -r '.instance.status' <<<"$vPREV_CURL_RESPONSE")"
    if [ "$queried_server_status" == "${expected_server_status}" ] && [ "$queried_status" == "${expected_status}" ]; then
      break
    fi
    max_retries=$((max_retries - 1))
    log.warn "waiting for 10 seconds before retrying."
    sleep 10
  done
  log.info "instance: ${instance_id} has reached the expected server status: ${expected_server_status} and status: ${expected_status}"
}
lib.vultr.compute.provision() {
  vPREV_RETURN=()

  local prev_ip="$1"
  local created_sshkey_id=""
  local instance_id=""
  local next_ip=""
  #
  # In the ssh key setup below, we acquired a keypair, and now
  # we need to ask, "is this keypair on vultr?".
  # If it's not, we must create it.
  #
  local found_valid_sshkey_id="$(lib.vultr.compute.find_existing_sshkey_id)"
  if [ -z "${found_valid_sshkey_id}" ]; then
    lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/ssh-keys" \
      -X POST \
      -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}" \
      -H "Content-Type: application/json" \
      --data '{
          "name" : "solos",
          "ssh_key" : "'"$(lib.ssh.cat_pubkey.self)"'"
        }'
    lib.utils.curl.allows_error_status_codes "none"
    created_sshkey_id="$(jq -r '.ssh_key.id' <<<"$vPREV_CURL_RESPONSE")"
  else
    created_sshkey_id="${found_valid_sshkey_id}"
  fi
  #
  # When no ip exists:
  # Go ahead and create a new instance and set the ip to the new instance.
  #
  # When a ip DOES exist:
  # We should assume that an instance exists and throw if not.
  # If an instance does exist, we should check it's tags (vultr doesn't have an sshkey_id field on the get instance response)
  # to see if it has the correct ssh key. If it doesn't, we delete the instance and create a new one.
  # Otherwise, we can skip the provisioning process and move on to the next cmd.
  #
  if [ -z "${prev_ip}" ]; then
    lib.vultr.compute.create_instance "${vSTATIC_VULTR_INSTANCE_DEFAULTS[0]}" "${vSTATIC_VULTR_INSTANCE_DEFAULTS[1]}" "${vSTATIC_VULTR_INSTANCE_DEFAULTS[2]}" "${created_sshkey_id}"
    next_ip="${vPREV_RETURN[0]}"
    instance_id="${vPREV_RETURN[1]}"
    log.info "waiting for the instance with id:${instance_id} and ip:${vENV_IP} to be ready."
    lib.vultr.compute.wait_for_ready_instance "$instance_id"
  else
    lib.vultr.compute.get_instance_id_from_ip "${prev_ip}"
    instance_id="${vPREV_RETURN[0]}"
    if [ -z "${instance_id}" ]; then
      log.error "no instance found with the ip: ${prev_ip}. you might need to do a hard reset."
      exit 1
    fi
    log.info "looking for a tag that tells us if the instance has a matching ssh key."
    ssh_tag_exists="$(lib.vultr.compute.instance_contains_tag "ssh_${created_sshkey_id}" "$instance_id")"
    if [ "${ssh_tag_exists}" == "true" ]; then
      log.info "found matching instance tag: ssh_${created_sshkey_id}"
      log.info "nothing to do. the instance is already provisioned."
      next_ip="$prev_ip"
    else
      log.warn "warning: waiting 5 seconds to begin the re-installation process."
      sleep 5
      log.info "deleting instance: ${instance_id}"
      lib.vultr.compute.destroy_instance "$instance_id"
      log.info "creating instance with settings: ${vSTATIC_VULTR_INSTANCE_DEFAULTS[*]}"
      lib.vultr.compute.create_instance "${vSTATIC_VULTR_INSTANCE_DEFAULTS[0]}" "${vSTATIC_VULTR_INSTANCE_DEFAULTS[1]}" "${vSTATIC_VULTR_INSTANCE_DEFAULTS[2]}" "${created_sshkey_id}"
      next_ip="${vPREV_RETURN[0]}"
      instance_id="${vPREV_RETURN[1]}"
      log.info "waiting for the instance with id:${instance_id} and ip:${vENV_IP} to be ready."
      lib.vultr.compute.wait_for_ready_instance "$instance_id"
    fi
  fi
  if [ -z "${next_ip}" ]; then
    log.error "something unexpected happened. no ip address was produced after the re-installation."
    exit 1
  fi
  vPREV_RETURN=("$next_ip")
}
lib.vultr.s3.bucket_exists() {
  vPREV_RETURN=()

  local bucket="$1"
  exists=false
  error=""
  {
    bucketstatus=$(aws s3api head-bucket --bucket "$bucket" 2>&1)
    if echo "${bucketstatus}" | grep 'Not Found'; then
      exists=false
    elif echo "${bucketstatus}" | grep 'Forbidden'; then
      exists=true
      error="Bucket exists but not owned by you"
    elif echo "${bucketstatus}" | grep 'Bad Request'; then
      exists=true
      error="Bucket name specified is less than 3 or greater than 63 characters"
    else
      exists=true
      error=""
    fi
  } >/dev/null
  if [ "$error" != "" ]; then
    echo "Error occurred while checking bucket status: $error"
    exit 1
  fi
  vPREV_RETURN=("$exists")
  echo "$exists"
}
lib.vultr.s3.create_bucket() {
  vPREV_RETURN=()

  local bucket="$1"
  aws --region "us-east-1" s3 mb s3://"$bucket" >/dev/null
}
lib.vultr.s3.get_object_storage_id() {
  vPREV_RETURN=()

  local label="$1"
  local object_storage_id=""
  lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/object-storage" \
    -X GET \
    -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  local object_storage_labels=$(jq -r '.object_storages[].label' <<<"$vPREV_CURL_RESPONSE")
  local object_storage_ids=$(jq -r '.object_storages[].id' <<<"$vPREV_CURL_RESPONSE")
  for i in "${!object_storage_labels[@]}"; do
    if [ "${object_storage_labels[$i]}" == "${label}" ]; then
      object_storage_id="${object_storage_ids[$i]}"
      break
    fi
  done
  vPREV_RETURN=("$object_storage_id")
  echo "$object_storage_id"
}
lib.vultr.s3.get_ewr_cluster_id() {
  vPREV_RETURN=()

  local cluster_id=""
  lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/object-storage/clusters" \
    -X GET \
    -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  local cluster_ids=$(jq -r '.clusters[].id' <<<"$vPREV_CURL_RESPONSE")
  local cluster_regions=$(jq -r '.clusters[].region' <<<"$vPREV_CURL_RESPONSE")
  for i in "${!cluster_regions[@]}"; do
    if [ "${cluster_regions[$i]}" == "ewr" ]; then
      cluster_id="${cluster_ids[$i]}"
      break
    fi
  done
  vPREV_RETURN=("$cluster_id")
  echo "$cluster_id"
}
lib.vultr.s3.create_storage() {
  vPREV_RETURN=()

  local cluster_id="$1"
  local label="$2"
  lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/object-storage" \
    -X POST \
    -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}" \
    -H "Content-Type: application/json" \
    --data '{
        "label" : "'"${label}"'",
        "cluster_id" : '"${cluster_id}"'
      }'
  lib.utils.curl.allows_error_status_codes "none"
  local object_storage_id=$(jq -r '.object_storage.id' <<<"$vPREV_CURL_RESPONSE")
  vPREV_RETURN=("$object_storage_id")
  echo "$object_storage_id"
}
lib.vultr.s3.provision() {
  vPREV_RETURN=()

  local object_storage_id=""
  local label="solos"
  object_storage_id="$(lib.vultr.s3.get_object_storage_id "${label}")"
  if [ -z "${object_storage_id}" ]; then
    log.info "no object storage found with the label: ${label}. creating a new one."
    local cluster_id="$(lib.vultr.s3.get_ewr_cluster_id)"
    log.info "using the ewr cluster id: ${cluster_id}"
    object_storage_id="$(lib.vultr.s3.create_storage "${cluster_id}" "${label}")"
    log.info "created object storage with the id: ${object_storage_id}"
  else
    log.info "found object storage with the label: ${label} and id: ${object_storage_id}"
  fi
  lib.utils.curl "$vENV_PROVIDER_API_ENDPOINT/object-storage/$object_storage_id" \
    -X GET \
    -H "Authorization: Bearer ${vENV_PROVIDER_API_KEY}"
  lib.utils.curl.allows_error_status_codes "none"
  vENV_S3_HOST="$(jq -r '.object_storage.s3_hostname' <<<"$vPREV_CURL_RESPONSE")"
  vENV_S3_ACCESS_KEY="$(jq -r '.object_storage.s3_access_key' <<<"$vPREV_CURL_RESPONSE")"
  vENV_S3_SECRET="$(jq -r '.object_storage.s3_secret_key' <<<"$vPREV_CURL_RESPONSE")"
  vENV_S3_OBJECT_STORE="$(jq -r '.object_storage.label' <<<"$vPREV_CURL_RESPONSE")"

  export AWS_ACCESS_KEY_ID=$vENV_S3_ACCESS_KEY
  export AWS_SECRET_ACCESS_KEY=$vENV_S3_SECRET
  export AWS_ENDPOINT_URL="https://$vENV_S3_HOST"

  local bucket_exists="$(lib.vultr.s3.bucket_exists "postgres")"
  if [ "$bucket_exists" == false ]; then
    lib.vultr.s3.create_bucket "postgres"
    log.info "created bucket postgres for object storage ${label}"
  else
    log.warn "bucket postgres already exists at object storage ${label}"
  fi
}
