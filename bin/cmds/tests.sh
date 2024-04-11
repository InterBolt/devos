#!/usr/bin/env bash
# shellcheck disable=SC2103,SC2164
# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

LIB_TEST_FILE_OPENING_LINES=()
LIB_FILES_FAILED=()
LIB_FAILED=()
LIB_PASSED=()

subcmd.tests._update_beginning_file_lines() {
  local lib_file="$1"
  LIB_TEST_FILE_OPENING_LINES=(
    "#!/usr/bin/env bash"
    ""
    "set -o errexit"
    "set -o pipefail"
    "set -o errtrace"
    ""
    "if [ \"\$(basename \"\$(pwd)\")\" != \"bin\" ]; then"
    "  echo \"error: must be run from the bin folder\""
    "  exit 1"
    "fi"
    ""
    " # shellcheck source=../${lib_file}"
    ". \"${lib_file}\""
    ""
    "__hook__.before_file() {"
    "  log.error \"__hook__.before_file\""
    "  return 1"
    "}"
    ""
    "__hook__.after_file() {"
    "  log.error \"running __hook__.after_file\""
    "  return 1"
    "}"
    ""
    "__hook__.before_fn() {"
    "  log.error \"running __hook__.before_fn \$1\""
    "  return 1"
    "}"
    ""
    "__hook__.after_fn() {"
    "  log.error \"running __hook__.after_fn \$1\""
    "  return 1"
    "}"
    ""
    "__hook__.after_fn_success() {"
    "  log.error \"__hook__.after_fn_success \$1\""
    "  return 1"
    "}"
    ""
    "__hook__.after_fn_fails() {"
    "  log.error \"__hook__.after_fn_fails \$1\""
    "  return 1"
    "}"
    ""
    "__hook__.after_file_success() {"
    "  log.error \"__hook__.after_file_success\""
    "  return 1"
    "}"
    ""
    "__hook__.after_file_fails() {"
    "  log.error \"__hook__.after_file_fails\""
    "  return 1"
    "}"
    ""
  )
}

subcmd.tests._extract_clean_lib_name_from_source() {
  basename "$1" | sed 's/^lib\.//' | sed 's/\.sh//'
}

subcmd.tests._extract_clean_lib_name_from_test() {
  basename "$1" | sed 's/^__test__\.lib\.//' | sed 's/\.sh//'
}

subcmd.tests._insert_variable_into_test_file() {
  local file="$1"
  local variable="$2"
  if [ ! -f "$file" ]; then
    log.error "file not found: $file"
    exit 1
  fi
  local line_number="$(grep -nE '^v[A-Z0-9_]{2,}=' "${file}" | tail -n 1 | cut -d: -f1)"
  local tmp_file="${file}.tmp.$(date +%s)"
  awk 'NR=='"$((line_number + 1))"'{print "'"${variable}="'\"\""}1' "${file}" >"${tmp_file}"
  cp -f "${tmp_file}" "${file}"
  rm -f "${tmp_file}"
}

subcmd.tests._blank_failing_test() {
  local missing_function="$1"
  echo "__test__.${missing_function}() {${n}  log.error \"${missing_function} not implemented yet\"${n}  return 1${n}}"
}

subcmd.tests._grep_lib_used_variables() {
  local lib_file="$1"
  if [ ! -f "$lib_file" ]; then
    log.error "file not found: $lib_file"
    exit 1
  fi
  grep -Eo 'v[A-Z0-9_]{2,}' "$lib_file" | sort -u
}

subcmd.tests._grep_lib_defined_variables() {
  local file="$1"
  if [ ! -f "$file" ]; then
    log.error "file not found: $file"
    exit 1
  fi
  grep -Eo 'v[A-Z0-9_]{2,}=' "${file}" | cut -d= -f1 | sort -u
}

subcmd.tests._grep_lib_defined_functions() {
  local lib_file="$1"
  local lib_unit_name="$2"
  if [ ! -f "$lib_file" ]; then
    log.error "file not found: $lib_file"
    exit 1
  fi
  grep -Eo "$lib_unit_name\.[a-z_\.]{2,}\(\)" "$lib_file" | sort -u | sed 's/()//'
}

subcmd.tests._grep_test_defined_functions() {
  local lib_unit_name="$1"
  local lib_test_filepath="$2"
  if [ ! -f "$lib_test_filepath" ]; then
    log.error "file not found: $lib_test_filepath"
    exit 1
  fi
  grep -Eo "__test__\.${lib_unit_name}\.[a-z_\.]{2,}\(\)" "$lib_test_filepath" | sort -u | sed 's/()//' | sed 's/__test__\.//'
}

