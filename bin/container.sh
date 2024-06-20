#!/usr/bin/env bash

# Any variables that might get used in template replacements should be defined here.
container__project=""
container__code_workspace_file=""
container__solos_dir="/root/.solos"
container__store_dir="${container__solos_dir}/data/store"
container__checked_out_project_store_file="${container__store_dir}/checked_out_project"
container__users_home_dir_store_file="${container__store_dir}/users_home_dir"
# We can't actually do anything if we don't know the user's home directory.
# This is because we need absolute paths to workspace folders for the code-workspace file.
if [[ ! -f ${container__users_home_dir_store_file} ]]; then
  echo "Unexpected error: the user's home directory was not saved to ${container__users_home_dir_store_file}." >&2
  exit 1
fi
# Used in the code-workspace template. Not used in the script itself.
container__users_home_dir=$(cat "${container__users_home_dir_store_file}" || echo "")

# For simplicity, let's ensure we're in the base directory of our SolOS installation.
# It's possible that this won't/doesn't matter, but it's a nice assurance to have as changes are made.
cd "${container__solos_dir}"

# Make sure we can access the logger functions.
. "${container__solos_dir}/src/shared/log.sh" || exit 1

# Help/usage stuff.
container.help() {
  cat <<EOF
USAGE: solos <project>

DESCRIPTION:

Launch a SolOS project, either by creating a new one or switching to an existing one.

Source: https://github.com/InterBolt/solos
EOF
}
if [[ $# -eq 0 ]]; then
  container.help
  exit 1
fi
if [[ ${1} = "--help" ]] || [[ ${1} = "-h" ]]; then
  container.help
  exit 0
fi

# Support a flag to exit early. Useful for confirming that our dockerized CLI is
# working as expected post-installation.
for arg in "$@"; do
  if [[ ${arg} = "--noop" ]]; then
    exit 0
  fi
done

# Grab the project name from either the first argument, or the checked out project store file.
# This allows users to simply type: "solos" without having to remember the project name.
if [[ -n ${1} ]]; then
  container__project="${1}"
  shift
elif [[ -f ${container__checked_out_project_store_file} ]]; then
  container__project=$(cat "${container__checked_out_project_store_file}" || echo "")
  if [[ -z ${container__project} ]]; then
    log.error "No project checked out. Please specify a project name as the first argument to \`solos\`"
    exit 1
  fi
fi

# Allows us to replace template string variables in files where the
# template string is in the format ___container__variable_name___ and container__variable_name
# is a variable defined here in this script.
container.do_template_variable_replacements() {
  local dir_or_file="$1"
  local eligible_files=()
  if [[ -d ${dir_or_file} ]]; then
    for file in "${dir_or_file}"/*; do
      if [[ -d ${file} ]]; then
        container.do_template_variable_replacements "${file}"
      fi
      if [[ -f ${file} ]]; then
        eligible_files+=("${file}")
      fi
    done
  elif [[ -f ${dir_or_file} ]]; then
    eligible_files+=("${dir_or_file}")
  fi
  if [[ ${#eligible_files[@]} -eq 0 ]]; then
    return
  fi
  local errored=false
  for file in "${eligible_files[@]}"; do
    bin_vars=$(grep -o "___container__[a-z0-9_]*___" "${file}" | sed 's/___//g')
    for bin_var in ${bin_vars}; do
      if [[ -z ${!bin_var+x} ]]; then
        log.error "Template variables error: ${file} is using an unset variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ -z ${!bin_var} ]]; then
        log.error "Template variables error: ${file} is using an empty variable: ${bin_var}"
        errored=true
        continue
      fi
      if [[ ${errored} = "false" ]]; then
        sed -i "s,___${bin_var}___,${!bin_var},g" "${file}"
      fi
    done
  done
  if [[ ${errored} = "true" ]]; then
    exit 1
  fi
}
container.main() {
  if [[ -z ${container__project} ]]; then
    log.error "No project name was supplied."
    exit 1
  fi

  # Create the projects directory if it doesn't exist.
  if [[ ! -d ${container__solos_dir}/projects ]]; then
    mkdir -p "${container__solos_dir}/projects"
    log.info "No projects found. Creating ~/.solos/projects directory."
  fi

  # Create the project directory if it doesn't exist.
  local project_dir="${container__solos_dir}/projects/${container__project}"
  if [[ ! -d ${project_dir} ]]; then
    mkdir -p "${project_dir}"
    log.info "${container__project} - Created ${project_dir}"
  fi

  # Initialize the ignore file for plugins if it doesn't exist.
  local ignore_file="${project_dir}/.solosignore.plugins"
  if [[ ! -f ${ignore_file} ]]; then
    echo "# Any plugin names listed below this line will be turned off when working in this project." \
      >"${ignore_file}"
    log.info "${container__project} - Created ${ignore_file}."
  fi

  # Create the vscode directory if it doesn't exist.
  local vscode_dir="${project_dir}/.vscode"
  if [[ ! -d ${vscode_dir} ]]; then
    mkdir -p "${vscode_dir}"
    log.info "${container__project} - Created ${vscode_dir}"
  fi

  # Create the code-workspace file if it doesn't exist.
  container__code_workspace_file="${vscode_dir}/${container__project}.code-workspace"
  if [[ ! -f ${container__code_workspace_file} ]]; then
    local template_code_workspace_file="${container__solos_dir}/src/cli/project.code-workspace"
    local tmp_dir="$(mktemp -d -q)"
    cp "${template_code_workspace_file}" "${tmp_dir}/${container__project}.code-workspace"
    if container.do_template_variable_replacements "${tmp_dir}/${container__project}.code-workspace"; then
      cp -f "${tmp_dir}/${container__project}.code-workspace" "${container__code_workspace_file}"
      log.info "${container__project} - Created ${container__code_workspace_file} based on template at ${template_code_workspace_file}."
    else
      log.error "${container__project} - Failed to build the code workspace file."
      exit 1
    fi
  fi

  # Create an empty checkout script if one doesn't exist.
  local checkout_script="${project_dir}/solos.checkout.sh"
  if [[ -f ${checkout_script} ]]; then
    chmod +x "${checkout_script}"
    if ! "${checkout_script}"; then
      log.warn "${container__project} - Failed to run the checkout script."
    else
      log.info "${container__project} - Checkout out."
    fi
  else
    cat <<EOF >"${checkout_script}"
#!/usr/bin/env bash

######################################################################################################################
##
## Checkout script docs at: https://[TODO]
##
######################################################################################################################

# Write your code below:
echo "Hello from the checkout script for project: ${container__project}"

EOF
    chmod +x "${checkout_script}"
    log.info "${container__project} - initialized the checkout script."
  fi
  if [[ ! -d ${container__store_dir} ]]; then
    mkdir -p "${container__store_dir}"
    log.info "${container__project} - created ${container__store_dir}"
  fi
  if [[ ! -f ${container__checked_out_project_store_file} ]]; then
    touch "${container__checked_out_project_store_file}"
    log.info "${container__project} - touched ${container__checked_out_project_store_file}"
  fi
  echo "${container__project}" >"${container__checked_out_project_store_file}"
  log.info "${container__project} - ready."
}

# Run the script, but error if any arguments are supplied that shouldn't be there.
if [[ $# -ne 0 ]]; then
  log.error "Unexpected error: arguments not supported: [${*}]"
  exit 1
fi

# The last line of the stdout must be the code-workspace file so that the user's host can open it.
if container.main; then
  # remove the "/root/" prefix from the code workspace file path.
  echo "${container__code_workspace_file/#\/root\//}"
else
  echo ""
fi
