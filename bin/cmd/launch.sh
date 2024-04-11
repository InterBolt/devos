#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

cmd.launch() {
  cmd.checkout

  if [ "$vCLI_OPT_HARD_RESET" == true ]; then
    #
    # Will throw on a dir path that is either non-existent OR
    # doesn't contain any file/files specific to a solos project.
    #
    lib.validate.throw_on_nonsolos
    lib.utils.warn_with_delay "DANGER: about to \`rm -rf ${vCLI_OPT_DIR}\`"
    rm -rf "$vCLI_OPT_DIR"
    log.warn "wiped and created empty dir: $vCLI_OPT_DIR"
  fi
  #
  # Will only throw on a dir path that already exists AND
  # doesn't have a solos project-specific file. Doesn't care about non-existent dirs
  # since those will just result in new solos projects.
  #
  lib.validate.throw_on_nonsolos_dir
  if [ ! -d "${vCLI_OPT_DIR}" ]; then
    mkdir -p "${vCLI_OPT_DIR}"
    log.info "created new SolOS project at: ${vCLI_OPT_DIR}"
    vENV_SOLOS_ID="$(lib.utils.generate_secret)"
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
  last_successful_run="$(lib.status.get "$vSTATUS_LAUNCH_SUCCEEDED")"
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
  lib.validate.validate_project_repo "$vCLI_OPT_DIR/repo"
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
  vENV_SEED_SECRET="$(lib.cache.overwrite_on_empty "vENV_SEED_SECRET" "$(lib.utils.generate_secret)")"
  log.debug "set \$vENV_SEED_SECRET= $vENV_SEED_SECRET"
  # ------------------------------------------------------------------------------------------------------------
  vENV_GITHUB_USERNAME="$(lib.cache.overwrite_on_empty "vENV_GITHUB_USERNAME" "$(git config -l | grep user.name | cut -d = -f 2)")"
  log.debug "set \$vENV_GITHUB_USERNAME= $vENV_GITHUB_USERNAME"
  # ------------------------------------------------------------------------------------------------------------
  vENV_GITHUB_EMAIL="$(lib.cache.overwrite_on_empty "vENV_GITHUB_EMAIL" "$(git config -l | grep user.email | cut -d = -f 2)")"
  log.debug "set \$vENV_GITHUB_EMAIL= $vENV_GITHUB_EMAIL"
  # ------------------------------------------------------------------------------------------------------------
  vENV_GITHUB_TOKEN="$(lib.cache.prompt "vENV_GITHUB_TOKEN")"
  log.debug "set \$vENV_GITHUB_TOKEN= $vENV_GITHUB_TOKEN"
  # ------------------------------------------------------------------------------------------------------------
  vENV_OPENAI_API_KEY="$(lib.cache.prompt "vENV_OPENAI_API_KEY")"
  log.debug "set \$vENV_OPENAI_API_KEY= $vENV_OPENAI_API_KEY"
  # ------------------------------------------------------------------------------------------------------------
  vENV_PROVIDER_API_KEY="$(lib.cache.prompt "vENV_PROVIDER_API_KEY")"
  log.debug "set \$vENV_PROVIDER_API_KEY= $vENV_PROVIDER_API_KEY"
  # ------------------------------------------------------------------------------------------------------------
  vENV_PROVIDER_NAME="$(lib.cache.prompt "vENV_PROVIDER_NAME")"
  log.debug "set \$vENV_PROVIDER_NAME= $vENV_PROVIDER_NAME"
  # ------------------------------------------------------------------------------------------------------------
  vENV_PROVIDER_API_ENDPOINT="$(lib.cache.prompt "vENV_PROVIDER_API_ENDPOINT")"
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
  lib.vultr.s3.provision
  log.success "vultr object storage is ready"
  #
  # prev_id is NOT the same as ip_to_deprovision.
  # when prev_id is set and is associated with a matching
  # ssh key, we "promote" it to vENV_IP and skip
  # much (or all) of the vultr provisioning process.
  #
  local most_recent_ip="$(lib.cache.get "most_recent_ip")"
  local ip_to_deprovision="$(lib.cache.get "ip_to_deprovision")"
  if [ -n "${most_recent_ip}" ]; then
    log.info "the ip \`$most_recent_ip\` from a previous run was found."
    log.info "if ssh keyfiles are the same, we will skip provisioning."
  fi
  lib.vultr.compute.provision "$most_recent_ip"
  vENV_IP="${vPREV_RETURN[0]}"
  log.success "vultr compute is ready"
  #
  # I'm treating the lib.vultr. functions as a black box and then doing
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
    lib.cache.set "ip_to_deprovision" "$most_recent_ip"
    lib.cache.set "most_recent_ip" "$vENV_IP"
  fi
  #
  # Generates the .env/.env.sh files by mapping all
  # global variables starting with vENV_* to both files.
  #
  lib.env.generate_files
  #
  # Builds the ssh config file for the remote server and
  # local docker dev container.
  # Important: the ssh config file is the source of truth for
  # our remote ip.
  #
  lib.ssh.build.config_file "$ip"
  log.info "created: $(lib.ssh.path_config.self)."
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
  lib.ssh.rsync_up.remote "$linux_sh_project_file" "/root/"
  lib.ssh.command.remote "chmod +x /root/${vSTATIC_LINUX_SH_FILENAME}"
  log.info "uploaded and set permissions for remote bootstrap script."
  #
  # Create the folder where we'll store out caprover
  # deployment tar files.
  #
  lib.ssh.command.remote "mkdir -p /root/deployments"
  log.info "created remote deployment dir: /root/deployments"
  #
  # Before bootstrapping can occur, make sure we upload the .solos config folder
  # from our local machine to the remote machine.
  # Important: we don't need to do this with the docker container because we mount it
  #
  if lib.ssh.command.remote '[ -d '"${vSTATIC_SERVER_CONFIG_ROOT}"' ]'; then
    log.warn "remote already has the global solos config folder. skipping."
    log.info "see \`solos --help\` for how to re-sync your local or docker dev config folder to the remote."
  else
    lib.ssh.command.remote "mkdir -p ${vSTATIC_SERVER_CONFIG_ROOT}"
    log.info "created empty remote .solos config folder."
    lib.ssh.rsync_up.remote "${vSTATIC_MY_CONFIG_ROOT}/" "${vSTATIC_SERVER_CONFIG_ROOT}/"
    log.info "uploaded local .solos config folder to remote."
  fi
  #
  #
  # The linux.sh file will run the env specific launch scripts.
  # Important: these env specific scripts should be idempotent and performant.
  #
  lib.ssh.command.remote "/root/${vSTATIC_LINUX_SH_FILENAME} remote ${vCLI_OPT_SERVER}"
  #
  # We might want this status in the future
  #
  lib.status.set "${vSTATUS_BOOTSTRAPPED_REMOTE}" "$(lib.utils.date)"
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
  bootstrapped_manually_at="$(lib.status.get "${vSTATUS_BOOTSTRAPPED_MANUALLY}")"
  if [ -n "${bootstrapped_manually_at}" ]; then
    log.warn "skipping manual bootstrap step - completed at ${bootstrapped_manually_at}"
  else
    lib.ssh.rsync_down.remote "${vSTATIC_SERVER_ROOT}/${vSTATIC_MANUAL_FILENAME}" "${vCLI_OPT_DIR}/"
    log.debug "downloaded manual file to: ${vCLI_OPT_DIR}"
    log.info "review the manual instructions before continuing"
    lib.utils.echo_line
    echo ""
    cat "${vCLI_OPT_DIR}/${vSTATIC_MANUAL_FILENAME}"
    echo ""
    lib.utils.echo_line
    echo -n "Hit enter (0/2) to continue."
    read -r
    echo -n "Hit enter (1/2) to continue."
    read -r
    lib.status.set "${vSTATUS_BOOTSTRAPPED_MANUALLY}" "$(lib.utils.date)"
    log.info "completed manual bootstrap step. see \`solos --help\` for how to re-display manual instructions."
  fi
  #
  # The logic here is simpler because the bootstrap script for the docker container
  # will never deal with things like databases or service orchestration.
  #
  lib.ssh.command.docker "${vSTATIC_DOCKER_MOUNTED_LAUNCH_DIR}/${vSTATIC_LINUX_SH_FILENAME} docker ${vCLI_OPT_SERVER}"
  lib.status.set "${vSTATUS_BOOTSTRAPPED_DOCKER}" "$(lib.utils.date)"
  log.info "bootstrapped the local docker container."
  #
  # This is redundant, but it's a good safety check because
  # if something bad happened and the old ip is the same as the current
  # we'll end up destroying the current instance. Yikes.
  #
  local ip_to_deprovision="$(lib.cache.get "ip_to_deprovision")"
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
    lib.utils.warn_with_delay "DANGER: destroying instance: ${ip_to_deprovision}"
    lib.vultr.compute.get_instance_id_from_ip "${ip_to_deprovision}"
    local instance_id_to_deprovision="${vPREV_RETURN[0]}"
    if [ "${instance_id_to_deprovision}" == "null" ]; then
      log.error "Unexpected error: couldn't find instance for ip: \`${ip_to_deprovision}\`. Nothing to deprovision."
      exit 1
    fi
    lib.vultr.compute.destroy_instance "${instance_id_to_deprovision}"
    log.info "destroyed the previous instance with ip: ${ip_to_deprovision}"
    lib.cache.del "ip_to_deprovision"
    log.debug "deleted the ip_to_deprovision cache entry."
  fi
  lib.status.set "${vSTATUS_LAUNCH_SUCCEEDED}" "$(lib.utils.date)"
  log.success "launch completed successfully."
}
