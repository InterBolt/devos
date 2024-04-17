#!/usr/bin/env bash

# Note on the shellcheck disabling here: unused variables are allowed
# because shellcheck can't tell that we're actually using them in other
# scripts sourced within this one.
# shellcheck disable=SC2034

# Serves as a "test" run immediately after initial install.
# Important: must be first thing this script does.
for entry_arg in "$@"; do
  if [[ $entry_arg = "--noop" ]]; then
    exit 0
  fi
done

if ! cd "$(dirname "${BASH_SOURCE[0]}")"; then
  echo "Unexpected error: could not cd into 'dirname \"\${BASH_SOURCE[0]}\"'" >&2
  exit 1
fi

# The parent must always be a bin folder. This covers dev case and
# `/usr/local/bin/solos` case.
if [[ "$(basename "$(pwd)")" != "bin" ]]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# Will include dotfiles in globbing.
shopt -s dotglob

# Let's other sourced scripts know for certain that they're running in the
# context of the SOLOS cli.
vRUNNING_IN_SOLOS=true

# A secret command that we can use to run any script we want in the installed repo.
# Extremely helpful for development where I need to test a bit of bash before integrating
# into the CLI.
if [[ $1 = "-" ]]; then
  cd .. || exit 1
  "$PWD/$2"
  exit 0
fi

# shellcheck source=shared/static.sh
. "shared/static.sh"

vMETA_DEVELOPER_MODE=false
if [[ $1 = "--dev" ]]; then
  vMETA_DEVELOPER_MODE=true
  shift
fi
vMETA_USE_FOREGROUND_LOGS=false
for entry_arg in "$@"; do
  if [[ $entry_arg = "--foreground" ]]; then
    set -- "${@/--foreground/}"
    vMETA_USE_FOREGROUND_LOGS=true
  fi
done
vMETA_START_SECONDS="${SECONDS}"
vMETA_LOG_LINE_COUNT="$(wc -l <"${vSTATIC_LOG_FILEPATH}" | xargs)"
vMETA_BIN_DIR="$(pwd)"
vMETA_BIN_FILEPATH="$vMETA_BIN_DIR/$0"
vMETA_DEBUG_LEVEL=${DEBUG_LEVEL:-0}

vPREV_CURL_RESPONSE=""
vPREV_CURL_ERR_STATUS_CODE=""
vPREV_CURL_ERR_MESSAGE=""
vPREV_RETURN=()

vSTATUS_BOOTSTRAPPED_MANUALLY="completed-manual"
vSTATUS_BOOTSTRAPPED_REMOTE="completed-remote"
vSTATUS_LAUNCH_SUCCEEDED="completed-launch"
vSTATUS_BOOTSTRAPPED_DOCKER="completed-docker"

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

if [[ ${vMETA_DEVELOPER_MODE} = true ]]; then
  chmod +x "shared/codegen.sh"
  shared/codegen.sh
fi

# shellcheck source=shared/log.sh
. "shared/log.sh"
# shellcheck source=pkg/__source__.sh
. "pkg/__source__.sh"
# shellcheck source=lib/__source__.sh
. "lib/__source__.sh"
# shellcheck source=cli/__source__.sh
. "cli/__source__.sh"
# shellcheck source=cmd/__source__.sh
. "cmd/__source__.sh"

