#!/usr/bin/env bash
# shellcheck disable=SC2115
set -o errexit
set -o pipefail
set -o errtrace

#
# In the solos_base.sh script, we use the existence of this variable
# to determine if we should continue. We do this because we're using
# fake shellcheck source comments/paths to get IDE support for everything
# that exists in this script.
#
vFROM_BIN_SCRIPT=true

cd "$(dirname "${BASH_SOURCE[0]}")"

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=shared/static.sh
. "shared/static.sh"

vENTRY_BIN_DIR="$(pwd)"
vENTRY_BIN_FILEPATH="$vENTRY_BIN_DIR/$0"
vENTRY_DEBUG_LEVEL=${DEBUG_LEVEL:-0}
#
# `dotglob` option ensures that dotfiles and folders are included when using globs.
# Helpful for looping through files in a directory.
#
shopt -s dotglob
# --------------------------------------------------------------------------------------------
#
# RESPONSE/RETURN SLOTS
#
vPREV_CURL_RESPONSE=""
vPREV_CURL_ERR_STATUS_CODE=""
vPREV_CURL_ERR_MESSAGE=""
vPREV_RETURN=()
# --------------------------------------------------------------------------------------------
#
# STATUSES:
#
# These are used to keep track of various statuses, like "did the bootstrap complete"
#
vSTATUS_BOOTSTRAPPED_MANUALLY="completed-manual"
vSTATUS_BOOTSTRAPPED_REMOTE="completed-remote"
vSTATUS_LAUNCH_SUCCEEDED="completed-launch"
vSTATUS_BOOTSTRAPPED_DOCKER="completed-docker"
# --------------------------------------------------------------------------------------------
#
# OPTIONS DERIVED FROM THE CLI
#
vCLI_USAGE_ALLOWS_CMDS=()
vCLI_USAGE_ALLOWS_OPTIONS=()
vCLI_PARSED_CMD=""
vCLI_PARSED_OPTIONS=()
vCLI_OPT_HARD_RESET=false
vCLI_OPT_CLEAR_CACHE=false
vCLI_OPT_TAG=""
vCLI_OPT_LIB=""
vCLI_OPT_FN=""
vCLI_OPT_DIR=""
vCLI_OPT_SERVER=""
# --------------------------------------------------------------------------------------------
#
# config that get passed to each environment.
#
# shellcheck disable=SC2034
vENV_OPENAI_API_KEY=""
# shellcheck disable=SC2034
vENV_PROVIDER_API_KEY=""
# shellcheck disable=SC2034
vENV_PROVIDER_NAME="vultr"
# shellcheck disable=SC2034
vENV_PROVIDER_API_ENDPOINT="https://api.lib.vultr.com/v2"
# shellcheck disable=SC2034
vENV_GITHUB_TOKEN=""
# shellcheck disable=SC2034
vENV_IP=""
# shellcheck disable=SC2034
vENV_S3_HOST=""
# shellcheck disable=SC2034
vENV_S3_OBJECT_STORE=""
# shellcheck disable=SC2034
vENV_S3_ACCESS_KEY=""
# shellcheck disable=SC2034
vENV_S3_SECRET=""
# shellcheck disable=SC2034
vENV_GITHUB_USERNAME=""
# shellcheck disable=SC2034
vENV_GITHUB_EMAIL=""
# shellcheck disable=SC2034
vENV_SEED_SECRET=""
# shellcheck disable=SC2034
vENV_DB_PORT=5432
# shellcheck disable=SC2034
vENV_SOLOS_ID=""
#
# The log script has no awareness of the variables in this script.
# That means we need to provide any context via it's log.ready
# function.
#
# shellcheck source=shared/log.sh
. "shared/log.sh"
#
# The log must be initialized before other dependent libs are sourced.
#
log.ready "solos" "${vSTATIC_MY_CONFIG_ROOT}/${vSTATIC_LOGS_DIRNAME}"
#
# Make the libraries we need available.
#
# shellcheck source=lib.cache.sh
. "lib.cache.sh"
# shellcheck source=lib.env.sh
. "lib.env.sh"
# shellcheck source=lib.ssh.sh
. "lib.ssh.sh"
# shellcheck source=lib.status.sh
. "lib.status.sh"
# shellcheck source=lib.utils.sh
. "lib.utils.sh"
# shellcheck source=lib.validate.sh
. "lib.validate.sh"
# shellcheck source=lib.vultr.sh
. "lib.vultr.sh"
#
# Load our CLI parsing commands.
#
# shellcheck source=cli/__source__.sh
. "cli/__source__.sh"
#
# Generate source statements for each command in the __source__.sh file.
# Ensures I won't release a version of solos that is mising commands.
#
if [ "$vMODE" != "production" ]; then
  . cmd/gen.sh
