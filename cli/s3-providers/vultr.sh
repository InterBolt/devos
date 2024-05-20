#!/usr/bin/env bash

vSELF_PROVISION_VULTR_API_ENDPOINT="https://api.lib.vultr.com/v2"
vSELF_PROVISION_VULTR_API_TOKEN=""
vSELF_VULTR_CURL_RESPONSE=""

s3_provider.vultr._get_object_storage_id() {
  local label="solos-${vPROJECT_ID}"
  local object_storage_id=""
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/object-storage" \
    -X GET \
    -H "Authorization: Bearer ${vSELF_PROVISION_VULTR_API_TOKEN}"
  lib.utils.curl.allows_error_status_codes "none"
  local object_storage_labels=$(jq -r '.object_storages[].label' <<<"${vSELF_VULTR_CURL_RESPONSE}")
  local object_storage_ids=$(jq -r '.object_storages[].id' <<<"${vSELF_VULTR_CURL_RESPONSE}")
  for i in "${!object_storage_labels[@]}"; do
    if [[ ${object_storage_labels[$i]} = ${label} ]]; then
      object_storage_id="${object_storage_ids[$i]}"
      break
    fi
  done
  if [[ -n ${object_storage_id} ]]; then
    echo "${object_storage_id}"
  else
    echo ""
  fi
}

s3_provider.vultr._get_ewr_cluster_id() {
  local cluster_id=""
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/object-storage/clusters" \
    -X GET \
    -H "Authorization: Bearer ${vSELF_PROVISION_VULTR_API_TOKEN}"
  lib.utils.curl.allows_error_status_codes "none"
  local cluster_ids=$(jq -r '.clusters[].id' <<<"${vSELF_VULTR_CURL_RESPONSE}")
  local cluster_regions=$(jq -r '.clusters[].region' <<<"${vSELF_VULTR_CURL_RESPONSE}")
  for i in "${!cluster_regions[@]}"; do
    if [[ ${cluster_regions[$i]} = "ewr" ]]; then
      cluster_id="${cluster_ids[$i]}"
      break
    fi
  done
  echo "${cluster_id}"
}

s3_provider.vultr._create_storage() {
  local cluster_id="$1"
  local label="solos-${vPROJECT_ID}"
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/object-storage" \
    -X POST \
    -H "Authorization: Bearer ${vSELF_PROVISION_VULTR_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data '{
        "label" : "'"${label}"'",
        "cluster_id" : '"${cluster_id}"'
      }'
  lib.utils.curl.allows_error_status_codes "none"
  local object_storage_id=$(jq -r '.object_storage.id' <<<"${vSELF_VULTR_CURL_RESPONSE}")
  echo "${object_storage_id}"
}

s3_provider.vultr.init() {
  local api_key="${1}"
  if [[ -z ${api_key} ]]; then
    log_error "No API key provided."
    exit 1
  fi
  vSELF_PROVISION_VULTR_API_TOKEN="${api_key}"
  local object_storage_id="$(s3_provider.vultr._get_object_storage_id)"
  if [[ -z ${object_storage_id} ]]; then
    # Create the storage is the EWR region (east I think?)
    local ewr_cluster_id="$(s3_provider.vultr._get_ewr_cluster_id)"
    object_storage_id="$(s3_provider.vultr._create_storage "${ewr_cluster_id}")"
  fi
  lib.utils.curl "${vSELF_PROVISION_VULTR_API_ENDPOINT}/object-storage/${object_storage_id}" \
    -X GET \
    -H "Authorization: Bearer ${vSELF_PROVISION_VULTR_API_TOKEN}"
  lib.utils.curl.allows_error_status_codes "none"
  jq -r '.object_storage.s3_hostname' <<<"${vSELF_VULTR_CURL_RESPONSE}"
  jq -r '.object_storage.s3_access_key' <<<"${vSELF_VULTR_CURL_RESPONSE}"
  jq -r '.object_storage.s3_secret_key' <<<"${vSELF_VULTR_CURL_RESPONSE}"
  jq -r '.object_storage.label' <<<"${vSELF_VULTR_CURL_RESPONSE}"
}
