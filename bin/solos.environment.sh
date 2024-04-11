#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=solos.sh
. "shared/empty.sh"
# shellcheck source=solos.utils.sh
. "shared/empty.sh"
# shellcheck source=shared/static.sh
. "shared/empty.sh"

environment.generate_env_files() {
  local tmp_dir="$(mktemp -d 2>/dev/null)"
  local env_vars=$(grep -Eo 'vENV_[A-Z0-9_]{2,}' "$vENTRY_BIN_FILEPATH")
  for env_var in $env_vars; do
    local result="$(declare -p "$env_var" &>/dev/null && echo "set" || echo "unset")"
    if [ "$result" == "unset" ]; then
      log.error "Undefined env var: $env_var used in solos main script."
      exit 1
    else
      local env_val=${!env_var}
      if [ -z "$env_val" ]; then
        log.error "$env_var cannot be empty when building the .env file."
        exit 1
      fi
      local env_name=$(echo "$env_var" | sed 's/vENV_/ENV_/g' | tr '[:lower:]' '[:upper:]')
      local found="$(grep -q "^$env_name=" "$vCLI_OPT_DIR/$vSTATIC_ENV_FILENAME" &>/dev/null && echo "found" || echo "")"
      if [ -z "$found" ]; then
        echo "$env_name=$env_val" >>"$tmp_dir/$vSTATIC_ENV_FILENAME"
        echo "export $env_name=\"$env_val\"" >>"$tmp_dir/$vSTATIC_ENV_SH_FILENAME"
      fi
    fi
  done
  #
  # Wait until the files are built before moving them to their final location
  # in case we had to abort mid-loop.
  #
  rm -f "$vCLI_OPT_DIR/$vSTATIC_ENV_SH_FILENAME"
  rm -f "$vCLI_OPT_DIR/$vSTATIC_ENV_FILENAME"
  mv "$tmp_dir/$vSTATIC_ENV_SH_FILENAME" "$vCLI_OPT_DIR/$vSTATIC_ENV_SH_FILENAME"
  mv "$tmp_dir/$vSTATIC_ENV_FILENAME" "$vCLI_OPT_DIR/$vSTATIC_ENV_FILENAME"
  #
  # Cleanup tmp dir
  #
  rm -rf "$tmp_dir"
}