subcmd.tests.unit.create_lib_test() {
  local lib_unit_name="$1"
  local force="${2:-false}"
  local lib_file="lib.${lib_unit_name}.sh"
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
  local defined_functions="$(subcmd.tests._grep_lib_defined_functions "${lib_file}" "${lib_unit_name}")"
  local variables="$(subcmd.tests._grep_lib_used_variables "${lib_file}")"
  subcmd.tests._update_beginning_file_lines "${lib_file}"
  local lines=("${LIB_TEST_FILE_OPENING_LINES[@]}")
  local n=$'\n'
  for variable in $variables; do
    lines+=("$variable=\"\"")
  done
  for defined_function in $defined_functions; do
    lines+=("")
    lines+=("$(subcmd.tests._blank_failing_test "${defined_function}")")
  done
  for line in "${lines[@]}"; do
    echo "$line" >>"${target_test_file_path}"
  done
}

subcmd.tests.unit.tests_add_missing_function_coverage() {
  local lib_unit_name="$1"
  local lib_file="lib.${lib_unit_name}.sh"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: $1"
    exit 1
  fi
  local test_dir="__tests__"
  local target_test_file="__test__.${lib_file}"
  local target_test_file_path="${test_dir}/${target_test_file}"
  if [ ! -f "${target_test_file_path}" ]; then
    subcmd.tests.unit.create_lib_test "${lib_unit_name}"
    return
  fi
  local defined_functions="$(subcmd.tests._grep_lib_defined_functions "${lib_file}" "${lib_unit_name}")"
  local test_functions="$(subcmd.tests._grep_test_defined_functions "${lib_unit_name}" "${target_test_file_path}")"
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
    lines+=("$(subcmd.tests._blank_failing_test "${missing_function}")")
  done
  for line in "${lines[@]}"; do
    echo "$line" >>"${target_test_file_path}"
  done
}

subcmd.tests.unit.get_undefined_test_variables() {
  local lib_unit_name="$1"
  local lib_file="lib.${lib_unit_name}.sh"
  local test_lib_file="__tests__/__test__.${lib_file}"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: $1"
    exit 1
  fi
  if [ ! -f "${test_lib_file}" ]; then
    return
  fi
  local defined_test_variables="$(subcmd.tests._grep_lib_defined_variables "${test_lib_file}")"
  local used_lib_variables="$(subcmd.tests._grep_lib_used_variables "${lib_file}")"
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

subcmd.tests.step.verify_source_existence() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find '__tests__' -maxdepth 1 -type f -name '__test__.lib.*' -print0)
  local missing_source_files=()
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_test "${lib_file}")"
    if [ ! -f "lib.${lib_unit_name}.sh" ]; then
      missing_source_files+=("lib.${lib_unit_name}.sh")
    fi
  done
  if [ ${#missing_source_files[@]} -gt 0 ]; then
    log.error "missing source files: ${missing_source_files[*]}"
    exit 1
  fi
}

subcmd.tests.step.verify_function_coverage() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'lib.*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    local target_test_file_path="__tests__/__test__.lib.${lib_unit_name}.sh"
    local defined_lib_functions="$(subcmd.tests._grep_lib_defined_functions "${lib_file}" "${lib_unit_name}")"
    local defined_test_functions="$(subcmd.tests._grep_test_defined_functions "${lib_unit_name}" "${target_test_file_path}")"
    for defined_lib_function in $defined_lib_functions; do
      if ! echo "$defined_test_functions" | grep -q "^${defined_lib_function}$"; then
        log.error "defined lib function: ${defined_lib_function} is not covered in ${lib_unit_name} test file"
        exit 1
      fi
    done
    for defined_test_function in $defined_test_functions; do
      if ! echo "$defined_lib_functions" | grep -q "^${defined_test_function}$"; then
        log.error "defined test function: ${defined_test_function} does not cover an existing function in the ${lib_unit_name} file"
        exit 1
      fi
    done
  done
}

subcmd.tests.step.verify_variables() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'lib.*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    local target_test_file_path="__tests__/__test__.lib.${lib_unit_name}.sh"
    local used_variables_in_lib="$(subcmd.tests._grep_lib_used_variables "${lib_file}")"
    local defined_variables_in_test="$(subcmd.tests._grep_lib_defined_variables "${target_test_file_path}")"
    for used_variable_in_lib in $used_variables_in_lib; do
      if ! echo "$defined_variables_in_test" | grep -q "^${used_variable_in_lib}$"; then
        log.error "used variable in lib: ${used_variable_in_lib} was not defined in ${lib_unit_name} test file"
        exit 1
      fi
    done
    for defined_variable_in_test in $defined_variables_in_test; do
      if ! echo "$used_variables_in_lib" | grep -q "^${defined_variable_in_test}$"; then
        log.error "defined variable in test: ${used_variable_in_lib} is not used in ${lib_unit_name} file"
        exit 1
      fi
    done
  done
}

subcmd.tests.step.cover_functions() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'lib.*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    subcmd.tests.unit.tests_add_missing_function_coverage "${lib_unit_name}"
  done
}

