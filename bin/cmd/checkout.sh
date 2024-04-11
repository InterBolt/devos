#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

cmd.checkout() {
  #
  # Important: do these checks BEFORE saving the provided directory in the
  # lib.cache. Let's be sure any directories we put there are valid and safe.
  #
  lib.validate.checked_out_server_and_dir
  lib.validate.throw_if_dangerous_dir
  lib.validate.throw_if_missing_installed_commands
  #
  # The value of vCLI_OPT_SERVER is derived from either a flag value
  # or from the server type of the associated checked out directory.
  #
  # If a flag is provided that does not match the server specificed
  # in the checked out directory, we'll throw an error.
  #
  lib.cache.set "checked_out" "$vCLI_OPT_DIR"
  log.info "checked out dir: $vCLI_OPT_DIR"
  if [ -f "$vCLI_OPT_DIR/$vSTATIC_SOLOS_ID_FILENAME" ]; then
    vENV_SOLOS_ID="$(cat "$vCLI_OPT_DIR/$vSTATIC_SOLOS_ID_FILENAME")"
    log.debug "set \$vENV_SOLOS_ID= $vENV_SOLOS_ID"
  fi
  if [ -f "$(lib.ssh.path_config.self)" ]; then
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
    local most_recent_ip="$(lib.ssh.extract_ip.remote)"
    lib.cache.set "most_recent_ip" "$most_recent_ip"
    log.debug "updated the most recent ip in the lib.cache."
  fi
}
