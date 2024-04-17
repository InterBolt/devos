#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

cmd.create() {
  solos.checkout_project_dir
  solos.detect_remote_ip
  exit 0

  # This script is idempotent. But a warning doesn't hurt.
  last_successful_run="$(lib.status.get "$vSTATUS_LAUNCH_SUCCEEDED")"
  if [[ -n "$last_successful_run" ]]; then
    log.warn "the last successful run was at: $last_successful_run"
  fi

  # Generate and collect things like the caprover password, postgres passwords.
  # api keys, etc.
  local expects_these_things=(
    "vSUPPLIED_SEED_SECRET"
    "vSUPPLIED_GITHUB_USERNAME"
    "vSUPPLIED_GITHUB_EMAIL"
    "vSUPPLIED_GITHUB_TOKEN"
    "vSUPPLIED_OPENAI_API_KEY"
    "vSUPPLIED_PROVIDER_API_KEY"
    "vSUPPLIED_PROVIDER_NAME"
    "vSUPPLIED_PROVIDER_API_ENDPOINT"
  )
  local some_vars_not_set=false
  for expected_var in "${expects_these_things[@]}"; do
    if [[ -z ${!expected_var+x} ]]; then
      log.error "var: ${expected_var} is not defined"
      some_vars_not_set=true
    fi
  done
  if [[ ${some_vars_not_set} = "true" ]]; then
    exit 1
  fi
  vSUPPLIED_SEED_SECRET="$(lib.store.project.set_on_empty "vSUPPLIED_SEED_SECRET" "$(lib.utils.generate_secret)")"
  vSUPPLIED_GITHUB_USERNAME="$(lib.store.project.set_on_empty "vSUPPLIED_GITHUB_USERNAME" "$(git config -l | grep user.name | cut -d = -f 2)")"
  vSUPPLIED_GITHUB_EMAIL="$(lib.store.project.set_on_empty "vSUPPLIED_GITHUB_EMAIL" "$(git config -l | grep user.email | cut -d = -f 2)")"
  vSUPPLIED_GITHUB_TOKEN="$(lib.store.project.prompt "vSUPPLIED_GITHUB_TOKEN")"
  vSUPPLIED_OPENAI_API_KEY="$(lib.store.project.prompt "vSUPPLIED_OPENAI_API_KEY")"
  vSUPPLIED_PROVIDER_API_KEY="$(lib.store.project.prompt "vSUPPLIED_PROVIDER_API_KEY")"
  vSUPPLIED_PROVIDER_NAME="$(lib.store.project.prompt "vSUPPLIED_PROVIDER_NAME")"
  vSUPPLIED_PROVIDER_API_ENDPOINT="$(lib.store.project.prompt "vSUPPLIED_PROVIDER_API_ENDPOINT")"
  for i in "${!expects_these_things[@]}"; do
    if [[ -z ${!expects_these_things[$i]} ]]; then
      log.error "${expects_these_things[$i]} is empty. Exiting."
      exit 1
    fi
  done
  lib.ssh.build_keypairs

  # On re-runs, the vultr provisioning functions will check for the existence
  # of the old ip and if it's the same as the current ip, it will skip the
  # provisioning process.
  lib.vultr.s3.provision
  log.success "vultr object storage is ready"

  # prev_id is NOT the same as ip_to_deprovision.
  # when prev_id is set and is associated with a matching
  # ssh key, we "promote" it to vDETECTED_REMOTE_IP and skip
  # much (or all) of the vultr provisioning process.
  local most_recent_ip="$(lib.store.project.get "most_recent_ip")"
  local ip_to_deprovision="$(lib.store.project.get "ip_to_deprovision")"
  if [[ -n ${most_recent_ip} ]]; then
    log.info "the ip \`${most_recent_ip}\` from a previous run was found."
    log.info "if ssh keyfiles are the same, we will skip provisioning."
  fi
  lib.vultr.compute.provision "${most_recent_ip}"
  vDETECTED_REMOTE_IP="${vPREV_RETURN[0]}"
  log.success "vultr compute is ready"

  # I'm treating the lib.vultr. functions as a black box and then doing
  # critical checks on the produced ip. Should throw when:
  # 1) vDETECTED_REMOTE_IP is empty after provisioning
  # 2) the ip to deprovision in our store is the same as vDETECTED_REMOTE_IP
  if [[ -z "$vDETECTED_REMOTE_IP" ]]; then
    log.error "Unexpected error: the current ip is empty. Exiting."
    exit 1
  fi
  if [[ "$ip_to_deprovision" = "$vDETECTED_REMOTE_IP" ]]; then
    log.error "Unexpected error: the ip to deprovision is the same as the current ip. Exiting."
    exit 1
  fi

  # After the sanity checks, if the ip changed, we're safe
  # to update the store slots for the most recent ip and the
  # ip to deprovision.

  # By putting the ip to deprovision in the store, we ensure that
  # a hard reset won't stop our script from deprovisioning the old instance.
  # on future runs.
  if [[ "$vDETECTED_REMOTE_IP" != "$most_recent_ip" ]]; then
    lib.store.project.set "ip_to_deprovision" "$most_recent_ip"
    lib.store.project.set "most_recent_ip" "$vDETECTED_REMOTE_IP"
  fi

  # Builds the ssh config file for the remote server and
  # local docker dev container.
  # Important: the ssh config file is the source of truth for
  # our remote ip.
  lib.ssh.build.config_file "$ip"

  # Next, we want to form the launch directory inside of our project directory
  # using the `.launch` dirs from within the bin and server specific dirs.
  # Note: launch files are used later to bootstrap our environments.
  solos.generate_launch_build
  local project_launch_dir="${vOPT_PROJECT_DIR}/launch"

  # Build and start the local docker container.
  # We set the COMPOSE_PROJECT_NAME environment variable to
  # the unique id of our project so that we can easily detect
  # whether or not a specific project's dev container is running.
  # Note: I'm being lazy and just cd'ing in and out to run the compose
  # command. This keeps the compose.yml config a little simpler.
  local entry_dir="${PWD}"
  cd "${project_launch_dir}"
  COMPOSE_PROJECT_NAME="solos-${vOPT_PROJECT_ID}" docker compose --file compose.yml up --force-recreate --build --remove-orphans --detach
  log.info "docker container is ready"
  cd "$entry_dir"

  # Important: don't upload the env files to the remote at all!
  # Instead, deployment scripts should take responsibility for
  # packaging anything required from those files when uploading
  # to the remote.

  # Note: In a previous implementation I was making the above mistake.
  local linux_sh_project_file="${project_launch_dir}/${vSTATIC_LINUX_SH_FILENAME}"
  if [[ ! -f "$linux_sh_project_file" ]]; then
    log.error "Unexpected error: $linux_sh_project_file not found. Exiting."
    exit 1
  fi
  lib.ssh.rsync_up "$linux_sh_project_file" "/root/"
  lib.ssh.command "chmod +x /root/${vSTATIC_LINUX_SH_FILENAME}"
  log.info "uploaded and set permissions for remote bootstrap script."

  # Create the folder where we'll store out caprover
  # deployment tar files.
  lib.ssh.command "mkdir -p /root/deployments"
  log.info "created remote deployment dir: /root/deployments"

  # Before bootstrapping can occur, make sure we upload the .solos config folder
  # from our local machine to the remote machine.
  # Important: we don't need to do this with the docker container because we mount it
  if lib.ssh.command '[ -d '"${vSTATIC_SOLOS_ROOT}"' ]'; then
    log.warn "remote already has the global solos config folder. skipping."
    log.info "see \`solos --help\` for how to re-sync your local or docker dev config folder to the remote."
  else
    lib.ssh.command "mkdir -p ${vSTATIC_SOLOS_ROOT}"
    log.info "created empty remote .solos config folder."
    lib.ssh.rsync_up "${vSTATIC_SOLOS_ROOT}/" "${vSTATIC_SOLOS_ROOT}/"
    log.info "uploaded local .solos config folder to remote."
  fi

  # # The linux.sh file will run the env specific launch scripts.
  # # Important: these env specific scripts should be idempotent and performant.
  # lib.ssh.command "/root/${vSTATIC_LINUX_SH_FILENAME} remote ${vSUPPLIED_GITHUB_USERNAME} ${vSUPPLIED_GITHUB_EMAIL} ${vSUPPLIED_GITHUB_TOKEN}"

  # We might want this status in the future
  lib.status.set "${vSTATUS_BOOTSTRAPPED_REMOTE}" "$(lib.utils.full_date)"
  log.info "bootstrapped the remote server."

  # Any type of manual action we need can be specified by a server by simply
  # creating a manual.txt file during it's bootstrap process. This script should have
  # zero awareness of the specifics of the manual.txt file.

  # Example: this script used to understand that we needed caprover and postgres
  # but now it doesn't care. Instead, we'll put all the info for how to setup
  # any one-click-apps, databases, extra infra, etc. in the manual.txt file.
  bootstrapped_manually_at="$(lib.status.get "${vSTATUS_BOOTSTRAPPED_MANUALLY}")"
  if [[ -n ${bootstrapped_manually_at} ]]; then
    log.warn "skipping manual bootstrap step - completed at ${bootstrapped_manually_at}"
  else
    lib.ssh.rsync_down "/root/${vSTATIC_MANUAL_FILENAME}" "${vOPT_PROJECT_DIR}/"
    log.info "downloaded manual file to: ${vOPT_PROJECT_DIR}"
    log.info "review the manual instructions before continuing"
    lib.utils.echo_line
    echo ""
    cat "${vOPT_PROJECT_DIR}/${vSTATIC_MANUAL_FILENAME}"
    echo ""
    lib.utils.echo_line
    echo -n "Hit enter (0/2) to continue."
    read -r
    echo -n "Hit enter (1/2) to continue."
    read -r
    lib.status.set "${vSTATUS_BOOTSTRAPPED_MANUALLY}" "$(lib.utils.full_date)"
    log.info "completed manual bootstrap step. see \`solos --help\` for how to re-display manual instructions."
  fi

  # # The logic here is simpler because the bootstrap script for the docker container
  # # will never deal with things like databases or service orchestration.
  # lib.ssh.command.docker "${vSTATIC_DOCKER_MOUNTED_LAUNCH_DIR}/${vSTATIC_LINUX_SH_FILENAME} docker ${vSUPPLIED_GITHUB_USERNAME} ${vSUPPLIED_GITHUB_EMAIL} ${vSUPPLIED_GITHUB_TOKEN}"
  lib.status.set "${vSTATUS_BOOTSTRAPPED_DOCKER}" "$(lib.utils.full_date)"
  log.info "bootstrapped the local docker container."

  # This is redundant, but it's a good safety check because
  # if something bad happened and the old ip is the same as the current
  # we'll end up destroying the current instance. Yikes.
  local ip_to_deprovision="$(lib.store.project.get "ip_to_deprovision")"
  if [[ ${ip_to_deprovision} = "${vDETECTED_REMOTE_IP}" ]]; then
    log.error "Unexpected error: the ip to deprovision is the same as the current ip. Exiting."
    exit 1
  fi

  # The active ip should never be empty.
  if [[ -z ${vDETECTED_REMOTE_IP} ]]; then
    log.error "Unexpected error: the current ip is empty. Exiting."
    exit 1
  fi

  # Destroy the vultr instance associated with the old ip and then
  # delete the store entry so this never happens twice.
  if [[ -n ${ip_to_deprovision} ]]; then
    lib.utils.warn_with_delay "DANGER: destroying instance: ${ip_to_deprovision}"
    lib.vultr.compute.get_instance_id_from_ip "${ip_to_deprovision}"
    local instance_id_to_deprovision="${vPREV_RETURN[0]}"
    if [[ ${instance_id_to_deprovision} = "null" ]]; then
      log.error "Unexpected error: couldn't find instance for ip: \`${ip_to_deprovision}\`. Nothing to deprovision."
      exit 1
    fi
    lib.vultr.compute.destroy_instance "${instance_id_to_deprovision}"
    log.info "destroyed the previous instance with ip: ${ip_to_deprovision}"
    lib.store.project.del "ip_to_deprovision"
    log.info "deleted the ip_to_deprovision store entry."
  fi
  lib.status.set "${vSTATUS_LAUNCH_SUCCEEDED}" "$(lib.utils.full_date)"
  log.success "launch completed successfully."
}
