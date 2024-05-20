#!/usr/bin/env bash

cmd.provision._collect_provider() {
  local provider_name="$(lib.secrets.get "s3_provider")"
  if [[ -z ${provider_name} ]]; then
    provider_name="$(gum_s3_provider)"
    if [[ -z ${provider_name} ]]; then
      log_error "No provider was selected. Exiting."
      exit 1
    fi
  fi
  echo "${provider_name}"
}

cmd.provision._collect_api_key() {
  local api_key="$(lib.secrets.get "s3_provider_api_key")"
  if [[ -z ${api_key} ]]; then
    local tmp_file="$(mktemp)"
    gum_s3_provider_api_key >"${tmp_file}"
    lib.secrets.set "s3_provider_api_key" "$(cat "${tmp_file}")"
    rm -f "${tmp_file}"
    cmd.provision._collect_api_key
    return 0
  fi
  echo "${api_key}"
}

cmd.provision() {
  solos.use_checked_out_project
  local provider_name="$(cmd.provision._collect_provider)"
  local api_key="$(cmd.provision._collect_api_key)"
  log_info "${vPROJECT_NAME} - Provisioning S3-compatible storage using \"${provider_name}\""
  # s3_provider."${provider_name}".init will always echo back 4 lines where line
  # 1 = s3_object_store
  # 2 = s3_access_key
  # 3 = s3_secret
  # 4 = s3_host
  local s3_info="$("s3_provider.${provider_name}.init" "${api_key}")"
  local s3_object_store="$(echo "${s3_info}" | sed -n 1p)"
  local s3_access_key="$(echo "${s3_info}" | sed -n 2p)"
  local s3_secret="$(echo "${s3_info}" | sed -n 3p)"
  local s3_host="$(echo "${s3_info}" | sed -n 4p)"
  lib.secrets.set "s3_object_store" "${s3_object_store}"
  lib.secrets.set "s3_access_key" "${s3_access_key}"
  lib.secrets.set "s3_secret" "${s3_secret}"
  lib.secrets.set "s3_host" "${s3_host}"
  log.info "Provisioned S3-compatible storage for ${vPROJECT_NAME} using \"${provider_name}\""
}
