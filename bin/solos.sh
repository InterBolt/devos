#!/usr/bin/env bash
# Note on the shellcheck disabling here: unused variables are allowed
# because shellcheck can't tell that we're actually using them in other
# scripts sourced within this one.
# shellcheck disable=SC2034

# Fail if we try to set a restricted variable without a default value.
# This would indicate a logic error.
vRESTRICTED_NOOP=false
vRESTRICTED_DEVELOPER=false
for _all_args in "$@"; do
  if [[ $_all_args = "--restricted-"* ]]; then
    _flag_name="${_all_args#--restricted-}"
    _var_name="vRESTRICTED_$(echo "${_flag_name}" | tr '[:lower:]' '[:upper:]')"
    eval "${!_var_name}=true"
    set -- "${@/"--restricted-${_flag_name}"*/}"
  fi
done
if [[ ${vRESTRICTED_DEVELOPER} = true ]]; then
  echo "Running in dev mode"
fi

# We might need more here later, but for now the main thing
# is resetting the cursor via tput.
trap "tput cnorm" EXIT

if ! cd "$(dirname "${BASH_SOURCE[0]}")"; then
  echo "Unexpected error: could not cd into 'dirname \"\${BASH_SOURCE[0]}\"'" >&2
  exit 1
fi

# Will include dotfiles in globbing.
shopt -s dotglob

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

# Make sure the basic directories we need exist.
mkdir -p "${vSTATIC_SOLOS_ROOT}"
mkdir -p "${vSTATIC_SOLOS_PROJECTS_ROOT}"
mkdir -p "${vSTATIC_LOGS_DIR}"
if [[ ! -f "${vSTATIC_LOG_FILEPATH}" ]]; then
  touch "${vSTATIC_LOG_FILEPATH}"
fi

# Miscellanous values that are used throughout the script.
# calling them "meta" because they are mostly inferred, or
# derived from undocumented flags.
vSOLOS_USE_FOREGROUND_LOGS=false
for entry_arg in "$@"; do
  if [[ $entry_arg = "--foreground" ]]; then
    set -- "${@/--foreground/}"
    vSOLOS_USE_FOREGROUND_LOGS=true
  fi
done
vSOLOS_STARTED_AT="${SECONDS}"
vSOLOS_LOG_LINE_COUNT="$(wc -l <"${vSTATIC_LOG_FILEPATH}" | xargs)"
vSOLOS_BIN_DIR="$(pwd)"
vSOLOS_BIN_FILEPATH="$vSOLOS_BIN_DIR/$0"
vSOLOS_DEBUG_LEVEL=${DEBUG_LEVEL:-0}

# Slots to store returns/responses. Bash don't allow rich return
# types, so we do this hacky shit instead.
vPREV_CURL_RESPONSE=""
vPREV_CURL_ERR_STATUS_CODE=""
vPREV_CURL_ERR_MESSAGE=""
vPREV_RETURN=()

# Statuses to track launch progress.
vSTATUS_BOOTSTRAPPED_MANUALLY="completed-manual"
vSTATUS_BOOTSTRAPPED_REMOTE="completed-remote"
vSTATUS_LAUNCH_SUCCEEDED="completed-launch"
vSTATUS_BOOTSTRAPPED_DOCKER="completed-docker"

# The vCLI_* values get set within the cli.parse.* functions.
vCLI_USAGE_ALLOWS_CMDS=()
vCLI_USAGE_ALLOWS_OPTIONS=()
vCLI_PARSED_CMD=""
vCLI_PARSED_OPTIONS=()

# These are not 1-1 mappings to option flags. But they ARE
# derived from the option flags.
vOPT_LIB=""
vOPT_FN=""
vOPT_PROJECT_DIR=""
vOPT_PROJECT_REL_DIR=""
vOPT_PROJECT_ID=""
vOPT_IS_NEW_PROJECT=false

