#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"

# shellcheck source=static.sh
source static.sh
# shellcheck source=shared.log.sh
source shared.log.sh

log.ready "tests"

tests._insert_variable_into_test_file() {
  local file="$1"
  local variable="$2"
  if [ ! -f "$file" ]; then
    log.error "file not found: $file"
    exit 1
  fi
  local line_number="$(grep -nE '^v[A-Z_]{2,}=' "${file}" | tail -n 1 | cut -d: -f1)"
  local tmp_file="${file}.tmp.$(date +%s)"
  awk 'NR=='"$((line_number + 1))"'{print "'"${variable}="'\"\""}1' "${file}" >"${tmp_file}"
  cp -f "${tmp_file}" "${file}"
  rm -f "${tmp_file}"
}

tests._blank_failing_test() {
  local missing_function="$1"
  echo "__test__.${missing_function}() {${n}  log.error \"${missing_function} not implemented yet\"${n}  return 1${n}}"
}

tests._grep_lib_used_variables() {
  local lib_file="$1"
  if [ ! -f "$lib_file" ]; then
    log.error "file not found: $lib_file"
    exit 1
  fi
  grep -Eo 'v[A-Z_]{2,}' "$lib_file" | sort -u
}

tests._grep_lib_defined_variables() {
  local file="$1"
  if [ ! -f "$file" ]; then
    log.error "file not found: $file"
    exit 1
  fi
  grep -Eo 'v[A-Z_]{2,}=' "${file}" | cut -d= -f1 | sort -u
}

tests._grep_lib_defined_functions() {
  local lib_file="$1"
  local lib_unit_name="$2"
  if [ ! -f "$lib_file" ]; then
    log.error "file not found: $lib_file"
    exit 1
  fi
  grep -Eo "$lib_unit_name\.[a-z_\.]{2,}\(\)" "$lib_file" | sort -u | sed 's/()//'
}

tests._grep_test_defined_functions() {
  local lib_unit_name="$1"
  local lib_test_filepath="$2"
  if [ ! -f "$lib_test_filepath" ]; then
    log.error "file not found: $lib_test_filepath"
    exit 1
  fi
  grep -Eo "__test__\.${lib_unit_name}\.[a-z_\.]{2,}\(\)" "$lib_test_filepath" | sort -u | sed 's/()//' | sed 's/__test__\.//'
}

tests.unit.create_lib_test() {
  local lib_unit_name="$1"
  local force="${2:-false}"
  local lib_file="solos.${lib_unit_name}"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: $1"
    exit 1
  fi
  local test_dir="__tests__"
  local target_test_file="__test__.${lib_file}"
  local target_test_file_path="${test_dir}/${target_test_file}"
  if [ -f "${target_test_file_path}" ] && [ "${force}" == "false" ]; then
    return
  fi
  if [ "$force" == "true" ] && [ -f "${target_test_file_path}" ]; then
    mv "${target_test_file_path}" "${test_dir}/.archive.$(date +%s).${target_test_file}"
    log.warn "archived previous test file at: .archive.${target_test_file_path}"
  fi
  local defined_functions="$(tests._grep_lib_defined_functions "${lib_file}" "${lib_unit_name}")"
  local variables="$(tests._grep_lib_used_variables "${lib_file}")"
  local lines=(
    "#!/usr/bin/env bash"
    ""
    "# shellcheck source=../${lib_file}"
    "source \"${lib_file}\""
    ""
    "pre.test() {"
    "  log.info \"running pre.test\""
    "}"
    ""
    "post.test() {"
    "  log.info \"running post.test\""
    "}"
    ""
  )
  local n=$'\n'
  for variable in $variables; do
    lines+=("$variable=\"\"")
  done
  for defined_function in $defined_functions; do
    lines+=("")
    lines+=("$(tests._blank_failing_test "${defined_function}")")
  done
  for line in "${lines[@]}"; do
    echo "$line" >>"${target_test_file_path}"
  done
}