# Utility functions that don't yet have their own categories, so we prefix
# them with lib.* to keep them organized and separate from the rest of the lib
# functions.
solos.apply_parsed_cli_args() {
  local was_server_set=false
  if [[ -z ${vCLI_PARSED_CMD} ]]; then
    log.error "No command supplied. Please supply a command."
    exit 1
  fi
  for i in "${!vCLI_PARSED_OPTIONS[@]}"; do
    case "${vCLI_PARSED_OPTIONS[$i]}" in
    "hard-reset")
      vCLI_OPT_HARD_RESET=true
      ;;
    dir=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [[ "$val" = "${HOME}" ]]; then
        log.error "Danger: --dir flag cannot be set to the home directory. Exiting."
        exit 1
      fi
      if [[ ${HOME} = "${val}"* ]]; then
        log.error "Danger: --dir flag cannot be set to a parent directory of the home directory. Exiting."
        exit 1
      fi
      vCLI_OPT_DIR="${val}"
      ;;
    server=*)
      # Always ignore unless this was provided for the launch command.
      # Prefer the user to rely on the saved server type inside their projects
      # dir (aka $vCLI_OPT_DIR).
      if [[ "$vCLI_PARSED_CMD" = "launch" ]]; then
        val="${vCLI_PARSED_OPTIONS[$i]#*=}"
        vCLI_OPT_SERVER="$val"
        was_server_set=true
      fi
      ;;
    tag=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [[ -n "$val" ]]; then
        vCLI_OPT_TAG="$val"
      fi
      ;;
    lib=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [[ -n "$val" ]]; then
        vCLI_OPT_LIB="$val"
        if [[ ! -f "lib/$vCLI_OPT_LIB.sh" ]]; then
          log.error "Unknown lib: $vCLI_OPT_LIB"
          exit 1
        fi
      fi
      ;;
    fn=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [[ -n ${val} ]]; then
        vCLI_OPT_FN="${val}"
      else
        log.error "The --fn flag must be followed by a function name."
        exit 1
      fi
      ;;
    esac
  done
  local projects_server_type_file="${vCLI_OPT_DIR}/${vSTATIC_SERVER_TYPE_FILENAME}"
  if [[ ${was_server_set} = "true" ]]; then
    if [[ -f ${projects_server_type_file} ]]; then
      local projects_server_type="$(cat "${projects_server_type_file}")"
      if [[ -z ${projects_server_type} ]]; then
        log.error "Unexpected error: ${projects_server_type_file} is empty"
        exit 1
      fi
      if [[ -z ${vCLI_OPT_SERVER} ]]; then
        log.error "Unexpected error: --server flag was provided with an empty value."
        exit 1
      fi
      if [[ ${projects_server_type} != "${vCLI_OPT_SERVER}" ]]; then
        log.error "cannot change the server type after the initial launch command is run"
        log.error "found: \`${projects_server_type}\`, you provided: \`${vCLI_OPT_SERVER}\`"
        log.error "only a hard reset (use with caution) can change the server type."
        log.info "\`solos --help\` for more info."
        exit 1
      fi
    else
      log.warn "No server type file found at: ${vCLI_OPT_DIR}/${vSTATIC_SERVER_TYPE_FILENAME}"
    fi
  elif [[ -f ${projects_server_type_file} ]]; then
    vCLI_OPT_SERVER="$(cat "${projects_server_type_file}")"
  fi
}
solos.merge_launch_dirs() {
  # Important: we want to approach the files inside of the launch
  # dir as ephemeral and not worry about overwriting them.
  # This is helpful too in future proofing the script against changes
  # to the project directory location outside of the cli.

  # The server launch dir contains launch files specific to the server type.
  local server_launch_dir="${vCLI_OPT_DIR}/repo/${vSTATIC_REPO_SERVERS_DIR}/${vCLI_OPT_SERVER}/${vSTATIC_LAUNCH_DIRNAME}"

  # The bin launch dir contains launch files that are shared across all server types.
  # Ex: code-workspace files, docker compose.yml file, standard linux startup script, etc.
  local bin_launch_dir="${vCLI_OPT_DIR}/repo/${vSTATIC_BIN_LAUNCH_DIR}"

  # We'll combine the above launch dir files and do some variable
  # injection on them to create the final launch directory.
  local project_launch_dir="${vCLI_OPT_DIR}/${vSTATIC_LAUNCH_DIRNAME}"

  # Prevent an error from resulting in a partially incomplete launch dir
  # by building everything in a tmp dir and then moving it over.
  local tmp_dir="${vCLI_OPT_DIR}/.tmp"
  local tmp_launch_dir="${tmp_dir}/${vSTATIC_LAUNCH_DIRNAME}"
  if [[ -d "$project_launch_dir" ]]; then
    log.warn "rebuilding the launch directory."
  fi
  rm -rf "${tmp_launch_dir}"
  mkdir -p "${tmp_launch_dir}"

  # Clarification: I don't expect the server specific launch files to
  # require variable injection, however variable injection will still work
  # since we call the injection command on the fully built directory
  # which contains both server specific and shared launch files.

  # The only reason why I don't expect the server specific launch files to
  # require variable injection is because they are NOT meant to be aware of
  # variables residing in this script.
  cp -a "${server_launch_dir}/." "${tmp_launch_dir}/"
  log.info "copied: ${server_launch_dir} to ${tmp_launch_dir}"
  cp -a "${bin_launch_dir}/." "${tmp_launch_dir}/"
  log.info "copied: ${bin_launch_dir} to ${tmp_launch_dir}"
  if ! lib.utils.template_variables "${tmp_launch_dir}" "commit" 2>&1; then
    log.error "something unexpected happened while injecting variables into the launch directory."
    exit 1
  fi
  log.info "injected variables into the tmp launch directory."
  rm -rf "${project_launch_dir}"
  log.info "deleted: ${project_launch_dir}"
  mv "${tmp_launch_dir}" "${project_launch_dir}"
  log.info "successfully rebuilt ${project_launch_dir}"
}
solos.import_project_repo() {
  # Rather than download portions of the repo we need, we prefer
  # to rely on a full clone in each project directory.

  # Note: maybe in the future, if we want to prevent re-runs of the
  # launch command from busting our version of the repo in our project
  # we can automate forking the repo on the initial clone so that pulls
  # won't cause any issues. But for now, the forking needs to occur
  # manually by the user in their project.
  local clone_target_dir="${vCLI_OPT_DIR}/repo"
  local repo_server_dir="${clone_target_dir}/${vSTATIC_REPO_SERVERS_DIR}/${vCLI_OPT_SERVER}"
  if [[ -d ${clone_target_dir} ]]; then
    log.warn "the SolOS repo was already cloned to ${clone_target_dir}."
    log.info "pulling latest changes on checked out branch."
    git -C "${clone_target_dir}" pull >/dev/null
    log.info "pulled latest changes."
  else
    git clone ${vSTATIC_REPO_URL} "${clone_target_dir}" >/dev/null
    log.info "cloned the SolOS repo to ${clone_target_dir}."
  fi
  if [[ ! -d ${repo_server_dir} ]]; then
    log.error "The server ${vCLI_OPT_SERVER} does not exist in the SolOS repo. Exiting."
    exit 1
  fi
  find "${clone_target_dir}" -type f -name "*.sh" -exec chmod +x {} \;
  log.info "set permissions for all shell scripts in: ${clone_target_dir}"
}
solos.create_ssh_files() {
  local self_publickey_path="$(lib.ssh.path_pubkey.self)"
  local self_privkey_path="$(lib.ssh.path_privkey.self)"
  local self_authorized_keys_path="$(lib.ssh.path_authorized_keys.self)"
  local self_config_path="$(lib.ssh.path_config.self)"
  local self_ssh_dir_path="$(lib.ssh.path.self)"

  # This is the dir we'll use to store all the keyfiles required
  # by our local, docker dev container, and remote server.
  # Important: if a dev manually deletes this dir before re-running a launch,
  # infra will get recreated and the keys will get regenerated.
  if [[ ! -d ${self_ssh_dir_path} ]]; then
    mkdir -p "${self_ssh_dir_path}"
    log.info "created: ${self_ssh_dir_path}"
    ssh-keygen -t rsa -q -f "${self_privkey_path}" -N ""
    log.info "created private key: ${self_privkey_path}, public key: ${self_publickey_path}"
    cat "${self_publickey_path}" >"${self_authorized_keys_path}"
    log.info "created ${self_authorized_keys_path}"
  fi
  chmod 644 "${self_authorized_keys_path}"
  log.info "updated permissions: chmod 644 - ${self_authorized_keys_path}"
  chmod 644 "${self_publickey_path}"
  log.info "updated permissions: chmod 644 - ${self_publickey_path}"
  chmod 644 "${self_config_path}"
  log.info "updated permissions: chmod 644 - ${self_config_path}"
  chmod 600 "${self_privkey_path}"
  log.info "updated permissions: chmod 600 - ${self_privkey_path}"
}
solos.require_completed_launch_status() {
  if [[ -z "$(lib.status.get "$vSTATUS_LAUNCH_SUCCEEDED")" ]]; then
    log.error "Launch status is still incomplete. Run (or fix whatever issues occured and re-run) the launch command."
    log.info "\`solos --help\` for more info."
    exit 1
  fi

  # Feel free to add more paranoid checks here. The status above should cover us, but
  # it does rely on some trust that either the user didn't delete the status file or
  # that the launch script didn't leave out anything critical in a future change.
  if ! lib.ssh.command.remote '[ -d '"${vSTATIC_SERVER_CONFIG_ROOT}"' ]'; then
    log.error "Unexpected error: ${vSTATIC_SERVER_CONFIG_ROOT} not found on the remote."
    exit 1
  fi
}

