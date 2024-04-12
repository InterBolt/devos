#!/usr/bin/env bash
# shellcheck disable=SC2103,SC2164

# shellcheck source=../shared/solos_base.sh
. shared/solos_base.sh

LIB_TEST_FILE_OPENING_LINES=()
LIB_FILES_FAILED=()
LIB_FAILED=()
LIB_PASSED=()

subcmd.tests._normalize_function_name() {
  local name="$1"
  if [ -z "${name}" ]; then
    log.error "function name is empty"
    exit 1
  fi
  if [[ "${name}" == *".sh" ]]; then
    log.error "function name cannot end in .sh"
    exit 1
  fi
  if [[ "${name}" == "__test__."* ]]; then
    name="${name/__test__./}"
  fi
  if [[ "${name}" != "lib."* ]]; then
    name="lib.${name}"
  fi
  echo "${name}"
}

subcmd.tests._update_beginning_file_lines() {
  local lib_file="$1"
  LIB_TEST_FILE_OPENING_LINES=(
    "#!/usr/bin/env bash"
    ""
    "set -o errexit"
    "set -o pipefail"
    "set -o errtrace"
    ""
    "cd \"\$(git rev-parse --show-toplevel 2>/dev/null)/bin\""
    ""
    " # shellcheck source=../${lib_file}"
    ". \"lib/${lib_file}\""
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
  basename "$1" | sed 's/\.sh//'
}

subcmd.tests._extract_clean_lib_name_from_test() {
  basename "$1" | sed 's/^__test__\.//' | sed 's/\.sh//'
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
  local lib_unit_name="$1"
  if [ ! -f "${lib_unit_name}.sh" ]; then
    log.error "file not found: $lib_file"
    exit 1
  fi
  grep "^lib.${lib_unit_name}[A-Z0-9_]*\(\)" "${lib_unit_name}.sh" | sort -u | sed 's/()//' | cut -f 1 -d ' '
}

subcmd.tests._grep_test_defined_functions() {
  local lib_unit_name="$1"
  if [ ! -f "${lib_unit_name}.sh" ]; then
    log.error "file not found: ${lib_unit_name}.sh"
    exit 1
  fi
  grep "^__test__.${lib_unit_name}[A-Z0-9_]*\(\)" "tests/__test__.${lib_unit_name}.sh" | sort -u | sed 's/()//' | sed 's/__test__\./lib\./' | cut -f 1 -d ' '
}

subcmd.tests.unit.create_lib_test() {
  local lib_unit_name="$1"
  local force="${2:-false}"
  local lib_file="${lib_unit_name}.sh"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: ${lib_file} $PWD"
    exit 1
  fi
  local test_dir="tests"
  local target_test_file="__test__.${lib_file}"
  local target_test_file_path="${test_dir}/${target_test_file}"
  if [ -f "${target_test_file_path}" ] && [ "${force}" == "false" ]; then
    return
  fi
  if [ "$force" == "true" ] && [ -f "${target_test_file_path}" ]; then
    mv "${target_test_file_path}" "${test_dir}/.archive.$(date +%s).${target_test_file}"
    log.warn "archived previous test file at: .archive.${target_test_file_path}"
  fi
  local defined_functions="$(subcmd.tests._grep_lib_defined_functions "${lib_unit_name}")"
  local variables="$(subcmd.tests._grep_lib_used_variables "${lib_file}")"
  subcmd.tests._update_beginning_file_lines "${lib_file}"
  local lines=(" ${LIB_TEST_FILE_OPENING_LINES[@]} ")
  local n=$'\n'
  for variable in $variables; do
    lines+=("$variable=\"\"")
  done
  lines+=("")
  for defined_function in $defined_functions; do
    lines+=("$(subcmd.tests._blank_failing_test "${defined_function/lib\./}")")
  done
  for line in "${lines[@]}"; do
    echo "$line" >>"${target_test_file_path}"
  done
}

subcmd.tests.unit.tests_add_missing_function_coverage() {
  local lib_unit_name="$1"
  local lib_file="${lib_unit_name}.sh"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: $1"
    exit 1
  fi
  local test_dir="tests"
  local target_test_file="__test__.${lib_file}"
  local target_test_file_path="${test_dir}/${target_test_file}"
  if [ ! -f "${target_test_file_path}" ]; then
    subcmd.tests.unit.create_lib_test "${lib_unit_name}"
    return
  fi
  local defined_functions="$(subcmd.tests._grep_lib_defined_functions "${lib_unit_name}")"
  local test_functions="$(subcmd.tests._grep_test_defined_functions "${lib_unit_name}")"
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
    lines+=("$(subcmd.tests._blank_failing_test "${missing_function/lib\.//}")")
  done
  for line in "${lines[@]}"; do
    echo "$line" >>"${target_test_file_path}"
  done
}

subcmd.tests.unit.get_undefined_test_variables() {
  local lib_unit_name="$1"
  local lib_file="${lib_unit_name}.sh"
  local test_lib_file="tests/__test__.${lib_file}"
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
  done < <(find 'tests' -maxdepth 1 -type f -name '__test__.*' -print0)
  local missing_source_files=()
  for lib_file in "${lib_files[@]}"; do
    lib_file="$(basename "$lib_file")"
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_test "${lib_file}")"
    if [ ! -f "${lib_unit_name}.sh" ]; then
      missing_source_files+=("${lib_unit_name}.sh")
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
  done < <(find . -not \( -path "*/__*__.sh" -prune \) -maxdepth 1 -type f -name '*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    lib_file="$(basename "$lib_file")"
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    local target_test_file_path="tests/__test__.${lib_unit_name}.sh"
    local defined_lib_functions="$(subcmd.tests._grep_lib_defined_functions "${lib_unit_name}")"
    local defined_test_functions="$(subcmd.tests._grep_test_defined_functions "${lib_unit_name}")"
    for defined_lib_function in $defined_lib_functions; do
      if ! echo "$defined_test_functions" | grep -q "^${defined_lib_function}$"; then
        log.error "${defined_lib_function} is not covered in ${lib_unit_name} test file"
        exit 1
      fi
    done
    for defined_test_function in $defined_test_functions; do
      if ! echo "$defined_lib_functions" | grep -q "^${defined_test_function}$"; then
        log.error "${defined_test_function} does not cover an existing function in the ${lib_unit_name} file"
        exit 1
      fi
    done
  done
}

subcmd.tests.step.verify_variables() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -not \( -path "*/__*__.sh" -prune \) -maxdepth 1 -type f -name '*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    lib_file="$(basename "$lib_file")"
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    local target_test_file_path="tests/__test__.${lib_unit_name}.sh"
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
  done < <(find . -not \( -path "*/__*__.sh" -prune \) -maxdepth 1 -type f -name '*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    lib_file="$(basename "$lib_file")"
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    subcmd.tests.unit.tests_add_missing_function_coverage "${lib_unit_name}"
  done
}

subcmd.tests.step.cover_variables() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -not \( -path "*/__*__.sh" -prune \) -maxdepth 1 -type f -name '*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    lib_file="$(basename "$lib_file")"
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    local undefined_variables="$(subcmd.tests.unit.get_undefined_test_variables "${lib_unit_name}")"
    if [ -n "$undefined_variables" ]; then
      for undefined_variable in $undefined_variables; do
        subcmd.tests._insert_variable_into_test_file "tests/__test__.${lib_unit_name}.sh" "${undefined_variable}"
      done
    fi
  done
}

subcmd.tests.dangerously_recreate() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -not \( -path "*/__*__.sh" -prune \) -maxdepth 1 -type f -name '*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    lib_file="$(basename "$lib_file")"
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    subcmd.tests.unit.create_lib_test "${lib_unit_name}" true
  done
}

subcmd.tests.init() {
  local lib_files=()
  while IFS= read -r -d $'\0' file; do
    lib_files+=("$file")
  done < <(find . -not \( -path "*/__*__.sh" -prune \) -maxdepth 1 -type f -name '*.sh' -print0)
  for lib_file in "${lib_files[@]}"; do
    lib_file="$(basename "$lib_file")"
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
  local lib_file="${lib_unit_name}.sh"
  if [ ! -f "${lib_file}" ]; then
    log.error "file not found: ${lib_file}"
    exit 1
  fi
  local lib_test_file="tests/__test__.${lib_unit_name}.sh"
  if [ ! -f "${lib_test_file}" ]; then
    log.error "test file not found: $1"
    exit 1
  fi
  local supplied_functions=()
  local functions_found_in_test="$(subcmd.tests._grep_test_defined_functions "${lib_unit_name}")"
  for arg in "${@:2}"; do
    if [ -z "${arg}" ]; then
      continue
    fi
    if ! echo "$functions_found_in_test" | grep -q "^${arg}$"; then
      log.error "function not found: ${arg}"
      exit 1
    else
      supplied_functions+=("$(subcmd.tests._normalize_function_name "$arg")")
    fi
  done
  if [ ${#supplied_functions[@]} -eq 0 ]; then
    for function_found_in_test in $functions_found_in_test; do
      supplied_functions+=("$function_found_in_test")
    done
  fi
  chmod +x "$lib_test_file"
  # shellcheck disable=SC1090
  . "$lib_test_file"
  if __hook__.before_file; then
    local something_failed=false
    for supplied_function in "${supplied_functions[@]}"; do
      local function_name_without_prefix="${supplied_function/lib./}"
      local test_function="__test__.${function_name_without_prefix}"
      if ! __hook__.before_fn "${supplied_function}"; then
        LIB_FAILED+=("$function_name_without_prefix")
        continue
      fi
      if ! "${test_function}"; then
        something_failed=true
        __hook__.after_fn_fails "${supplied_function}" || true
        LIB_FAILED+=("$function_name_without_prefix")
      else
        __hook__.after_fn_success "$function_name_without_prefix" || true
        LIB_PASSED+=("$function_name_without_prefix")
      fi
      __hook__.after_fn "$function_name_without_prefix" || true
    done
    if [ "${something_failed}" == "true" ]; then
      __hook__.after_file_fails || true
      LIB_FILES_FAILED+=("$lib_unit_name")
    else
      __hook__.after_file_success || true
    fi
    __hook__.after_file || true
  else
    LIB_FILES_FAILED+=("$lib_unit_name")
  fi
}

cmd.tests() {
  #
  # Make sure we're in a git repo and that we're either in our docker dev container
  # or on a local machine. We can't run tests in a remote environment.
  #
  if [ "${vSTATIC_RUNNING_IN_GIT_REPO}" != "true" ]; then
    log.error "this command can only be run from within a git repo."
    exit 1
  fi
  if [ "${vSTATIC_HOST}" == "remote" ]; then
    log.error "this command cannot be run in a remote environment."
    exit 1
  fi
  if [ ! -d "lib" ]; then
    log.error "lib directory not found. Exiting."
    exit 1
  fi
  local entry_dir="$PWD"
  cd "lib" || exit 1
  #
  # Normalize the function name to the format: lib.<lib_name>.<function_name>.
  # Then, make sure the user is allowed to pass only a function if they want and
  # we'll infer the library name from the function name.
  #
  local lib_to_test="${vCLI_OPT_LIB}"
  local fn_to_test="${vCLI_OPT_FN}"
  local lib_dir="$PWD"
  local lib_files=()
  if [ -z "${lib_to_test}" ] && [ -z "${fn_to_test}" ]; then
    while IFS= read -r -d $'\0' file; do
      lib_files+=("$file")
    done < <(find . -not \( -path "*/__*__.sh" -prune \) -maxdepth 1 -type f -name '*.sh' -print0)
  else
    if [ -n "${fn_to_test}" ]; then
      fn_to_test="$(subcmd.tests._normalize_function_name "${fn_to_test}")"
      local inferred_lib_to_test="$(echo "${fn_to_test}" | cut -d. -f2)"
      if [ -n "${lib_to_test}" ]; then
        if [ "${lib_to_test}" != "${inferred_lib_to_test}" ]; then
          log.error "the --lib and --fn flags specify different libraries. Exiting."
          exit 1
        fi
      else
        lib_to_test="${inferred_lib_to_test}"
      fi
    fi
    local lib_unit_name="${lib_to_test}"
    local lib_test_file="$PWD/tests/__test__.${lib_unit_name}.sh"
    if [ ! -f "${lib_test_file}" ]; then
      log.error "test file not found: ${lib_test_file}"
      exit 1
    fi
    lib_files+=("$lib_dir/${lib_unit_name}.sh")
  fi
  #
  # Init tests that don't exist, make sure all functions are covered from the source libs,
  # and verify some basic things like variable usage and function coverage.
  #
  local no_errors=true
  subcmd.tests.init
  subcmd.tests.cover
  subcmd.tests.verify
  #
  # Run each test associated with a lib.
  # If we provided a --fn flag, only run that function.
  #
  for lib_file in "${lib_files[@]}"; do
    lib_file="$(basename "$lib_file")"
    local lib_unit_name="$(subcmd.tests._extract_clean_lib_name_from_source "$lib_file")"
    subcmd.tests.unit "${lib_unit_name}" "${fn_to_test}"
    cd "$lib_dir" || exit 1
  done
  #
  # Collect the status of the ran tests and output the results.
  #
  if [ ${#LIB_FILES_FAILED[@]} -gt 0 ]; then
    no_errors=false
  fi
  if [ ${#LIB_FAILED[@]} -gt 0 ]; then
    for failed in "${LIB_FAILED[@]}"; do
      log.error "failed: ${failed}"
      no_errors=false
    done
  fi
  if [ ${#LIB_PASSED[@]} -gt 0 ]; then
    for passed in "${LIB_PASSED[@]}"; do
      log.info "passed: ${passed}"
    done
  fi
  if [ "${no_errors}" == "true" ]; then
    log.info "SUCCESS: all tests passed"
  else
    log.error "FAILED: some tests failed"
  fi
  cd "$entry_dir" || exit 1
}