tests.unit.tests_add_missing_function_coverage() {
  local lib_unit_name="$1"
  local lib_file="solos.${lib_unit_name}"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: $1"
    exit 1
  fi
  local test_dir="__tests__"
  local target_test_file="__test__.${lib_file}"
  local target_test_file_path="${test_dir}/${target_test_file}"
  if [ ! -f "${target_test_file_path}" ]; then
    tests.unit.create_lib_test "${lib_unit_name}"
    return
  fi
  local defined_functions="$(tests._grep_lib_defined_functions "${lib_file}" "${lib_unit_name}")"
  local test_functions="$(tests._grep_test_defined_functions "${lib_unit_name}" "${target_test_file_path}")"
  local missing_functions=()
  for defined_function in $defined_functions; do
    if ! echo "$test_functions" | grep -q "^${defined_function}$"; then
      missing_functions+=("$defined_function")
    fi
  done
  if [ ${#missing_functions[@]} -eq 0 ]; then
    return
  fi
  local lines=()
  local n=$'\n'
  for missing_function in "${missing_functions[@]}"; do
    lines+=("")
    lines+=("$(tests._blank_failing_test "${missing_function}")")
  done
  for line in "${lines[@]}"; do
    echo "$line" >>"${target_test_file_path}"
  done
}

tests.unit.get_stale_test_functions() {
  local lib_unit_name="$1"
  local lib_file="solos.${lib_unit_name}"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: $1"
    exit 1
  fi
  local test_dir="__tests__"
  local target_test_file="__test__.${lib_file}"
  local target_test_file_path="${test_dir}/${target_test_file}"
  if [ ! -f "${target_test_file_path}" ]; then
    log.error "test file not found: ${target_test_file_path}"
    return
  fi

  local defined_functions="$(tests._grep_lib_defined_functions "${lib_file}" "${lib_unit_name}")"
  local test_functions="$(tests._grep_test_defined_functions "${lib_unit_name}" "${target_test_file_path}")"
  local missing_functions=()
  for test_function in $test_functions; do
    if ! echo "$defined_functions" | grep -q "^${test_function}$"; then
      missing_functions+=("$test_function")
    fi
  done
  if [ ${#missing_functions[@]} -eq 0 ]; then
    return
  fi
  for missing_function in "${missing_functions[@]}"; do
    echo "${missing_function}"
  done
}

tests.unit.get_undefined_test_variables() {
  local lib_unit_name="$1"
  local lib_file="solos.${lib_unit_name}"
  local test_lib_file="__tests__/__test__.${lib_file}"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: $1"
    exit 1
  fi
  if [ ! -f "${test_lib_file}" ]; then
    return
  fi
  local defined_test_variables="$(tests._grep_lib_defined_variables "${test_lib_file}")"
  local used_lib_variables="$(tests._grep_lib_used_variables "${lib_file}")"
  local missing_variables=()
  for used_variable in $used_lib_variables; do
    if ! echo "$defined_test_variables" | grep -q "^${used_variable}$"; then
      missing_variables+=("$used_variable")
    fi
  done
  if [ ${#missing_variables[@]} -eq 0 ]; then
    return
  fi
  echo "${missing_variables[*]}"
}

tests.unit.get_stale_test_variables() {
  local lib_unit_name="$1"
  local lib_file="solos.${lib_unit_name}"
  local test_lib_file="__tests__/__test__.${lib_file}"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: $1"
    exit 1
  fi
  if [ ! -f "${test_lib_file}" ]; then
    return
  fi
  local defined_test_variables="$(tests._grep_lib_defined_variables "${test_lib_file}")"
  local used_lib_variables="$(tests._grep_lib_used_variables "${lib_file}")"
  local stale_variables=()
  for defined_variable in $defined_test_variables; do
    if ! echo "$used_lib_variables" | grep -q "^${defined_variable}$"; then
      stale_variables+=("$defined_variable")
    fi
  done
  if [ ${#stale_variables[@]} -eq 0 ]; then
    return
  fi
  echo "${stale_variables[*]}"
}

tests.step.verify_test_source_exists() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find '__tests__' -maxdepth 1 -type f -name '__test__.solos.*' -print0)
  local missing_source_files=()
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(basename "${lib_file}" | sed 's/^__test__\.solos\.//')"
    if [ ! -f "solos.${lib_unit_name}" ]; then
      missing_source_files+=("solos.${lib_unit_name}")
    fi
  done
  if [ ${#missing_source_files[@]} -gt 0 ]; then
    log.error "missing source files: ${missing_source_files[*]}"
    exit 1
  fi
}

tests.step.verify_function_coverage() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'solos.*' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(basename "${lib_file}" | sed 's/^solos\.//')"
    local target_test_file_path="__tests__/__test__.solos.${lib_unit_name}"
    local defined_lib_functions="$(tests._grep_lib_defined_functions "${lib_file}" "${lib_unit_name}")"
    local defined_test_functions="$(tests._grep_test_defined_functions "${lib_unit_name}" "${target_test_file_path}")"
    if [ "${#defined_lib_functions[@]}" -ne "${#defined_test_functions[@]}" ]; then
      log.error "function coverage failed for ${lib_unit_name}"
      log.error "defined functions: ${defined_lib_functions[*]}"
      log.error "test functions: ${defined_test_functions[*]}"
      exit 1
    fi
  done
}

tests.step.verify_variable_coverage() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'solos.*' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(basename "${lib_file}" | sed 's/^solos\.//')"
    local target_test_file_path="__tests__/__test__.solos.${lib_unit_name}"
    local used_variables_in_lib="$(tests._grep_lib_used_variables "${lib_file}")"
    local defined_variables_in_test="$(tests._grep_lib_defined_variables "${target_test_file_path}")"
    if [ "${#used_variables_in_lib[@]}" -ne "${#defined_variables_in_test[@]}" ]; then
      log.error "variable coverage failed for ${lib_unit_name}"
      log.error "used variables: ${used_variables_in_lib[*]}"
      log.error "defined variables: ${defined_variables_in_test[*]}"
      exit 1
    fi
  done
}

tests.step.cover_functions() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'solos.*' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(basename "${lib_file}" | sed 's/^solos\.//')"
    tests.unit.tests_add_missing_function_coverage "${lib_unit_name}"
  done
}

tests.step.cover_variables() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'solos.*' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(basename "${lib_file}" | sed 's/^solos\.//')"
    local undefined_variables="$(tests.unit.get_undefined_test_variables "${lib_unit_name}")"
    if [ -n "$undefined_variables" ]; then
      for undefined_variable in $undefined_variables; do
        tests._insert_variable_into_test_file "__tests__/__test__.solos.${lib_unit_name}" "${undefined_variable}"
      done
    fi
  done
}

tests.dangerously_recreate() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'solos.*' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(basename "${lib_file}" | sed 's/^solos\.//')"
    tests.unit.create_lib_test "${lib_unit_name}" true
  done
}

tests.init() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'solos.*' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(basename "${lib_file}" | sed 's/^solos\.//')"
    tests.unit.create_lib_test "${lib_unit_name}"
  done
}

tests.cover() {
  tests.step.cover_functions
  tests.step.cover_variables
}

tests.verify() {
  tests.step.verify_function_coverage
  tests.step.verify_variable_coverage
  tests.step.verify_test_source_exists
}

tests.run.unit() {
  local lib_unit_name="$1"
  local lib_file="solos.${lib_unit_name}"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: ${lib_file}"
    exit 1
  fi
  local lib_test_file="__tests__/__test__.solos.${lib_unit_name}"
  if [ ! -f "${lib_test_file}" ]; then
    log.error "test file not found: $1"
    exit 1
  fi
  local defined_functions="$(tests._grep_test_defined_functions "${lib_unit_name}" "${lib_test_file}")"
  chmod +x "$lib_test_file"
  # shellcheck disable=SC1090
  source "$lib_test_file"
  pre.test
  for defined_function in ${defined_functions}; do
    local test_function="__test__.${defined_function}"
    if ! type "${test_function}" &>/dev/null; then
      log.error "test function not found: ${test_function}"
      exit 1
    fi
    if ! "${test_function}"; then
      log.error "failed: ${lib_test_file}:${test_function}"
    else
      log.success "passed: ${lib_test_file}:${test_function}"
    fi
  done
  post.test
}

tests.run() {
  local lib_files=()
  if [ "$#" -eq 0 ]; then
    while IFS= read -r -d $'\0' file; do
      lib_files+=("$file")
    done < <(find . -maxdepth 1 -type f -name 'solos.*' -print0)
  else
    local lib_unit_name="$1"
    local lib_test_file="$PWD/__tests__/__test__.solos.${lib_unit_name}"
    if [ ! -f "${lib_test_file}" ]; then
      log.error "test file not found: $1"
      exit 1
    fi
    lib_files+=("$PWD/solos.${lib_unit_name}")
  fi
  tests.init
  tests.cover
  tests.verify
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(basename "${lib_file}" | sed 's/^solos\.//')"
    tests.run.unit "${lib_unit_name}"
  done
}

tests.run "$@"