solos.trap() {
  tput cnorm
  local code=$?

  # The cache only exists for the duration of a given run.
  lib.cache.clear
  if [[ $code -eq 1 ]]; then
    exit 1
  fi
  exit $code
}

# This is where we set up the error trapping logic.
# When I first created this all it did was log global variables.
if ! declare -f solos.trap >/dev/null; then
  log.error "solos.trap is not a defined function. Exiting."
  exit 1
fi
trap "solos.trap" EXIT

cli.parse.requirements
cli.parse.cmd "$@"
cli.parse.validate_opts
solos.apply_parsed_cli_args

# Before doing ANYTHING, check that our command actually exists.
# This is the earliest we can call this because we need the
# parsed arguments.
if ! command -v "cmd.$vCLI_PARSED_CMD" &>/dev/null; then
  log.error "cmd.$vCLI_PARSED_CMD is not defined. Exiting."
  exit 1
fi

# Note: if cmd = test, run without the do_task wrapper
if [[ "$vCLI_PARSED_CMD" = "test" ]]; then
  vMETA_USE_FOREGROUND_LOGS=true
  "cmd.$vCLI_PARSED_CMD"
else
  lib.utils.do_task "Running ${vCLI_PARSED_CMD}" "cmd.$vCLI_PARSED_CMD"
fi
