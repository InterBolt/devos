#!/usr/bin/env bash
# Note on the shellcheck disabling here: unused variables are allowed
# because shellcheck can't tell that we're actually using them in other
# scripts sourced within this one.
# shellcheck disable=SC2034

set -o errexit

# We might need more here later, but for now the main thing
# is resetting the cursor via tput.
trap "tput cnorm" EXIT

cd "$(dirname "${BASH_SOURCE[0]}")"

# Will include dotfiles in globbing.
shopt -s dotglob

# Slots to store returns/responses. Bash don't allow rich return
# types, so we do this hacky shit instead.
vPREV_CURL_RESPONSE=""
vPREV_CURL_ERR_STATUS_CODE=""
vPREV_CURL_ERR_MESSAGE=""
vPREV_RETURN=()
vPREV_NEXT_ARGS=()

# shellcheck source=shared/static.sh
. "shared/static.sh"
# shellcheck source=shared/helpers.sh
. "shared/helpers.sh"

helpers.simple_flag_parser \
  --restricted-developer \
  "ARGS:" "$@"
set -- "${vPREV_NEXT_ARGS[@]}" || exit 1
vRESTRICTED_MODE_DEVELOPER=${vPREV_RETURN[1]:-false}

# A secret command that enables a developer to run ANY bash script by supplying "-"
# as the first argument and the path to the script as the second.
helpers.run_anything "$(cat "${vSTATIC_SOLOS_CONFIG_DIR}/host" || echo "")" "$@"

# Miscellanous values that are used throughout the script.
# calling them "meta" because they are mostly inferred, or
# derived from undocumented flags.
vSOLOS_RUNTIME=1
helpers.simple_flag_parser \
  --output \
  "ARGS:" "$@"
set -- "${vPREV_NEXT_ARGS[@]}" || exit 1
vSOLOS_STARTED_AT="$(date +%s)"
vSOLOS_LOG_LINE_COUNT="$(wc -l <"${vSTATIC_LOG_FILEPATH}" | xargs)"
vSOLOS_BIN_DIR="$(pwd)"
vSOLOS_BIN_FILEPATH="${vSOLOS_BIN_DIR}/$0"
vSOLOS_DEBUG=${DEBUG:-0}

# The vCLI_* values get set within the cli.parse.* functions.
vCLI_PARSED_CMD=""
vCLI_PARSED_OPTIONS=()

# These are not 1-1 mappings to option flags. But they ARE
# derived from the option flags.
vOPT_LIB=""
vOPT_FN=""

# Anything the user might supply either via a prompt or env
# variable should go here.
vSUPPLIED_OPENAI_API_KEY=""
vSUPPLIED_PROVIDER_API_KEY=""
vSUPPLIED_PROVIDER_NAME="vultr"
vSUPPLIED_ROOT_DOMAIN=""
vSUPPLIED_SEED_SECRET=""

# We need to acquire these things from the provisioning process.
vS3_HOST=""
vS3_OBJECT_STORE=""
vS3_ACCESS_KEY=""
vS3_SECRET=""

# Anything that requires provisioning to have already occured.
vPROJECT_IP=""
vPROJECT_NAME=""
vPROJECT_ID=""

# shellcheck source=shared/log.sh
. "shared/log.sh"

# Perform any code generation tasks here.
# For now, it's just generating a __source__.sh file for
# each of the bin's subdirs so we can source all files for
# any category at once.
if [[ ${vRESTRICTED_MODE_DEVELOPER} = true ]]; then
  chmod +x "shared/codegen.sh"
  . shared/codegen.sh
  shared.codegen.run "${vSTATIC_SOURCE_FILE}"
fi

# shellcheck source=pkg/__source__.sh
. "pkg/${vSTATIC_SOURCE_FILE}"
# shellcheck source=lib/__source__.sh
. "lib/${vSTATIC_SOURCE_FILE}"
# shellcheck source=cli/__source__.sh
. "cli/${vSTATIC_SOURCE_FILE}"
# shellcheck source=cmd/__source__.sh
. "cmd/${vSTATIC_SOURCE_FILE}"
# shellcheck source=provision/__source__.sh
. "provision/${vSTATIC_SOURCE_FILE}"

# Do this up top so that any missing heredocs will be caught early.
vHEREDOC_DEBIAN_INSTALL_DOCKER="$(lib.utils.heredoc 'debian-install-docker.sh')"

