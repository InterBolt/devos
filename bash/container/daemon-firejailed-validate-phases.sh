#!/usr/bin/env bash

# What is this script?
# ---------------------
# This script will run before any installed plugins are executed in order to validate some set of assumptions around
# files, networking, and other such things. If this script fails, SolOS will enter a "panicked" state and will not
# execute any further plugins. This script should be as simple as possible and should not rely on any external dependencies.
# Note: installed plugins cannot be shell scripts, they should be statically linked binaries. This precheck plugin script is the
# exception.

# SolOS Plugin API:
# -----------------
# The plugin API is fundamentally based on some set of files and folders that get included in the firejailed sandbox where a plugin executable runs.
# A plugin executable should implement various phases by conditionally executing code based on the value of the first argument supplied to it.
# Each phase gets read/write access to specific files and folders and the SolOS daemon is responsible for ensuring these files and folders
# are created, destroyed, and shared with subsequent phases.
#
# Rules for each --[phase] are as follows:
# ----------------------------------------
# --phase-configure
#   - available filesystem [file:/root/config.json (read/write)]
#       - file:/root/config.json is a file that may or may not exist. If it does that means the user
#         has configured the plugin in some other step. A plugin should validate the config file if it
#         exists and if it doesn't, it should create a default one.
#   - networking [none]
# --phase-download
#   - available filesystem [file:/root/config.json (read only), dir:/root/download (read/write)]
#       - file:/root/config.json is a file that may or may not exist. If it does that means the user
#         has configured the plugin in some other step. A plugin should validate the config file if it
#         exists and if it doesn't, it should create a default one.
#       - dir:/root/download is an empty directory where the plugin will store any downloaded files.
#   - networking [allowed]
# --phase-collection
#   - available filesystem [file:/root/config.json (read only), dir:/root/collection (read/write), dir:/root/.solos (read only)]
#       - dir:/root/.solos contains all of the users config, projects, app, everything
#         related to SolOS and their development environment.
#       - dir:/root/collection is an empty directory where the plugin will store "collected" data that
#         it downloads/extracts from the internet and the user's .solos directory.
#   - networking [none]
# --phase-process
#   - available filesystem [file:/root/config.json (read only), dir:/root/collection (read only), dir:/root/.solos (read only), file:/root/processed.json (read/write)]
#       - dir:/root/collection files from the collection phase.
#       - dir:/root/.solos same as above.
#       - file:/root/processed.json stores the "processed" data that the plugin generates. Since plugin authors will write their plugins using "real"
#         programming languages, JSON seems like a good format for the processed data. The SolOS daemon combines json from all plugins into a single
#         JSON array where objects are in the format: { "plugin": "plugin-name", "data": { ... } }.
#   - networking [none]
# --phase-push
#   - available filesystem [file:/root/config.json (read only), file:/root/processed.json (read only)]
#       - file:/root/processed.log is a file where each line is the encoded json from the processed.json files produced by all the plugins.
#   - networking [allowed]
#
# Threat model - negligence/accidental leaks:
# -------------------------------------------
# If SolOS is a usable service for the general public, it's probably DOA if it must fend of highly sophisticated and malicious plugin authors.
# Instead of worrying too much about that, the focus should be on making it difficult for a "reasonably" trustworthy authors to accidentally
# damage or leake sensitive user data.
# There could come a time where SolOS develops the sophistication to ward off even the worst actors, but even then, the nature of using the
# processed data from a plugin to inform an LLM response bot could result in a malicious actor using a plugin to generate a subtle responses that
# convinces the user to do harmful things. This is a problem that can't be solved through a purely technical solution. Ultimately, software
# like this will depend on the development of a community that looks out for one another when vetting plugins.
#
# Security via plugin phases:
# ---------------------------
# We limit network access to the download phase and push phase. The download phase can't access any user data, so it's safe to allow network access.
# And the push phase can only access the processed data, which is far less likely to contain accidentally leaked sensitive data. SolOS can add
# intermediate scrubbing to the processed data anyways to further mitigate leakage risks.
#
# HELPER FUNCTIONS
#
daemon_firejailed_validate_phases.verify_absence() {
  for path in "${@}"; do
    if [[ -e ${path} ]]; then
      echo "SOLOS_PANIC: ${path} should not exist."
      exit 1
    fi
  done
}
daemon_firejailed_validate_phases.verify_read_and_write() {
  for path in "${@}"; do
    if [[ ! -w ${path} ]]; then
      echo "SOLOS_PANIC: ${path} should be set to read/write."
      exit 1
    fi
  done
}
daemon_firejailed_validate_phases.verify_read_only() {
  for path in "${@}"; do
    if [[ -w ${path} ]]; then
      echo "SOLOS_PANIC: ${path} should be set to read only."
      exit 1
    fi
  done
}
daemon_firejailed_validate_phases.verify_files_exists() {
  for path in "${@}"; do
    if [[ ! -f ${path} ]]; then
      echo "SOLOS_PANIC: ${path} file should exist."
      exit 1
    fi
  done
}
daemon_firejailed_validate_phases.verify_dirs_exists() {
  for path in "${@}"; do
    if [[ ! -d ${path} ]]; then
      echo "SOLOS_PANIC: ${path} directory should exist."
      exit 1
    fi
  done
}
daemon_firejailed_validate_phases.verify_network_acccess() {
  local enabled="${1:-"true"}"
  local urls=(
    "https://www.google.com"
    "https://www.github.com"
    "https://www.example.com"
    "https://www.facebook.com"
    "https://www.twitter.com"
    "https://www.linkedin.com"
    "https://www.instagram.com"
    "https://www.reddit.com"
    "https://www.youtube.com"
    "https://www.netflix.com"
    "https://www.hulu.com"
  )
  for url in "${urls[@]}"; do
    if curl -s -I "${url}" >/dev/null; then
      if [[ ${enabled} = false ]]; then
        echo "SOLOS_PANIC: Network access should be disabled." >&2
        exit 1
      fi
    fi
  done
  if [[ ${enabled} = true ]]; then
    echo "SOLOS_PANIC: Network access should be enabled." >&2
    exit 1
  fi
}
#
# PHASE TESTS:
#
daemon_firejailed_validate_phases.main() {
  local solos_dir="/root/.solos"
  local config_file="/root/config.json"
  local download_dir="/root/download"
  local collection_dir="/root/collection"
  local processed_file="/root/processed.json"

  if [[ ${1} = "--phase-configure" ]]; then
    daemon_firejailed_validate_phases.verify_absence \
      "${solos_dir}" \
      "${download_dir}" \
      "${collection_dir}" \
      "${processed_file}"
    daemon_firejailed_validate_phases.verify_files_exists \
      "${config_file}"
    daemon_firejailed_validate_phases.verify_read_and_write \
      "${config_file}"
    daemon_firejailed_validate_phases.verify_network_acccess "false"

  elif [[ ${1} = "--phase-download" ]]; then
    daemon_firejailed_validate_phases.verify_absence \
      "${solos_dir}" \
      "${collection_dir}" \
      "${processed_file}"

    daemon_firejailed_validate_phases.verify_dirs_exists \
      "${download_dir}"

    daemon_firejailed_validate_phases.verify_files_exists \
      "${config_file}"

    daemon_firejailed_validate_phases.verify_read_and_write \
      "${download_dir}"

    daemon_firejailed_validate_phases.verify_read_only \
      "${config_file}"

    daemon_firejailed_validate_phases.verify_network_acccess "true"

  elif [[ ${1} = "--phase-collection" ]]; then
    daemon_firejailed_validate_phases.verify_absence \
      "${download_dir}" \
      "${processed_file}"
    daemon_firejailed_validate_phases.verify_files_exists \
      "${config_file}"
    daemon_firejailed_validate_phases.verify_dirs_exists \
      "${solos_dir}"
    daemon_firejailed_validate_phases.verify_read_only \
      "${solos_dir}" \
      "${config_file}"
    daemon_firejailed_validate_phases.verify_read_and_write \
      "${collection_dir}"
    daemon_firejailed_validate_phases.verify_network_acccess "false"

  elif [[ ${1} = "--phase-process" ]]; then
    daemon_firejailed_validate_phases.verify_absence \
      "${download_dir}"
    daemon_firejailed_validate_phases.verify_dirs_exists \
      "${solos_dir}" \
      "${collection_dir}"
    daemon_firejailed_validate_phases.verify_files_exists \
      "${processed_file}" \
      "${config_file}"
    daemon_firejailed_validate_phases.verify_read_only \
      "${solos_dir}" \
      "${collection_dir}" \
      "${config_file}"
    daemon_firejailed_validate_phases.verify_read_and_write \
      "${processed_file}"
    daemon_firejailed_validate_phases.verify_network_acccess "false"

  elif [[ ${1} = "--phase-push" ]]; then
    daemon_firejailed_validate_phases.verify_absence \
      "${download_dir}" \
      "${collection_dir}" \
      "${solos_dir}"
    daemon_firejailed_validate_phases.verify_files_exists \
      "${processed_file}" \
      "${config_file}"
    daemon_firejailed_validate_phases.verify_read_only \
      "${processed_file}" \
      "${config_file}"
    daemon_firejailed_validate_phases.verify_network_acccess "true"

  else
    echo "SOLOS_PANIC: ${1} does not equal one of --phase-configure, --phase-download, --phase-collection, --phase-process, or --phase-push."
    exit 1
  fi
}

daemon_firejailed_validate_phases.main "$@"
