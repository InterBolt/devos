#!/usr/bin/env bash
# shellcheck disable=SC2115
set -o errexit
set -o pipefail
set -o errtrace

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi
#
# Variable naming notes:
#
#   - vENTRY_* tell things about the script at the moment it was invoked.
#   - vCLI_* derived from cli arguments and options
#   - vENV_* used to populate env files
#   - vSTATIC_* exported variables that are used across multiple scripts
#     - sourced from a file called static.
#       makes them accessible to non-bin scripts too if needed
#   - vPREV_* hold values from previous commands. allows more traditional
#     return based logic.
#   - vSTATUS_* strings that we use to track important statuses like
#     "did the bootstrap complete" or "did the launch succeed"
#
# Control flow notes:
#
#   => We define the most important variables first, vSTATIC_* and vENTRY_*.
#      These variables are should be treated like constant values and never re-assigned.
#   => We then initialize the empty definitions for all the variables that are subject to change.
#   => Next, initialize the logger and source all the solos.* libs we need.
#   => Next, define the trap logic to use utils.exit_trap and ensure that utils.exit_trap is defined.
#   => Next, defines some helper functions prefixed with solos.*.
#      These might become their own categories in the future.
#   => Then define the cmd.<command_name> functions where the <command_name> part maps to a command defined in the usage docs.
#      See the solos.flags file for those usage docs. The cmd.<command_name> functions are where the main logic of the script
#      is defined.
#   => Before a command is invoked a few things happen:
#        1. The cli arguments are parsed and the vCLI_* variables are set.
#        2. Verification logic is run to catch early errors. Things like checking dir contents, installed commands, etc.
#        3. Warnings are provided if the command and/or flag combinations will lead to destructive actions.
#        4. Finally, the command is run. If a cmd.* function doesn't exist, the script will throw.
#
# Pre-supplied configuratin:
#
# => I'm seeing some generalities start to form around byoPROVIDER and byoOBJECTSTORE.
#    Eventually we'll have some variables which are jq responses of a config json file that
#    the user can supply. We can build validation logic around these variables to ensure
#    that the user has supplied things we support. Like right now only vultr is supported.
#
# Misc notes:
#
#  => The launch command must be run to completion first. if it fails, it can be safely re-run once the issue is addressed.
#  => Zero code sharing between the server/* directories and these bin script files.
#  => The server/* directories are meant to be as self-contained as possible and rely on hook scripts to interact with the bin scripts.
#  => The bin script code prioritizes compatibility with popular linux distros and macOS.
#  => The cli is meant to be run on the developers original work machine.
#  => The server/* directories are where we can go crazy to target a specific platform.
#
# Lib testing notes:
#
# => multi step process to start:
#    1. run `solos test-generate` to create a .test dir with empty unit tests for each script's deifned command.
#    2. make manual modifications to the unit tests
#    3. run `solos test <lib>` to run the tests for a specific lib. or `solos test` to run all tests.
# => what happens if lots of things change?
#    1. it's not perfect, but just run the test generation command again, be human, and diff the changes.
#    2. additionally we can use `solos test-cover` to fill in missing coverage of new functions that will auto fail if not covered.
#
# Integration testing notes:
#
# => I think the pre-reqs to creating a good integration test are:
#      1. the vultr provisioning code and any other infra stuff must live behind a common interface.
#         then we can sub out the interface with some reasonable fakes and mocks and at least test the majority of the code paths.
#      2. the ssh code must be able to be subbed out with a fake ssh server.
#      3. we need a stub or fake server/* type directory that can be used to test the hooks.
# => We'll leave testing specific infra provisioning logic to our unit tests.
#
cd "$(dirname "${BASH_SOURCE[0]}")"

