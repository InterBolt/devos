#!/usr/bin/env bash

SOLOS_DIR="${HOME}/.solos"
RCFILES_DIR="${SOLOS_DIR}/rcfiles"
USER_MANAGED_BASHRC_FILE="${RCFILES_DIR}/.bashrc"

# Initialize a bashrc file which allows the user to customize their shell.
if [[ ! -f "${USER_MANAGED_BASHRC_FILE}" ]]; then
  if [[ ! -d ${RCFILES_DIR} ]]; then
    if ! mkdir -p "${RCFILES_DIR}"; then
      echo "Failed to create ${RCFILES_DIR}" >&2
      exit 1
    fi
  fi
  cat <<EOF >"${USER_MANAGED_BASHRC_FILE}"
#!/usr/bin/env bash

. "\${HOME}/.solos/repo/profiles/bash/bashrc.sh" "\$@"

# Add your customizations to the SolOS shell.
# Tip: type \`info\` in the shell to see what functions and aliases are available.

install_solos
EOF
fi

echo "Host [migration]: completed migration - ${0}" >&2