# Anything the user might supply either via a prompt or env
# variable should go here.
vSUPPLIED_OPENAI_API_KEY=""
vSUPPLIED_PROVIDER_API_KEY=""
vSUPPLIED_PROVIDER_NAME="vultr"
vSUPPLIED_PROVIDER_API_ENDPOINT="https://api.lib.vultr.com/v2"
vSUPPLIED_GITHUB_TOKEN=""
vSUPPLIED_ROOT_DOMAIN=""
vSUPPLIED_S3_HOST=""
vSUPPLIED_S3_OBJECT_STORE=""
vSUPPLIED_S3_ACCESS_KEY=""
vSUPPLIED_S3_SECRET=""
vSUPPLIED_GITHUB_USERNAME=""
vSUPPLIED_GITHUB_EMAIL=""
vSUPPLIED_SEED_SECRET=""

# I'm not sure what "category" this is, but maybe anything we
# "infer" from our environment?
vDETECTED_REMOTE_IP=""

if [[ ${vRESTRICTED_DEVELOPER} = true ]]; then
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
  local project_server_file=""
  local project_id_file=""
  local was_project_set=false
  if [[ -z ${vCLI_PARSED_CMD} ]]; then
    log.error "No command supplied. Please supply a command."
    exit 1
  fi

  # now handle the rest of the options.
  for i in "${!vCLI_PARSED_OPTIONS[@]}"; do
    case "${vCLI_PARSED_OPTIONS[$i]}" in
    project=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [[ ! "${val}" =~ ^[a-zA-Z][a-zA-Z0-9]*$ ]]; then
        log.error 'Invalid project name: '"${val}"'. Expects: ^[a-zA-Z][a-zA-Z0-9]*$'
        exit 1
      fi
      vOPT_PROJECT_DIR="${vSTATIC_SOLOS_PROJECTS_ROOT}/${val}"
      vOPT_PROJECT_REL_DIR=".solos/projects/${val}"
      project_id_file="${vOPT_PROJECT_DIR}/${vSTATIC_SOLOS_ID_FILENAME}"
      if [[ ! -d "${vOPT_PROJECT_DIR}" ]]; then
        mkdir -p "${vOPT_PROJECT_DIR}"
        vOPT_PROJECT_ID="$(lib.utils.generate_secret)"
        echo "${vOPT_PROJECT_ID}" >"${project_id_file}"
        vOPT_IS_NEW_PROJECT=true
      elif [[ -f "${vOPT_PROJECT_DIR}" ]]; then
        log.error "${vOPT_PROJECT_DIR} is a file. Did you pass in the wrong project name?"
        exit 1
      elif [[ ! -d "${vOPT_PROJECT_DIR}" ]] && [[ ! -f "${project_id_file}" ]]; then
        log.error "${project_id_file} was not found, which means ${vOPT_PROJECT_DIR} isn't a SolOS project."
        exit 1
      fi
      was_project_set=true
      ;;
    lib=*)
      val="${vCLI_PARSED_OPTIONS[$i]#*=}"
      if [[ -n "$val" ]]; then
        vOPT_LIB="$val"
        if [[ ! -f "lib/$vOPT_LIB.sh" ]]; then
          log.error "Unknown lib: $vOPT_LIB"
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
solos.checkout_project_dir() {
  if [[ ${vOPT_CHECKED_OUT} = true ]]; then
    return 0
  fi
  local project_id_file="${vOPT_PROJECT_DIR}/${vSTATIC_SOLOS_ID_FILENAME}"
  if [[ -z ${vOPT_PROJECT_DIR} ]]; then
    vOPT_PROJECT_DIR="$(lib.store.global.get "checked_out")"
    vOPT_PROJECT_REL_DIR=".solos/projects/$(basename "${vOPT_PROJECT_DIR}")"
  fi
  if [[ -z ${vOPT_PROJECT_DIR} ]]; then
    log.error "Please supply a --project flag."
    exit 1
  fi
  if [[ ! -d ${vOPT_PROJECT_DIR} ]]; then
    log.error "The checked out directory ${vOPT_PROJECT_DIR} no longer exists. Removing from the cache."
    lib.store.global.del "checked_out"
    exit 1
  fi
  if [[ ! -f ${project_id_file} ]]; then
    log.error "Failed to find a project id at: ${project_id_file}"
    exit 1
  fi
  vOPT_PROJECT_ID="$(cat "${project_id_file}")"
  if [[ -z ${vOPT_PROJECT_ID} ]]; then
    log.error "Unexpected error: ${project_id_file} is empty."
    exit 1
  fi
  lib.store.global.set "checked_out" "${vOPT_PROJECT_DIR}"

  # Ensures no-op on next function call for idempotency.
  vOPT_CHECKED_OUT=true
}
solos.detect_remote_ip() {
  local ssh_path_config="${vOPT_PROJECT_DIR}/.ssh/ssh_config"
  if [[ -f "${ssh_path_config}" ]]; then
    # Note: For the most part we can just assume the ip we extract here
    # is the correct one. The time where it isn't true is if we wipe our project's .ssh
    # dir and re-run the launch command. But since the store files are in the global config
    # dir, we can always find it despite a wiped project dir.
    local most_recent_ip="$(lib.ssh.extract_ip)"
    lib.store.project.set "most_recent_ip" "${most_recent_ip}"
    log.info "Found a remote ip in the ssh config file."
  elif [[ ${vOPT_IS_NEW_PROJECT} = false ]]; then
    # Note: Solos doesn't allow changing the .ssh dir files via any of its commands.
    # So if the ssh config file is missing, I'd rather error and exit than try to account for it.
    # If there are legitimate reasons for changing the ssh dirs than we can add a command
    # to deal with any hairyness separately and at a future date.
    log.error "${ssh_path_config} was not found."
    exit 1
  fi
}
solos.generate_launch_build() {
  local bin_launch_dir="${vOPT_PROJECT_DIR}/src/bin/launch"
  local project_launch_build_dir="${vOPT_PROJECT_DIR}/launch_build"
  if [[ -d "$project_launch_dir" ]]; then
    log.warn "Rebuilding the project's \`launch_build\` directory."
  fi

  # Create the tmp dir where we'll do our template variable injection.
  # This way if it fails, we don't need to worry about how to mend our
  # files back to their original state.
  local tmp_dir="$(mktmp -d)"
  local tmp_launch_dir="${tmp_dir}/$(basename "${project_launch_build_dir}")"
  mkdir -p "${tmp_launch_dir}"

  # Clarification: I don't expect the server specific launch files to
  # require variable injection, however variable injection will still work
  # since we call the injection command on the fully built directory
  # which contains both server specific and shared launch files.

  # Move the template files into the tmp dir and then do variable injection
  # on them.
  cp -a "${bin_launch_dir}/." "${tmp_launch_dir}/"
  if ! lib.utils.template_variables "${tmp_launch_dir}" "commit" 2>&1; then
    log.error "Unexpected error: failed to inject solos variables into the launch_build files."
    exit 1
  fi
  rm -rf "${project_launch_dir}"
  log.info "deleted: ${project_launch_dir}"
  mv "${tmp_launch_dir}" "${project_launch_dir}"
  log.info "Built the project's launch_build directory."
}
solos.require_completed_launch_status() {
  if [[ -z "$(lib.status.get "$vSTATUS_LAUNCH_SUCCEEDED")" ]]; then
    log.error "Launch status is still incomplete."
    log.info "\`solos --help\` for more info."
    exit 1
  fi

  # Feel free to add more paranoid checks here. The status above should cover us, but
  # it does rely on some trust that either the user didn't delete the status file or
  # that the launch script didn't leave out anything critical in a future change.
  if ! lib.ssh.command.remote '[ -d '"${vSTATIC_SOLOS_ROOT}"' ]'; then
    log.error "Unexpected error: ${vSTATIC_SOLOS_ROOT} not found on the remote."
    exit 1
  fi
}

cli.parse.requirements
cli.parse.cmd "$@"
cli.parse.validate_opts
solos.apply_parsed_cli_args

# Before doing ANYTHING, check that our command actually exists.
# This is the earliest we can call this because we need the
# parsed arguments.
if ! command -v "cmd.$vCLI_PARSED_CMD" &>/dev/null; then
  log.error "No implementation for $vCLI_PARSED_CMD exists."
  exit 1
fi

# Note: if cmd = test, run without the do_task wrapper
if [[ "$vCLI_PARSED_CMD" = "test" ]]; then
  vSOLOS_USE_FOREGROUND_LOGS=true
  "cmd.$vCLI_PARSED_CMD"
else
  lib.utils.do_task "Running ${vCLI_PARSED_CMD}" "cmd.$vCLI_PARSED_CMD"
fi