solos.ingest_test_options() {
  for i in "${!vCLI_PARSED_OPTIONS[@]}"; do
    case "${vCLI_PARSED_OPTIONS[$i]}" in
    lib=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [[ -n ${val} ]]; then
        vOPT_LIB="${val}"
        if [[ ! -f "lib/${vOPT_LIB}.sh" ]]; then
          log.error "Unknown error: lib/${vOPT_LIB}.sh does not exist."
          exit 1
        fi
      fi
      ;;
    fn=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [[ -n ${val} ]]; then
        vOPT_FN="${val}"
      else
        log.error "The --fn flag must be followed by a function name."
        exit 1
      fi
      ;;
    esac
  done
}
# The main user-facing options should get implemented here.
solos.ingest_main_options() {
  for i in "${!vCLI_PARSED_OPTIONS[@]}"; do
    case "${vCLI_PARSED_OPTIONS[$i]}" in
    project=*)
      if [[ ${vCLI_PARSED_CMD} != "checkout" ]]; then
        log.error "The --project flag is only valid for the 'checkout' command."
        exit 1
      fi
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [[ ! "${val}" =~ ^[a-z_-]*$ ]]; then
        log.error 'Invalid project name: '"${val}"'. Can only contain lowercase letters, underscores, and hyphens.'
        exit 1
      fi
      vPROJECT_NAME="${val}"
      ;;
    esac
  done
}
solos.collect_supplied_variables() {
  # Automatically generate a secret if one doesn't exist.
  vSUPPLIED_SEED_SECRET="$(lib.store.project.set_on_empty "secret" "$(lib.utils.generate_secret)")"
  # Prompts
  vSUPPLIED_PROVIDER_NAME="$(lib.store.project.prompt "provider_name" 'Only "vultr" is supported at this time.')"
  local path_to_provision_implementation="${vSOLOS_BIN_DIR}/provision/${vSUPPLIED_PROVIDER_NAME}.sh"
  if [[ ! -f ${path_to_provision_implementation} ]]; then
    log.error "Unknown provider: ${path_to_provision_implementation}. See the 'provision' directory for supported providers."
    lib.store.project.del "provider_name"
    solos.collect_supplied_variables
  fi
  vSUPPLIED_ROOT_DOMAIN="$(lib.store.project.prompt "root_domain")"
  if [[ ! "${vSUPPLIED_ROOT_DOMAIN}" =~ \.[a-z]+$ ]]; then
    log.error "Invalid root domain: ${vSUPPLIED_ROOT_DOMAIN}."
    lib.store.project.del "root_domain"
    solos.collect_supplied_variables
  fi
  vSUPPLIED_PROVIDER_API_KEY="$(lib.store.project.prompt "provider_api_key" 'Use your provider dashboard to create an API key.')"
  vSUPPLIED_OPENAI_API_KEY="$(lib.store.project.prompt "openai_api_key" 'Use the OpenAI dashboard to create an API key.')"
  # Try to grab things from project store
  vS3_OBJECT_STORE="$(lib.store.project.get "s3_object_store")"
  vS3_ACCESS_KEY="$(lib.store.project.get "s3_access_key")"
  vS3_SECRET="$(lib.store.project.get "s3_secret")"
  vS3_HOST="$(lib.store.project.get "s3_host")"
}
# Ensure the user doesn't have to supply the --project flag every time.
solos.use_checked_out_project() {
  vPROJECT_NAME="$(lib.store.global.get "project_name")"
  if [[ -z ${vPROJECT_NAME} ]]; then
    log.error "No project currently checked out."
    exit 1
  fi
  vPROJECT_ID="$(lib.utils.get_project_id)"
  if [[ -z ${vPROJECT_ID} ]]; then
    log.error "Unexpected error: no project ID found for ${vPROJECT_NAME}."
    exit 1
  fi
  vPROJECT_IP="$(lib.ssh.project_extract_project_ip)"
}

if [[ ${vRESTRICTED_MODE_DEVELOPER} = true ]]; then
  lib.utils.validate_interfaces \
    "${vSOLOS_BIN_DIR}/provision" \
    "${vSTATIC_INTERFACE_FILE}"
fi

# Parses CLI arguments into simpler data structures and validates against
# the usage strings in cli/usage.sh.
cli.parse.requirements
cli.parse.cmd "$@"
cli.parse.validate_opts

if [[ -z ${vCLI_PARSED_CMD} ]]; then
  exit 1
fi

if ! command -v "cmd.${vCLI_PARSED_CMD}" &>/dev/null; then
  log.error "No implementation for ${vCLI_PARSED_CMD} exists."
  exit 1
fi

# Assign the cli flag options to some of our global variables.
# Seperate "main" from "test" options to not overwhelm the user
# facing implementation.
solos.ingest_main_options
if [[ ${vCLI_PARSED_CMD} = "test" ]]; then
  solos.ingest_test_options
fi

"cmd.${vCLI_PARSED_CMD}"