subcmd.tests.step.cover_variables() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'lib.*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    local undefined_variables="$(subcmd.tests.unit.get_undefined_test_variables "${lib_unit_name}")"
    if [ -n "$undefined_variables" ]; then
      for undefined_variable in $undefined_variables; do
        subcmd.tests._insert_variable_into_test_file "__tests__/__test__.lib.${lib_unit_name}.sh" "${undefined_variable}"
      done
    fi
  done
}

subcmd.tests.dangerously_recreate() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'lib.*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    subcmd.tests.unit.create_lib_test "${lib_unit_name}" true
  done
}

subcmd.tests.init() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -maxdepth 1 -type f -name 'lib.*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    subcmd.tests.unit.create_lib_test "${lib_unit_name}"
  done
}

subcmd.tests.cover() {
  subcmd.tests.step.cover_functions
  subcmd.tests.step.cover_variables
}

subcmd.tests.verify() {
  subcmd.tests.step.verify_function_coverage
  subcmd.tests.step.verify_variables
  subcmd.tests.step.verify_source_existence
}

#
# TODO: refactor the log.stripped logic so we don't need to set/unset so many times
#
subcmd.tests.unit() {
  local lib_unit_name="$1"
  shift
  local lib_file="lib.${lib_unit_name}.sh"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: ${lib_file}"
    exit 1
  fi
  local lib_test_file="__tests__/__test__.lib.${lib_unit_name}.sh"
  if [ ! -f "${lib_test_file}" ]; then
    log.error "test file not found: $1"
    exit 1
  fi
  local functions_to_test
  local defined_functions="$(subcmd.tests._grep_test_defined_functions "${lib_unit_name}" "${lib_test_file}")"
  local supplied_functions=("$@")
  if [ ${#supplied_functions[@]} -gt 0 ]; then
    for supplied_function in "${supplied_functions[@]}"; do
      if ! echo "$defined_functions" | grep -q "^${supplied_function}$"; then
        log.error "function not found: ${supplied_function}"
        exit 1
      fi
    done
    functions_to_test="${supplied_functions[*]}"
  else
    functions_to_test="${defined_functions[*]}"
  fi
  chmod +x "$lib_test_file"
  # shellcheck disable=SC1090
  . "$lib_test_file"
  if __hook__.before_file; then
    local something_failed=false
    for function_to_test in ${functions_to_test}; do
      local test_function="__test__.${function_to_test}"
      if ! type "${test_function}" &>/dev/null; then
        LIB_FAILED+=("${function_to_test}")
        continue
      fi
      if ! __hook__.before_fn "${function_to_test}"; then
        LIB_FAILED+=("${function_to_test}")
        continue
      fi
      if ! "${test_function}"; then
        something_failed=true
        __hook__.after_fn_fails "${function_to_test}" || true
        LIB_FAILED+=("${function_to_test}")
      else
        __hook__.after_fn_success "${function_to_test}" || true
        LIB_PASSED+=("${function_to_test}")
      fi
      __hook__.after_fn "${function_to_test}" || true
    done
    if [ "${something_failed}" == "true" ]; then
      __hook__.after_file_fails || true
      LIB_FILES_FAILED+=("${lib_unit_name}")
    else
      __hook__.after_file_success || true
    fi
    __hook__.after_file || true
  else
    LIB_FILES_FAILED+=("${lib_unit_name}")
  fi
}

cmd.tests() {
  if [ "$vSTATIC_RUNNING_IN_GIT_REPO" != "true" ]; then
    log.error "this command can only be run from within a git repo."
    exit 1
  fi
  if [ "$vSTATIC_HOST" != "local" ]; then
    log.error "this command must be run from your local machine. Exiting."
    exit 1
  fi

  local lib_files=()
  if [ -z "${vCLI_OPT_LIB}" ]; then
    while IFS= read -r -d $'\0' file; do
      lib_files+=("$file")
    done < <(find . -maxdepth 1 -type f -name 'lib.*.sh' -print0)
  else
    local lib_unit_name="${vCLI_OPT_LIB}"
    local lib_test_file="$PWD/__tests__/__test__.lib.${lib_unit_name}.sh"
    if [ ! -f "${lib_test_file}" ]; then
      log.error "test file not found: ${lib_test_file}"
      exit 1
    fi
    lib_files+=("$PWD/lib.${lib_unit_name}.sh")
  fi
  subcmd.tests.init
  subcmd.tests.cover
  subcmd.tests.verify
  for lib_file in "${lib_files[@]}"; do
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    subcmd.tests.unit "${lib_unit_name}" "${vCLI_OPT_FN}"
  done
  if [ ${#LIB_FILES_FAILED[@]} -gt 0 ]; then
    for failed in "${LIB_FILES_FAILED[@]}"; do
      log.error "failing file: ${failed}"
    done
  fi
  if [ ${#LIB_FAILED[@]} -gt 0 ]; then
    for failed in "${LIB_FAILED[@]}"; do
      log.error "failing function: ${failed}"
    done
  fi
}

cmd.tests
