#!/usr/bin/env bash

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

cmd.gen._exports() {
  local dir="$1"
  if [ ! -d "${dir}" ]; then
    log.error "A valid directory was not provided."
    exit 1
  fi
  local tmp_exports_file="$(mktemp 2>/dev/null)"
  local exports_file="${dir}/__exports__.sh"
  echo "#!/usr/bin/env bash" >"${tmp_exports_file}"
  echo "" >>"${tmp_exports_file}"
  for file in "${dir}"/*.sh; do
    if [ ! -f "${file}" ]; then
      continue
    fi
    local filename=$(basename "${file}")
    {
      echo "# shellcheck source=${filename}"
      echo ". ${filename}"
    } >>"${tmp_exports_file}"
  done
  rm -f "${exports_file}"
  cp "${tmp_exports_file}" "${exports_file}"
  rm -f "${tmp_exports_file}"
}

cmd.gen() {
  cmd.gen._exports "cmds"
  log.info "generated cmd exports: cmds/__exports__.sh"
}

cmd.gen