# shellcheck source=__shared__/static.sh
. "__shared__/static.sh"

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
vENV_PROVIDER_API_ENDPOINT="https://api.vultr.com/v2"
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
# shellcheck source=__shared__/log.sh
. "__shared__/log.sh"
#
# The log must be initialized before other dependent libs are sourced.
#
log.ready "cli" "${vSTATIC_MY_CONFIG_ROOT}/${vSTATIC_LOGS_DIRNAME}"
#
# Make the libraries we need available.
#
# shellcheck source=solos.cache.sh
. "solos.cache.sh"
# shellcheck source=solos.flags.sh
. "solos.flags.sh"
# shellcheck source=solos.ssh.sh
. "solos.ssh.sh"
# shellcheck source=solos.status.sh
. "solos.status.sh"
# shellcheck source=solos.utils.sh
. "solos.utils.sh"
# shellcheck source=solos.vultr.sh
. "solos.vultr.sh"
# shellcheck source=solos.validate.sh
. "solos.validate.sh"
# shellcheck source=solos.precheck.sh
. "solos.precheck.sh"
# shellcheck source=solos.environment.sh
. "solos.environment.sh"
#
# Return to the previous directory just in case.
#
cd "$vENTRY_BIN_DIR"
# --------------------------------------------------------------------------------------------
#
# TRAPPING LOGIC
#
# This is where we set up the error trapping logic.
# When I first created this all it did was log global variables.
#
if ! declare -f utils.exit_trap >/dev/null; then
  log.error "utils.exit_trap is not a defined function. Exiting."
  exit 1
