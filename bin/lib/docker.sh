#!/usr/bin/env bash
# shellcheck disable=SC2317

SELF_LIB_DOCKER_SOCKET_PATH="/var/run/docker.sock"

# shellcheck source=../shared/must-source.sh
. shared/must-source.sh

# shellcheck source=../shared/static.sh
. shared/empty.sh
# shellcheck source=../shared/log.sh
. shared/empty.sh
# shellcheck source=../bin.sh
. shared/empty.sh

# lib.docker.install_remote() {

# }

# # This must rely on a hack where it passes in the path of the host where the docker daemon is running.
# # In prod, we expect the path to the volumes to actually be the same since our containers run the same OS
# # and rely on the same basic filesystem structure.
# # HOWEVER, not being able to test defeats the purpose of dockerizing the remote server. To do that locally,
# # we must consider when docker is run on a non-debian environment, like my Mac.
# lib.docker.start_remote() {
#   local email="${1}"
#   local caprover_password="${2}"
#   local caprover_root_domain="${3}"
#   local caprover_remote_ip="${4}"

#   if [[ -z "${email}" || -z "${caprover_password}" || -z "${caprover_root_domain}" || -z "${caprover_remote_ip}" ]]; then
#     log.error "Missing arguments. Can't start the remote docker container." >&2
#     exit 1
#   fi
#   if [[ "${email}" != *@* ]]; then
#     log.error "Invalid email address." >&2
#     exit 1
#   fi
#   if [[ -z "${caprover_password}" ]]; then
#     log.error "Invalid password." >&2
#     exit 1
#   fi
#   if [[ "${caprover_root_domain}" != *.* ]]; then
#     log.error "Invalid root domain." >&2
#     exit 1
#   fi
#   if [[ "${caprover_remote_ip}" != *.*.*.* ]]; then
#     log.error "Invalid remote IP address." >&2
#     exit 1
#   fi

#   local entry_pwd="${PWD}"
#   cd "${HOME}" || exit 1

#   local host_solos_root="$(cat "${vSTATIC_SOLOS_ROOT}/${vSTATIC_SOLOS_HOST_REFERENCE_FILE}")"
#   local launch_rel_dir="/src/bin/launch"
#   local both_rel_volume_path="$(basename "${vSTATIC_SOLOS_PROJECTS_DIR}")/test"
#   if ! docker build -t "solos:base" -f "${vSTATIC_SOLOS_ROOT}${launch_rel_dir}/Dockerfile.base" . >/dev/null; then
#     log.error "Could not build the base image." >&2
#     exit 1
#   fi
#   if ! docker build -t "solos:remote" -f "${vSTATIC_SOLOS_ROOT}${launch_rel_dir}/Dockerfile.caddy" . >/dev/null; then
#     log.error "Could not build the remote image." >&2
#     exit 1
#   fi

#   # We'll need both paths.
#   local host_project_dir="${host_solos_root}/${both_rel_volume_path}"
#   local container_project_dir="${vSTATIC_SOLOS_ROOT}/${both_rel_volume_path}"

#   # Create the directory on the host and container since it's in a mounted dir.
#   mkdir -p "${container_project_dir}/captain"

#   # Make the proxy script executable if it isn't already.
#   # We already did the chmod in the dockerfile where we mount this.
#   if ! chmod +x "${vSTATIC_SOLOS_ROOT}"/src/bin/solos.sh; then
#     log.error "Could not make the proxy script executable." >&2
#     exit 1
#   fi

#   local cmd_symlink_bin="ln -sfv ${vSTATIC_SOLOS_ROOT}/src/bin/solos.sh /usr/local/bin/solos && chmod +x /usr/local/bin/solos"
#   local cmd_launch_caprover='docker run \
#     -p 80:80 -p 443:443 -p 3000:3000 \
#     -e ACCEPTED_TERMS=true \
#     -v '"${SELF_LIB_DOCKER_SOCKET_PATH}"':'"${SELF_LIB_DOCKER_SOCKET_PATH}"' -v '"${host_project_dir}/captain"':/captain \
#     caprover/caprover'
#   local cmd_setup_caprover='caprover serversetup -y \
#     -e '"${email}"' \
#     -w '"${caprover_password}"' \
#     -r '"${caprover_root_domain}"' \
#     -n solos \
#     -i '"${caprover_remote_ip}"''
#   # MUST COME LAST. This is what keeps the server alive.
#   local cmd_start_ssh='/usr/sbin/sshd -D'

#   # Will start up caprover and kick off an SSH server. When we ssh in to the remote
#   # we'll end up in this container which has everything we need to be effective.
#   if ! docker run \
#     -d \
#     -p 22 \
#     -v "${host_solos_root}":"${vSTATIC_SOLOS_ROOT}" \
#     -v "${SELF_LIB_DOCKER_SOCKET_PATH}":"${SELF_LIB_DOCKER_SOCKET_PATH}" \
#     solos:remote /bin/bash -c \
#     "cd /root && ${cmd_symlink_bin} && ${cmd_launch_caprover} && ${cmd_setup_caprover} && ${cmd_start_ssh}"; then
#     log.error "Could not start the remote container." >&2
#     exit 1
#   fi

#   # Get back to where we were.
#   cd "${entry_pwd}" || exit 1
# }