fi
#
# Now make the commands we need available.
#
# shellcheck source=cmd/__source__.sh
. "cmd/__source__.sh"
#
# --------------------------------------------------------------------------------------------
#
# TRAPPING LOGIC
#
# This is where we set up the error trapping logic.
# When I first created this all it did was log global variables.
#
if ! declare -f lib.utils.exit_trap >/dev/null; then
  log.error "lib.utils.exit_trap is not a defined function. Exiting."
  exit 1
fi
trap "lib.utils.exit_trap" EXIT
# --------------------------------------------------------------------------------------------
#
# Utility functions that don't yet have their own categories, so we prefix
# them with lib.* to keep them organized and separate from the rest of the lib
# functions.
#
solos.apply_parsed_cli_args() {
  local was_server_set=false
  if [ -z "$vCLI_PARSED_CMD" ]; then
    log.error "No command supplied. Please supply a command."
    exit 1
  fi
  for i in "${!vCLI_PARSED_OPTIONS[@]}"; do
    case "${vCLI_PARSED_OPTIONS[$i]}" in
    "hard-reset")
      vCLI_OPT_HARD_RESET=true
      log.debug "set \$vCLI_OPT_HARD_RESET= $vCLI_OPT_HARD_RESET"
      ;;
    dir=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [ "$val" == "$HOME" ]; then
        log.error "Danger: --dir flag cannot be set to the home directory. Exiting."
        exit 1
      fi
      if [[ "$HOME" == "$val"* ]]; then
        log.error "Danger: --dir flag cannot be set to a parent directory of the home directory. Exiting."
        exit 1
      fi
      vCLI_OPT_DIR="$val"
      log.debug "set \$vCLI_OPT_DIR= $vCLI_OPT_DIR"
      ;;
    server=*)
      #
      # Always ignore unless this was provided for the launch command.
      # Prefer the user to rely on the saved server type inside their projects
      # dir (aka $vCLI_OPT_DIR).
      #
      if [ "$vCLI_PARSED_CMD" == "launch" ]; then
        val="${vCLI_PARSED_OPTIONS[$i]#*=}"
        vCLI_OPT_SERVER="$val"
        was_server_set=true
        log.debug "set \$vCLI_OPT_SERVER= $vCLI_OPT_SERVER"
      fi
      ;;
    tag=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [ -n "$val" ]; then
        vCLI_OPT_TAG="$val"
        log.debug "set \$vCLI_OPT_TAG= $vCLI_OPT_TAG"
      fi
      ;;
    lib=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [ -n "$val" ]; then
        vCLI_OPT_LIB="$val"
        if [ ! -f "lib.$vCLI_OPT_LIB" ]; then
          log.error "Unknown lib: $vCLI_OPT_LIB"
          exit 1
        fi
        log.debug "set \$vCLI_OPT_LIB= $vCLI_OPT_LIB"
      fi
      ;;
    fn=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [ -n "${val}" ]; then
        vCLI_OPT_FN="${val}"
        if ! declare -f "${vCLI_OPT_FN}" >/dev/null; then
          log.error "Unknown function: ${vCLI_OPT_FN}. Cannot run tests."
          exit 1
        fi
        log.debug "set \$vCLI_OPT_FN= ${vCLI_OPT_FN}"
      else
        log.error "The --fn flag must be followed by a function name."
        exit 1
      fi
      ;;
    esac
  done
  local projects_server_type_file="${vCLI_OPT_DIR}/${vSTATIC_SERVER_TYPE_FILENAME}"
  if [ "${was_server_set}" == "true" ]; then
    if [ -f "${projects_server_type_file}" ]; then
      local projects_server_type="$(cat "${projects_server_type_file}")"
      if [ -z "${projects_server_type}" ]; then
        log.error "Unexpected error: ${projects_server_type_file} is empty"
        exit 1
      fi
      if [ -z "${vCLI_OPT_SERVER}" ]; then
        log.error "Unexpected error: --server flag was provided with an empty value."
        exit 1
      fi
      if [ "${projects_server_type}" != "${vCLI_OPT_SERVER}" ]; then
        log.error "cannot change the server type after the initial launch command is run"
        log.error "found: \`${projects_server_type}\`, you provided: \`${vCLI_OPT_SERVER}\`"
        log.error "only a hard reset (use with caution) can change the server type."
        log.info "\`solos --help\` for more info."
        exit 1
      fi
    fi
  elif [ -f "${projects_server_type_file}" ]; then
    vCLI_OPT_SERVER="$(cat "${projects_server_type_file}")"
    log.debug "set \$vCLI_OPT_SERVER= $vCLI_OPT_SERVER"
  fi
}
solos.rebuild_project_launch_dir() {
  #
  # Important: we want to approach the files inside of the launch
  # dir as ephemeral and not worry about overwriting them.
  # This is helpful too in future proofing the script against changes
  # to the project directory location outside of the cli.
  #
  #
  # The server launch dir contains launch files specific to the server type.
  #
  local server_launch_dir="${vCLI_OPT_DIR}/repo/${vSTATIC_REPO_SERVERS_DIR}/${vCLI_OPT_SERVER}/${vSTATIC_LAUNCH_DIRNAME}"
  #
  # The bin launch dir contains launch files that are shared across all server types.
  # Ex: code-workspace files, docker compose.yml file, standard linux startup script, etc.
  #
  local bin_launch_dir="${vCLI_OPT_DIR}/repo/${vSTATIC_BIN_LAUNCH_DIR}"
  #
  # We'll combine the above launch dir files and do some variable
  # injection on them to create the final launch directory.
  #
  local project_launch_dir="${vCLI_OPT_DIR}/${vSTATIC_LAUNCH_DIRNAME}"
  #
  # Prevent an error from resulting in a partially incomplete launch dir
  # by building everything in a tmp dir and then moving it over.
  #
  local tmp_dir="${vCLI_OPT_DIR}/.tmp"
  local tmp_launch_dir="${tmp_dir}/${vSTATIC_LAUNCH_DIRNAME}"
  if [ -d "$project_launch_dir" ]; then
    log.warn "rebuilding the launch directory."
  fi
  rm -rf "${tmp_launch_dir}"
  mkdir -p "${tmp_launch_dir}"
  #
  # Clarification: I don't expect the server specific launch files to
  # require variable injection, however variable injection will still work
  # since we call the injection command on the fully built directory
  # which contains both server specific and shared launch files.
  #
  # The only reason why I don't expect the server specific launch files to
  # require variable injection is because they are NOT meant to be aware of
  # variables residing in this script.
  #
  cp -a "${server_launch_dir}/." "${tmp_launch_dir}/"
  log.debug "copied: ${server_launch_dir} to ${tmp_launch_dir}"
  cp -a "${bin_launch_dir}/." "${tmp_launch_dir}/"
  log.debug "copied: ${bin_launch_dir} to ${tmp_launch_dir}"
  if ! lib.utils.template_variables "${tmp_launch_dir}" "commit" 2>&1; then
    log.error "something unexpected happened while injecting variables into the launch directory."
    exit 1
  fi
  log.debug "injected variables into the tmp launch directory."
  rm -rf "${project_launch_dir}"
  log.debug "deleted: ${project_launch_dir}"
  mv "${tmp_launch_dir}" "${project_launch_dir}"
  log.info "successfully rebuilt ${project_launch_dir}"
}
solos.import_project_repo() {
  #
  # Rather than download portions of the repo we need, we prefer
  # to rely on a full clone in each project directory.
  #
  # Note: maybe in the future, if we want to prevent re-runs of the
  # launch command from busting our version of the repo in our project
  # we can automate forking the repo on the initial clone so that pulls
  # won't cause any issues. But for now, the forking needs to occur
  # manually by the user in their project.
  #
  if [ -d "${vCLI_OPT_DIR}/repo" ]; then
    log.warn "the SolOS repo was already cloned to ${vCLI_OPT_DIR}/repo."
    log.info "pulling latest changes on checked out branch."
    #
    # Use the -C option instead of cd'ing to
    # maintain working directory.
    #
    git -C "${vCLI_OPT_DIR}/repo" pull 2>/dev/null
    log.info "pulled latest changes."
  else
    git clone https://github.com/InterBolt/lib.git "${vCLI_OPT_DIR}/repo" 2>/dev/null
    log.info "cloned the SolOS repo to ${vCLI_OPT_DIR}/repo."
  fi
  if [ ! -d "${vCLI_OPT_DIR}/repo/${vSTATIC_REPO_SERVERS_DIR}/${vCLI_OPT_SERVER}" ]; then
    log.error "The server ${vCLI_OPT_SERVER} does not exist in the SolOS repo. Exiting."
    exit 1
  fi
  find "${vCLI_OPT_DIR}/repo" -type f -name "*.sh" -exec chmod +x {} \;
  chmod +x "${vCLI_OPT_DIR}/repo/bin/solos"
  find "${vCLI_OPT_DIR}/repo/bin" -type f -name "solos*" -exec chmod +x {} \;
  chmod +x "${vCLI_OPT_DIR}/repo/install"
  log.info "set permissions for all shell scripts in: ${vCLI_OPT_DIR}/repo"
}
solos.build_project_ssh_dir() {
  local self_publickey_path="$(lib.ssh.path_pubkey.self)"
  local self_privkey_path="$(lib.ssh.path_privkey.self)"
  local self_authorized_keys_path="$(lib.ssh.path_authorized_keys.self)"
  local self_config_path="$(lib.ssh.path_config.self)"
  local self_ssh_dir_path="$(lib.ssh.path.self)"
  #
  # This is the dir we'll use to store all the keyfiles required
  # by our local, docker dev container, and remote server.
  # Important: if a dev manually deletes this dir before re-running a launch,
  # infra will get recreated and the keys will get regenerated.
  #
  if [ ! -d "${self_ssh_dir_path}" ]; then
    mkdir -p "${self_ssh_dir_path}"
    log.info "created: ${self_ssh_dir_path}"
    ssh-keygen -t rsa -q -f "${self_privkey_path}" -N ""
    log.info "created private key: ${self_privkey_path}, public key: ${self_publickey_path}"
    cat "${self_publickey_path}" >"${self_authorized_keys_path}"
    log.info "created ${self_authorized_keys_path}"
  fi
  chmod 644 "${self_authorized_keys_path}"
  log.debug "updated permissions: chmod 644 - ${self_authorized_keys_path}"
  chmod 644 "${self_publickey_path}"
  log.debug "updated permissions: chmod 644 - ${self_publickey_path}"
  chmod 644 "${self_config_path}"
  log.debug "updated permissions: chmod 644 - ${self_config_path}"
  chmod 600 "${self_privkey_path}"
  log.debug "updated permissions: chmod 600 - ${self_privkey_path}"
}
solos.require_completed_launch_status() {
  if [ -z "$(lib.status.get "$vSTATUS_LAUNCH_SUCCEEDED")" ]; then
    log.error "Launch status is still incomplete. Run (or fix whatever issues occured and re-run) the launch command."
    log.info "\`solos --help\` for more info."
    exit 1
  fi
  #
  # Feel free to add more paranoid checks here. The status above should cover us, but
  # it does rely on some trust that either the user didn't delete the status file or
  # that the launch script didn't leave out anything critical in a future change.
  #
  if ! lib.ssh.command.remote '[ -d '"${vSTATIC_SERVER_CONFIG_ROOT}"' ]'; then
    log.error "Unexpected error: ${vSTATIC_SERVER_CONFIG_ROOT} not found on the remote."
    exit 1
  fi
}
# --------------------------------------------------------------------------------------------
#
# ENTRY
#
# parse the cli args and validate them.
#
cli.parse.requirements
cli.parse.cmd "$@"
cli.parse.validate_opts
#
# We seperate the parsing and mapping concerns so that
# frequent changes to business logic don't affect the parsing logic
#
solos.apply_parsed_cli_args
#
# Before doing ANYTHING, check that our command actually exists.
#
if ! command -v "cmd.$vCLI_PARSED_CMD" &>/dev/null; then
  log.error "cmd.$vCLI_PARSED_CMD is not defined. Exiting."
  exit 1
fi
#
# Run the command specified in the cli args.
#
"cmd.$vCLI_PARSED_CMD"