fi
trap "utils.exit_trap" EXIT
# --------------------------------------------------------------------------------------------
#
# Utility functions that don't yet have their own categories, so we prefix
# them with solos.* to keep them organized and separate from the rest of the lib
# functions.
#
solos.map_parsed_cli() {
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
        if [ ! -f "solos.$vCLI_OPT_LIB" ]; then
          log.error "Unknown lib: $vCLI_OPT_LIB"
          exit 1
        fi
        log.debug "set \$vCLI_OPT_LIB= $vCLI_OPT_LIB"
      fi
      ;;
    "--clear-cache")
      vCLI_OPT_CLEAR_CACHE=true
      log.debug "set \$vCLI_OPT_CLEAR_CACHE= $vCLI_OPT_CLEAR_CACHE"
      ;;
    esac
  done
  if [ -z "$vCLI_OPT_DIR" ]; then
    vCLI_OPT_DIR="$(cache.get "checked_out")"
    if [ -z "$vCLI_OPT_DIR" ]; then
      log.error "No directory supplied or checked out in the cache. Please supply a --dir."
      exit 1
    fi
    log.debug "set \$vCLI_OPT_DIR= $vCLI_OPT_DIR"
  fi
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
  if [ -z "$vCLI_OPT_SERVER" ]; then
    log.error "Unexpected error: couldn't find a server type from either the --server flag or the checked out directory."
    exit 1
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
  if ! utils.template_variables "${tmp_launch_dir}" "commit" 2>&1; then
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
    git clone https://github.com/InterBolt/solos.git "${vCLI_OPT_DIR}/repo" 2>/dev/null
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
  local self_publickey_path="$(ssh.path_pubkey.self)"
  local self_privkey_path="$(ssh.path_privkey.self)"
  local self_authorized_keys_path="$(ssh.path_authorized_keys.self)"
  local self_config_path="$(ssh.path_config.self)"
  local self_ssh_dir_path="$(ssh.path.self)"
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
  if [ -z "$(status.get "$vSTATUS_LAUNCH_SUCCEEDED")" ]; then
    log.error "Launch status is still incomplete. Run (or fix whatever issues occured and re-run) the launch command."
    log.info "\`solos --help\` for more info."
    exit 1
  fi
  #
  # Feel free to add more paranoid checks here. The status above should cover us, but
  # it does rely on some trust that either the user didn't delete the status file or
  # that the launch script didn't leave out anything critical in a future change.
  #
  if ! ssh.cmd.remote '[ -d '"${vSTATIC_DEBIAN_CONFIG_ROOT}"' ]'; then
    log.error "Unexpected error: ${vSTATIC_DEBIAN_CONFIG_ROOT} not found on the remote."
    exit 1
  fi
}
solos.warn_with_delay() {
  local message="$1"
  if [ -z "$message" ]; then
    log.error "message must not be empty. Exiting."
    exit 1
  fi
  log.warn "$message in 5 seconds."
  sleep 3
  log.warn "$message in 2 seconds."
  sleep 2
  log.warn "$message here we go..."
  sleep 1
}
# --------------------------------------------------------------------------------------------
#
# COMMAND ENTRY FUNCTIONS
#
cmd.checkout() {
  #
  # Important: do these checks BEFORE saving the provided directory in the
  # cache. Let's be sure any directories we put there are valid and safe.
  #
  validate.throw_if_dangerous_dir
  validate.throw_if_missing_installed_commands
  #
  # The value of vCLI_OPT_SERVER is derived from either a flag value
  # or from the server type of the associated checked out directory.
  #
  # If a flag is provided that does not match the server specificed
  # in the checked out directory, we'll throw an error.
  #
  cache.set "checked_out" "$vCLI_OPT_DIR"
  log.info "checked out dir: $vCLI_OPT_DIR"
  if [ -f "$vCLI_OPT_DIR/$vSTATIC_SOLOS_ID_FILENAME" ]; then
    vENV_SOLOS_ID="$(cat "$vCLI_OPT_DIR/$vSTATIC_SOLOS_ID_FILENAME")"
    log.debug "set \$vENV_SOLOS_ID= $vENV_SOLOS_ID"
  fi
  if [ -f "$(ssh.path_config.self)" ]; then
    #
    # For the most part we can just assume the ip we extract here
    # is the correct one. The time where it isn't true is if we wipe our project's .ssh
    # dir and re-run the launch command. But since the cache files are in the global config
    # dir, we can always find it despite a wiped project dir.
    #
    # Important: a critical assumption is that the cache is never wiped between
    # the time we deleted the .ssh dir and the time we re-run the launch command.
    # In such a case, our script won't know what to de-provision and the user will
    # have to do that themselves through their provider's UI.
    # I think this is ok as long as clear warnings are put in place.
    #
    local most_recent_ip="$(ssh.extract_ip.remote)"
    cache.set "most_recent_ip" "$most_recent_ip"
    log.debug "updated the most recent ip in the cache."
  fi
}
cmd.launch() {
  cmd.checkout

  if [ "$vCLI_OPT_HARD_RESET" == true ]; then
    #
    # Will throw on a dir path that is either non-existent OR
    # doesn't contain any file/files specific to a solos project.
    #
    validate.throw_on_nonsolos
    solos.warn_with_delay "DANGER: about to \`rm -rf ${vCLI_OPT_DIR}\`"
    rm -rf "$vCLI_OPT_DIR"
    log.warn "wiped and created empty dir: $vCLI_OPT_DIR"
  fi
  #
  # Will only throw on a dir path that already exists AND
  # doesn't have a solos project-specific file. Doesn't care about non-existent dirs
  # since those will just result in new solos projects.
  #
  validate.throw_on_nonsolos_dir
  if [ ! -d "${vCLI_OPT_DIR}" ]; then
    mkdir -p "${vCLI_OPT_DIR}"
    log.info "created new SolOS project at: ${vCLI_OPT_DIR}"
    vENV_SOLOS_ID="$(utils.generate_secret)"
    echo "${vENV_SOLOS_ID}" >"${vCLI_OPT_DIR}/${vSTATIC_SOLOS_ID_FILENAME}"
    log.info "created new SolOS project at: ${vCLI_OPT_DIR} with id: ${vENV_SOLOS_ID}"
  fi
  if [ -f "${vCLI_OPT_DIR}/${vSTATIC_SOLOS_ID_FILENAME}" ]; then
    vENV_SOLOS_ID="$(cat "${vCLI_OPT_DIR}/${vSTATIC_SOLOS_ID_FILENAME}")"
    log.debug "set \$vENV_SOLOS_ID= ${vENV_SOLOS_ID}"
  fi
  #
  # We can only set the "server" once. Maybe in the future, we'll work in
  # a way to change the server type after the fact, but for now, I'm considering
  # it a one-time thing since there's so much logic tied to a particular server type
  # and I don't want to have to write hard to reason about, defensive code.
  #
  if [ ! -f "${vCLI_OPT_DIR}/${vSTATIC_SERVER_TYPE_FILENAME}" ]; then
    echo "${vCLI_OPT_SERVER}" >"${vSTATIC_SERVER_TYPE_FILENAME}"
    log.info "set server type: ${vCLI_OPT_SERVER}"
  fi
  #
  # This script is idempotent. But a warning doesn't hurt.
  #
  last_successful_run="$(status.get "$vSTATUS_LAUNCH_SUCCEEDED")"
  if [ -n "$last_successful_run" ]; then
    log.warn "the last successful run was at: $last_successful_run"
  fi
  solos.import_project_repo
  #
  # Confirm any assumptions we make later in the script.
  # Ex: the specified server exists, templates are valid, server/.boot dir valid, etc.
  # We want aggressive validates BEFORE the ssh keygen and vultr provisioning
  # sections since those create things that are harder to undo and debug.
  #
  validate.validate_project_repo "$vCLI_OPT_DIR/repo"
  #
  # Generate and collect things like the caprover password, postgres passwords.
  # api keys, etc.
  # Note: do not regenerate new passwords on subsequent runs unless we explicitly break
  # the cache or a force a hard reset.
  #
  local expects_these_things=(
    "vENV_SEED_SECRET"
    "vENV_GITHUB_USERNAME"
    "vENV_GITHUB_EMAIL"
    "vENV_GITHUB_TOKEN"
    "vENV_OPENAI_API_KEY"
    "vENV_PROVIDER_API_KEY"
    "vENV_PROVIDER_NAME"
    "vENV_PROVIDER_API_ENDPOINT"
  )
  #
  # TODO: we should rely on anything called `cache` for storing a value that when changed might
  # TODO[c]: bust lots of stuff on our remote server.
  #
  # ------------------------------------------------------------------------------------------------------------
  vENV_SEED_SECRET="$(cache.overwrite_on_empty "vENV_SEED_SECRET" "$(utils.generate_secret)")"
  log.debug "set \$vENV_SEED_SECRET= $vENV_SEED_SECRET"
  # ------------------------------------------------------------------------------------------------------------
  vENV_GITHUB_USERNAME="$(cache.overwrite_on_empty "vENV_GITHUB_USERNAME" "$(git config -l | grep user.name | cut -d = -f 2)")"
  log.debug "set \$vENV_GITHUB_USERNAME= $vENV_GITHUB_USERNAME"
  # ------------------------------------------------------------------------------------------------------------
  vENV_GITHUB_EMAIL="$(cache.overwrite_on_empty "vENV_GITHUB_EMAIL" "$(git config -l | grep user.email | cut -d = -f 2)")"
  log.debug "set \$vENV_GITHUB_EMAIL= $vENV_GITHUB_EMAIL"
  # ------------------------------------------------------------------------------------------------------------
  vENV_GITHUB_TOKEN="$(cache.prompt "vENV_GITHUB_TOKEN")"
  log.debug "set \$vENV_GITHUB_TOKEN= $vENV_GITHUB_TOKEN"
  # ------------------------------------------------------------------------------------------------------------
  vENV_OPENAI_API_KEY="$(cache.prompt "vENV_OPENAI_API_KEY")"
  log.debug "set \$vENV_OPENAI_API_KEY= $vENV_OPENAI_API_KEY"
  # ------------------------------------------------------------------------------------------------------------
  vENV_PROVIDER_API_KEY="$(cache.prompt "vENV_PROVIDER_API_KEY")"
  log.debug "set \$vENV_PROVIDER_API_KEY= $vENV_PROVIDER_API_KEY"
  # ------------------------------------------------------------------------------------------------------------
  vENV_PROVIDER_NAME="$(cache.prompt "vENV_PROVIDER_NAME")"
  log.debug "set \$vENV_PROVIDER_NAME= $vENV_PROVIDER_NAME"
  # ------------------------------------------------------------------------------------------------------------
  vENV_PROVIDER_API_ENDPOINT="$(cache.prompt "vENV_PROVIDER_API_ENDPOINT")"
  log.debug "set \$vENV_PROVIDER_API_ENDPOINT= $vENV_PROVIDER_API_ENDPOINT"
  # ------------------------------------------------------------------------------------------------------------
  for i in "${!expects_these_things[@]}"; do
    if [ -z "${!expects_these_things[$i]}" ]; then
      log.error "${expects_these_things[$i]} is empty. Exiting."
      exit 1
    fi
  done
  solos.build_project_ssh_dir
  #
  # On re-runs, the vultr provisioning functions will check for the existence
  # of the old ip and if it's the same as the current ip, it will skip the
  # provisioning process.
  #
  vultr.s3.provision
  log.success "vultr object storage is ready"
  #
  # prev_id is NOT the same as ip_to_deprovision.
  # when prev_id is set and is associated with a matching
  # ssh key, we "promote" it to vENV_IP and skip
  # much (or all) of the vultr provisioning process.
  #
  local most_recent_ip="$(cache.get "most_recent_ip")"
  local ip_to_deprovision="$(cache.get "ip_to_deprovision")"
  if [ -n "${most_recent_ip}" ]; then
    log.info "the ip \`$most_recent_ip\` from a previous run was found."
    log.info "if ssh keyfiles are the same, we will skip provisioning."
  fi
  vultr.compute.provision "$most_recent_ip"
  vENV_IP="${vPREV_RETURN[0]}"
  log.success "vultr compute is ready"
  #
  # I'm treating the vultr. functions as a black box and then doing
  # critical checks on the produced ip. Should throw when:
  # 1) vENV_IP is empty after provisioning
  # 2) the ip to deprovision in our cache is the same as vENV_IP
  #
  if [ -z "$vENV_IP" ]; then
    log.error "Unexpected error: the current ip is empty. Exiting."
    exit 1
  fi
  #
  #
  #
  if [ "$ip_to_deprovision" == "$vENV_IP" ]; then
    log.error "Unexpected error: the ip to deprovision is the same as the current ip. Exiting."
    exit 1
  fi
  #
  # After the sanity checks, if the ip changed, we're safe
  # to update the cache slots for the most recent ip and the
  # ip to deprovision.
  #
  # By putting the ip to deprovision in the cache, we ensure that
  # a hard reset won't stop our script from deprovisioning the old instance.
  # on future runs.
  #
  if [ "$vENV_IP" != "$most_recent_ip" ]; then
    cache.set "ip_to_deprovision" "$most_recent_ip"
    cache.set "most_recent_ip" "$vENV_IP"
  fi
  #
  # Generates the .env/.env.sh files by mapping all
  # global variables starting with vENV_* to both files.
  #
  environment.generate_env_files
  #
  # Builds the ssh config file for the remote server and
  # local docker dev container.
  # Important: the ssh config file is the source of truth for
  # our remote ip.
  #
  ssh.build.config_file "$ip"
  log.info "created: $(ssh.path_config.self)."
  #
  # Next, we want to form the launch directory inside of our project directory
  # using the `.launch` dirs from within the bin and server specific dirs.
  # Note: launch files are used later to bootstrap our environments.
  #
  solos.rebuild_project_launch_dir
  local project_launch_dir="${vCLI_OPT_DIR}/${vSTATIC_LAUNCH_DIRNAME}"
  #
  # Build and start the local docker container.
  # We set the COMPOSE_PROJECT_NAME environment variable to
  # the unique id of our project so that we can easily detect
  # whether or not a specific project's dev container is running.
  # Note: I'm being lazy and just cd'ing in and out to run the compose
  # command. This keeps the compose.yml config a little simpler.
  #
  local entry_dir="$PWD"
  cd "${project_launch_dir}"
  COMPOSE_PROJECT_NAME="solos-${vENV_SOLOS_ID}" docker compose --file compose.yml up --force-recreate --build --remove-orphans --detach
  log.info "docker container is ready"
  cd "$entry_dir"
  #
  # Important: don't upload the env files to the remote at all!
  # Instead, deployment scripts should take responsibility for
  # packaging anything required from those files when uploading
  # to the remote.
  #
  # Note: In a previous implementation I was making the above mistake.
  #
  local linux_sh_project_file="${project_launch_dir}/${vSTATIC_LINUX_SH_FILENAME}"
  if [ ! -f "$linux_sh_project_file" ]; then
    log.error "Unexpected error: $linux_sh_project_file not found. Exiting."
    exit 1
  fi
  ssh.rsync_up.remote "$linux_sh_project_file" "/root/"
  ssh.cmd.remote "chmod +x /root/${vSTATIC_LINUX_SH_FILENAME}"
  log.info "uploaded and set permissions for remote bootstrap script."
  #
  # Create the folder where we'll store out caprover
  # deployment tar files.
  #
  ssh.cmd.remote "mkdir -p /root/deployments"
  log.info "created remote deployment dir: /root/deployments"
  #
  # Before bootstrapping can occur, make sure we upload the .solos config folder
  # from our local machine to the remote machine.
  # Important: we don't need to do this with the docker container because we mount it
  #
  if ssh.cmd.remote '[ -d '"${vSTATIC_DEBIAN_CONFIG_ROOT}"' ]'; then
    log.warn "remote already has the global solos config folder. skipping."
    log.info "see \`solos --help\` for how to re-sync your local or docker dev config folder to the remote."
  else
    ssh.cmd.remote "mkdir -p ${vSTATIC_DEBIAN_CONFIG_ROOT}"
    log.info "created empty remote .solos config folder."
    ssh.rsync_up.remote "${vSTATIC_MY_CONFIG_ROOT}/" "${vSTATIC_DEBIAN_CONFIG_ROOT}/"
    log.info "uploaded local .solos config folder to remote."
  fi
  #
  #
  # The linux.sh file will run the env specific launch scripts.
  # Important: these env specific scripts should be idempotent and performant.
  #
  ssh.cmd.remote "/root/${vSTATIC_LINUX_SH_FILENAME} remote ${vCLI_OPT_SERVER}"
  #
  # We might want this status in the future
  #
  status.set "${vSTATUS_BOOTSTRAPPED_REMOTE}" "$(utils.date)"
  log.info "bootstrapped the remote server."
  #
  # Any type of manual action we need can be specified by a server by simply
  # creating a manual.txt file during it's bootstrap process. This script should have
  # zero awareness of the specifics of the manual.txt file.
  #
  # Example: this script used to understand that we needed caprover and postgres
  # but now it doesn't care. Instead, we'll put all the info for how to setup
  # any one-click-apps, databases, extra infra, etc. in the manual.txt file.
  #
  bootstrapped_manually_at="$(status.get "${vSTATUS_BOOTSTRAPPED_MANUALLY}")"
  if [ -n "${bootstrapped_manually_at}" ]; then
    log.warn "skipping manual bootstrap step - completed at ${bootstrapped_manually_at}"
  else
    ssh.rsync_down.remote "${vSTATIC_DEBIAN_ROOT}/${vSTATIC_MANUAL_FILENAME}" "${vCLI_OPT_DIR}/"
    log.debug "downloaded manual file to: ${vCLI_OPT_DIR}"
    log.info "review the manual instructions before continuing"
    utils.echo_line
    echo ""
    cat "${vCLI_OPT_DIR}/${vSTATIC_MANUAL_FILENAME}"
    echo ""
    utils.echo_line
    echo -n "Hit enter (0/2) to continue."
    read -r
    echo -n "Hit enter (1/2) to continue."
    read -r
    status.set "${vSTATUS_BOOTSTRAPPED_MANUALLY}" "$(utils.date)"
    log.info "completed manual bootstrap step. see \`solos --help\` for how to re-display manual instructions."
  fi
  #
  # The logic here is simpler because the bootstrap script for the docker container
  # will never deal with things like databases or service orchestration.
  #
  ssh.cmd.docker "${vSTATIC_DOCKER_MOUNTED_LAUNCH_DIR}/${vSTATIC_LINUX_SH_FILENAME} docker ${vCLI_OPT_SERVER}"
  status.set "${vSTATUS_BOOTSTRAPPED_DOCKER}" "$(utils.date)"
  log.info "bootstrapped the local docker container."
  #
  # This is redundant, but it's a good safety check because
  # if something bad happened and the old ip is the same as the current
  # we'll end up destroying the current instance. Yikes.
  #
  local ip_to_deprovision="$(cache.get "ip_to_deprovision")"
  if [ "${ip_to_deprovision}" == "${vENV_IP}" ]; then
    log.error "Unexpected error: the ip to deprovision is the same as the current ip. Exiting."
    exit 1
  fi
  #
  # The active ip should never be empty.
  #
  if [ -z "${vENV_IP}" ]; then
    log.error "Unexpected error: the current ip is empty. Exiting."
    exit 1
  fi
  #
  # Destroy the vultr instance associated with the old ip and then
  # delete the cache entry so this never happens twice.
  #
  if [ -n "${ip_to_deprovision}" ]; then
    solos.warn_with_delay "DANGER: destroying instance: ${ip_to_deprovision}"
    vultr.compute.get_instance_id_from_ip "${ip_to_deprovision}"
    local instance_id_to_deprovision="${vPREV_RETURN[0]}"
    if [ "${instance_id_to_deprovision}" == "null" ]; then
      log.error "Unexpected error: couldn't find instance for ip: \`${ip_to_deprovision}\`. Nothing to deprovision."
      exit 1
    fi
    vultr.compute.destroy_instance "${instance_id_to_deprovision}"
    log.info "destroyed the previous instance with ip: ${ip_to_deprovision}"
    cache.del "ip_to_deprovision"
    log.debug "deleted the ip_to_deprovision cache entry."
  fi
  status.set "${vSTATUS_LAUNCH_SUCCEEDED}" "$(utils.date)"
  log.success "launch completed successfully."
}
#
# This command likely occurs most often from within our docker dev container since that's where we'll do all
# our development work. Keep in mind syncing from local=>docker doesn't ever make sense since the docker container
# contains a mounted volume with the same config folder (renamed to /root/config instead of /root/.solos) as the local machine.
#
cmd.sync_config() {
  #
  # Note: most commands will require a fully launched project.
  #
  solos.require_completed_launch_status
  cmd.checkout
  solos.warn_with_delay "overwriting the remote config folder: ${vSTATIC_DEBIAN_CONFIG_ROOT}"
  local tmp_dir="/root/.tmp"
  local tmp_remote_config_dir="${tmp_dir}/${vSTATIC_CONFIG_DIRNAME}"
  #
  # Rsync the config up to a tmp dir first. Once everything is A+, force delete
  # the old config folder and move the new one to its place. Should limit downtime.
  #
  # Note: like most commands, we should be able to run this from within our docker container
  # no differently than if we were on the local machine. vSTATIC_MY_CONFIG_ROOT handles the
  # different absolute paths for local and docker since it uses the built-in $HOME variable.
  #
  ssh.cmd.remote "rm -rf ${tmp_remote_config_dir} && mkdir -p ${tmp_remote_config_dir}"
  log.info "wiped remote ${tmp_remote_config_dir} folder in preparation for rsync."
  ssh.rsync_up.remote "${vSTATIC_MY_CONFIG_ROOT}/" "${tmp_remote_config_dir}/"
  log.info "uploaded ${vSTATIC_MY_CONFIG_ROOT} to the remote server"
  ssh.cmd.remote "rm -rf ${vSTATIC_DEBIAN_CONFIG_ROOT} && mv ${tmp_remote_config_dir} ${vSTATIC_DEBIAN_CONFIG_ROOT}"
  log.info "overwrote remote's config:${vSTATIC_DEBIAN_CONFIG_ROOT} with ${vSTATIC_HOST}'s config: ${vSTATIC_MY_CONFIG_ROOT}."
  ssh.cmd.remote "rm -rf ${tmp_remote_config_dir}"
  log.debug "removed ${tmp_remote_config_dir} on the remote."
  log.info "success: synced config folder to remote."
}
cmd.code() {
  solos.require_completed_launch_status
  cmd.checkout

  if ! command -v "code" &>/dev/null; then
    log.error "vscode is not installed to your path. cannot continue."
  fi
  if [ "$vSTATIC_HOST" != "local" ]; then
    log.error "this command must be run from the local host. Exiting."
    exit 1
  fi
  validate.docker_host_running

  log.warn "would open vscode"
}
cmd.restore() {
  solos.require_completed_launch_status
  cmd.checkout

  if [ "$vSTATIC_HOST" == "local" ]; then
    validate.docker_host_running
  fi
  log.warn "TODO: implementation needed"
}
cmd.backup() {
  solos.require_completed_launch_status
  cmd.checkout

  if [ "$vSTATIC_HOST" == "local" ]; then
    validate.docker_host_running
  fi
  log.warn "TODO: implementation needed"
}
cmd.status() {
  if [ -z "$vCLI_OPT_DIR" ]; then
    vCLI_OPT_DIR="$(cache.get "checked_out")"
  fi
  if [ -z "$vCLI_OPT_DIR" ]; then
    log.error "no project found at: $vCLI_OPT_DIR. if you moved it, use the --dir flag to specify the new location."
    exit 1
  fi
  if [ ! -f "$vCLI_OPT_DIR/$vSTATIC_SERVER_TYPE_FILENAME" ]; then
    log.error "$vCLI_OPT_DIR doesn't appear to be a solos project. Exiting."
    exit 1
  fi
  #
  # If we're here, we know we have a project directory.
  # Let's go ahead and throw errors when base assumptions
  # like having a config dir are not met.
  #
  log.info "TODO: implementation needed"
}
cmd.prechecks() {
  cmd.checkout

  if [ "$vSTATIC_RUNNING_IN_GIT_REPO" == "true" ] && [ "$vSTATIC_HOST" == "local" ]; then
    precheck.all
  else
    log.error "this command can only be run from within a git repo."
    exit 1
  fi
}
cmd.tests() {
  cmd.checkout

  if [ "$vSTATIC_RUNNING_IN_GIT_REPO" == "true" ] && [ "$vSTATIC_HOST" == "local" ]; then
    if [ -z "$vCLI_OPT_LIB" ]; then
      __cmds__/tests.sh
    else
      __cmds__/tests.sh "$vCLI_OPT_LIB"
    fi
  else
    log.error "this command can only be run from within a git repo."
    exit 1
  fi
}
# --------------------------------------------------------------------------------------------
#
# ENTRY
#
# parse the cli args and validate them.
#
flags.parse_requirements
flags.parse_cmd "$@"
flags.validate_options
#
# We seperate the parsing and mapping concerns so that
# frequent changes to business logic don't affect the parsing logic
#
solos.map_parsed_cli
#
# Before doing ANYTHING, check that our command actually works.
# Fail fast!
#
if ! command -v "cmd.$vCLI_PARSED_CMD" &>/dev/null; then
  log.error "cmd.$vCLI_PARSED_CMD is not defined. Exiting."
  exit 1
fi
#
# We're only allowed to clear cache files associated with a particular named installation.
#
if [ "$vCLI_OPT_CLEAR_CACHE" == "true" ]; then
  solos.warn_with_delay "DANGER: clearing cache files associated with: ${vCLI_OPT_DIR}"
  cache.clear
fi
#
# Run the command specified in the cli args.
#
"cmd.$vCLI_PARSED_CMD"
