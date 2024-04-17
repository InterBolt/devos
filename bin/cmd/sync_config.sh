#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh
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
  solos.checkout_project_dir
  solos.store_ssh_derived_ip
  lib.utils.warn_with_delay "overwriting the remote config folder: ${vSTATIC_SOLOS_ROOT}"
  local tmp_dir="/root/.tmp"
  local tmp_remote_config_dir="${tmp_dir}/${vSTATIC_CONFIG_DIRNAME}"
  #
  # Rsync the config up to a tmp dir first. Once everything is A+, force delete
  # the old config folder and move the new one to its place. Should limit downtime.
  #
  # Note: like most commands, we should be able to run this from within our docker container
  # no differently than if we were on the local machine. vSTATIC_SOLOS_ROOT handles the
  # different absolute paths for local and docker since it uses the built-in $HOME variable.
  #
  lib.ssh.command.remote "rm -rf ${tmp_remote_config_dir} && mkdir -p ${tmp_remote_config_dir}"
  log.info "wiped remote ${tmp_remote_config_dir} folder in preparation for rsync."
  lib.ssh.rsync_up.remote "${vSTATIC_SOLOS_ROOT}/" "${tmp_remote_config_dir}/"
  log.info "uploaded ${vSTATIC_SOLOS_ROOT} to the remote server"
  lib.ssh.command.remote "rm -rf ${vSTATIC_SOLOS_ROOT} && mv ${tmp_remote_config_dir} ${vSTATIC_SOLOS_ROOT}"
  log.info "overwrote remote's config."
  lib.ssh.command.remote "rm -rf ${tmp_remote_config_dir}"
  log.info "removed ${tmp_remote_config_dir} on the remote."
  log.info "success: synced config folder to remote."
}
