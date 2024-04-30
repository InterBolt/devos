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

  # Simply retrieves storage info if the provisioning already happened.
  log.info "${vPROJECT_NAME} - Provisioning S3-compatible ${vSUPPLIED_PROVIDER_NAME} storage"
  provision."${vSUPPLIED_PROVIDER_NAME}".s3
  vS3_OBJECT_STORE="${vPREV_RETURN[0]}"
  vS3_ACCESS_KEY="${vPREV_RETURN[1]}"
  vS3_SECRET="${vPREV_RETURN[2]}"
  vS3_HOST="${vPREV_RETURN[3]}"
  lib.store.project.set "s3_object_store" "${vS3_OBJECT_STORE}"
  lib.store.project.set "s3_access_key" "${vS3_ACCESS_KEY}"
  lib.store.project.set "s3_secret" "${vS3_SECRET}"
  lib.store.project.set "s3_host" "${vS3_HOST}"

  # If a pub key was not created exit early
  local pubkey="$(lib.ssh.project_cat_pubkey)"
  if [[ -z ${pubkey} ]]; then
    log.error "Unexpected error: no SSH public key found."
    exit 1
  fi

  # Figure out the ssh key id by either finding it or creating it.
  log.info "${vPROJECT_NAME} - Creating or finding the project's SSH keypair on Vultr."
  provision."${vSUPPLIED_PROVIDER_NAME}".find_pubkey "${pubkey}"
  if [[ ${vPREV_RETURN[0]} = false ]]; then
    provision.vultr.save_pubkey "${pubkey}"
  fi

  if [[ -z ${vPROJECT_IP} ]]; then
    provision."${vSUPPLIED_PROVIDER_NAME}".create_server "${pubkey}"
    local server_ip="${vPREV_RETURN[0]:-""}"
    if [[ -z ${server_ip} ]]; then
      log.error "Unexpected error: no provisioned IP was found."
      exit 1
    fi
    vPROJECT_IP="${server_ip}"
  fi

  # The building of this file is idempotent and is "re-done" on every run.
  log.info "${vPROJECT_NAME} - Building SSH config."
  lib.ssh.project_build_config "${vPROJECT_IP}"

  # Let's inject any global variables from this script into the launch files.
  log.info "${vPROJECT_NAME} - Building launch files."
  local template_launch_dir="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}/src/bin/launch"
  local launch_dir="${vSTATIC_SOLOS_PROJECTS_DIR}/${vPROJECT_NAME}/launch"
  local tmp_launch_dir="$(mktmp -d)"
  cp -a "${template_launch_dir}/." "${tmp_launch_dir}/"
  lib.utils.template_variables "${tmp_launch_dir}"
  rm -rf "${launch_dir}"
  mv "${tmp_launch_dir}" "${launch_dir}"

  local caddy_docker_image="solos:caddy"
  local caddy_dockerfile="${launch_dir}/Dockerfile.caddy"
  local caddyfile="${launch_dir}/Caddyfile"
  [[ ! -f "${caddy_dockerfile}" ]] && log.error "Could not find: ${caddy_dockerfile}" && exit 1
  [[ ! -f "${caddyfile}" ]] && log.error "Could not find: ${caddyfile}" && exit 1

  # Removes the linux login message for future SSH commands.
  log.info "${vPROJECT_NAME} - Disabling linux login message."
  lib.ssh.project_command 'touch /root/.hushlogin || exit 0'

  log.info "${vPROJECT_NAME} - Exposing web ports."
  lib.ssh.project_command 'ufw allow 22,80,443'
  lib.ssh.project_command 'ufw allow 443/udp'

  log.info "${vPROJECT_NAME} - Enabling color support."
  lib.ssh.project_command 'echo "export TERM=xterm-256color" >>/root/.bashrc'

  log.info "${vPROJECT_NAME} - Creating /root/solos/apps"
  lib.ssh.project_command 'mkdir -p /root/solos/apps'

  log.info "${vPROJECT_NAME} - Creating /root/solos/docker"
  lib.ssh.project_command 'mkdir -p /root/solos/docker'

  log.info "${vPROJECT_NAME} - Creating /root/solos/logs"
  lib.ssh.project_command 'mkdir -p /root/solos/logs'

  log.info "${vPROJECT_NAME} - Creating /root/solos/cache"
  lib.ssh.project_command 'mkdir -p /root/solos/cache'

  log.info "${vPROJECT_NAME} - Creating /root/solos/caddy"
  lib.ssh.project_command 'mkdir -p /root/solos/caddy/config'

  log.info "${vPROJECT_NAME} - Creating /root/solos/caddy/data"
  lib.ssh.project_command 'mkdir -p /root/solos/caddy/data'

  log.info "${vPROJECT_NAME} - Creating /root/solos/caddy/etc"
  lib.ssh.project_command 'mkdir -p /root/solos/caddy/etc'

  log.info "${vPROJECT_NAME} - Uploading Caddyfile."
  lib.ssh.project_rsync_up "${launch_dir}/Caddyfile" "/root/solos/caddy/etc/"

  log.info "${vPROJECT_NAME} - Uploading Dockerfile.caddy."
  lib.ssh.project_rsync_up "${launch_dir}/Dockerfile.caddy" "/root/solos/docker/"

  # TODO: research other ways to install based on the OS. For now, I'm fine
  # TODO[.]: assuming debian for all the things.
  log.info "${vPROJECT_NAME} - Installing Docker."
  lib.ssh.project_command <<EOF
${vHEREDOC_DEBIAN_INSTALL_DOCKER}
EOF

  log.info "${vPROJECT_NAME} - Building Caddy."
  lib.ssh.project_command "cd /root/solos/docker/ \
    && docker build \
      -q \
      -t "${caddy_docker_image}" \
      -f Dockerfile.caddy ."

  log.info "${vPROJECT_NAME} - Starting caddy."
  lib.ssh.project_command "docker run \
    -d \
    -p 80:80 \
    -p 443:443 \
    -p 443:443/udp \
    -v /root/solos/caddy/config:/config/caddy \
    -v /root/solos/caddy/data:/data/caddy \
    -v /root/solos/caddy/etc:/etc/caddy \
    ${caddy_docker_image}"
}