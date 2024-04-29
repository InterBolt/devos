#!/usr/bin/env bash

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../solos.sh
. shared/empty.sh
# shellcheck source=../lib/ssh.sh
. shared/empty.sh
# shellcheck source=../lib/status.sh
. shared/empty.sh
# shellcheck source=../lib/store.sh
. shared/empty.sh
# shellcheck source=../lib/utils.sh
. shared/empty.sh
# shellcheck source=../lib/vultr.sh
. shared/empty.sh
# shellcheck source=../task/boot.sh
. shared/empty.sh

cmd.provision() {
  solos.use_checked_out_project
  solos.collect_supplied_variables

  # Only consider the project provisioned if all the S3 variables are set.
  local already_provisioned_s3=$(
    [[ -n ${vS3_HOST} ]] &&
      [[ -n ${vS3_ACCESS_KEY} ]] &&
      [[ -n ${vS3_SECRET} ]] &&
      [[ -n ${vS3_OBJECT_STORE} ]] &&
      echo "true" ||
      echo "false"
  )
  if [[ ${already_provisioned_s3} = true ]]; then
    log.warn "S3 host already provisioned: ${vS3_HOST}. See \`solos --help\` for how to re-provision."
    sleep 1
  else
    log.info "Provisioning S3 compatible object storage via ${vSUPPLIED_PROVIDER_NAME}"
    sleep .5
    provision."${vSUPPLIED_PROVIDER_NAME}".s3
    # set the global solos variables
    vS3_OBJECT_STORE="${vPREV_RETURN[0]}"
    vS3_ACCESS_KEY="${vPREV_RETURN[1]}"
    vS3_SECRET="${vPREV_RETURN[2]}"
    vS3_HOST="${vPREV_RETURN[3]}"
    # set the store so that future runs will skip the provisioning step
    lib.store.project.set "s3_object_store" "${vS3_OBJECT_STORE}"
    lib.store.project.set "s3_access_key" "${vS3_ACCESS_KEY}"
    lib.store.project.set "s3_secret" "${vS3_SECRET}"
    lib.store.project.set "s3_host" "${vS3_HOST}"
  fi

  # If a pub key was not created exit early
  local ssh_pubkey="$(lib.ssh.project_cat_pubkey)"
  if [[ -z ${ssh_pubkey} ]]; then
    log.error "Unexpected error: no SSH public key found."
    sleep 1
    exit 1
  fi

  # Figure out the ssh key id by either finding it or creating it.
  log.info "Creating or finding the project's SSH keypair on Vultr."
  sleep .5
  local sshkey_id=""
  local found_sshkey_id="$(provision."${vSUPPLIED_PROVIDER_NAME}".get_pubkey_id "${ssh_pubkey}")"
  local sshkey_label="solos-${vPROJECT_NAME}"
  if [[ -z ${found_sshkey_id} ]]; then
    sshkey_id="$(provision.vultr.save_pubkey "${sshkey_label}" "${ssh_pubkey}")"
  else
    sshkey_id="${found_sshkey_id}"
  fi

  # Test before proceeding.
  if [[ -z ${sshkey_id} ]]; then
    log.error "Unexpected error: no SSH key ID was found or created."
    sleep 1
    exit 1
  fi

  provision."${vSUPPLIED_PROVIDER_NAME}".create_server "${vPROJECT_NAME}" "${ssh_pubkey}"
  local returned_ip="${vPREV_RETURN[0]:-""}"
  if [[ -z ${returned_ip} ]]; then
    log.error "Unexpected error: no provisioned IP was found."
    sleep 1
    exit 1
  fi
  vPROJECT_IP="${returned_ip}"

  # The building of this file is idempotent and is "re-done" on every run.
  log.info "Building the SSH config file for VSCode."
  sleep .5
  lib.ssh.project_build_project_config "${vPROJECT_IP}"

  # Let's inject any global variables from this script into the launch files.
  log.info "Preparing project launch files."
  sleep .5
  local template_launch_dir="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}/src/bin/launch"
  local launch_dir="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}/launch"
  if [[ -d "${launch_dir}" ]]; then
    log.warn "Rebuilding and overwriting the project's launch files."
  else
    log.info "Creating the project's launch files."
  fi
  local tmp_launch_dir="$(mktmp -d)/launch"
  mkdir -p "${tmp_launch_dir}"
  cp -a "${template_launch_dir}/." "${tmp_launch_dir}/"
  if ! lib.utils.template_variables "${tmp_launch_dir}" "commit" 2>&1; then
    log.error "Unexpected error: failed to inject variables into launch files."
    exit 1
  fi
  rm -rf "${launch_dir}"
  mv "${tmp_launch_dir}" "${launch_dir}"

  # Docker image variables
  local caddy_docker_image="solos:caddy"
  local caddy_dockerfile="${launch_dir}/Dockerfile.caddy"
  local caddyfile="${launch_dir}/Caddyfile"
  [[ ! -f "${caddy_dockerfile}" ]] && log.error "Could not find: ${caddy_dockerfile}" && exit 1
  [[ ! -f "${caddyfile}" ]] && log.error "Could not find: ${caddyfile}" && exit 1

  # Removes the linux login message for future SSH commands.
  log.info "Disabling annnoying SSH login message for future commands."
  sleep .5
  lib.ssh.project_command 'touch /root/.hushlogin || exit 0'

  log.info "Setting up firewall on server."
  sleep .5
  lib.ssh.project_command 'ufw allow 22,80,443'
  lib.ssh.project_command 'ufw allow 443/udp'

  log.info "Enabling colored output from ssh commands."
  sleep .5
  lib.ssh.project_command 'echo "export TERM=xterm-256color" >>/root/.bashrc'

  log.info "Creating docker directory on the remote server."
  sleep .5
  lib.ssh.project_command 'mkdir -p /root/solos/docker'

  log.info "Creating caddy directories on the remote server."
  sleep .5
  lib.ssh.project_command 'mkdir -p /root/solos/caddy/config'
  lib.ssh.project_command 'mkdir -p /root/solos/caddy/data'
  lib.ssh.project_command 'mkdir -p /root/solos/caddy/etc'

  log.info "Uploading the caddyfile to the remote server."
  sleep .5
  lib.ssh.project_rsync_up "${launch_dir}/Caddyfile" "/root/solos/caddy/etc/"

  log.info "Uploading a dockerfile to build the caddy image."
  sleep .5
  lib.ssh.project_rsync_up "${launch_dir}/Dockerfile.caddy" "/root/solos/docker/"

  # TODO: research other ways to install based on the OS. For now, I'm fine
  # TODO[.]: assuming debian for all the things.
  log.info "Installing Docker on the remote server."
  sleep .5
  lib.ssh.project_command <<EOF
${vHEREDOC_DEBIAN_INSTALL_DOCKER}
EOF

  log.info "Building the caddy docker image on the server."
  sleep .5
  lib.ssh.project_command "cd /root/solos/docker/ \
    && docker build \
      -q \
      -t "${caddy_docker_image}" \
      -f Dockerfile.caddy ."

  log.info "Starting caddy."
  sleep .5
  if ! lib.ssh.project_command "docker run \
    -d \
    -p 80:80 \
    -p 443:443 \
    -p 443:443/udp \
    -v /root/solos/caddy/config:/config/caddy \
    -v /root/solos/caddy/data:/data/caddy \
    -v /root/solos/caddy/etc:/etc/caddy \
    ${caddy_docker_image}" >&2; then
    log.error "Failed to start the remote docker container."
    exit 1
  fi
}
