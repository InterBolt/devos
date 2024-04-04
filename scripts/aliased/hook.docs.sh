#!/usr/bin/env bash
# [START OF CONTEXT FOR COPILOT]
# - All exported variables from runtime.sh:
#   - exported variable: $runtime_expectations: The list of variables that are expected to be set at runtime.
#   - exported variable: $runtime_db_connection_manager: The connection string for the manager database.
#   - exported variable: $runtime_host: The host that a script is running on. It is initialized when dev-os is installed. It is set to 'remote' when the script is running on the remote server and 'local' when the script is running on the local machine.
#   - exported variable: $runtime_caprover: The caprover password.
#   - exported variable: $runtime_postgres: The postgres password.
#   - exported variable: $secret_openai: The openai api key.
#   - exported variable: $secret_gh_token: A github api token.
#   - exported variable: $runtime_devos: The private SSH key for the dev-os servers.
#   - exported variable: $runtime_devos_pub: The public SSH key for the dev-os servers.
#   - exported variable: $secret_vultr_s3_host: The vultr s3 host.
#   - exported variable: $secret_vultr_s3_access: The vultr s3 access key.
#   - exported variable: $secret_vultr_s3_secret: The vultr s3 secret.
#   - exported variable: $secret_vultr_s3_bucket: The vultr s3 bucket name.
#   - exported variable: $runtime_repo_dir: The DevOS repo directory.
#   - exported variable: $runtime_secrets_dir: The directory where secrets are stored.
#   - exported variable: $runtime_ssh_key_name: The name of the SSH key used between environments.
#   - exported variable: $runtime_outer_working_dir: The directory where apps and source code lives.
#   - exported variable: $runtime_outer_apps_dir: The directory where apps live.
#   - exported variable: $runtime_outer_github_dir: The directory where source code lives.
#   - exported variable: $runtime_caprover_root_domain: The root domain of the caprover server.
#   - exported variable: $runtime_caprover_name: The name of the caprover server.
#   - exported variable: $runtime_caprover_email: The email of the caprover server.
#   - exported variable: $runtime_node_version: The node version to use.
#   - exported variable: $runtime_outer_artifacts_dir: The directory where artifacts are stored.
#   - exported variable: $runtime_caprover_api_calls_dir: The directory where caprover api calls are stored.
#   - exported variable: $runtime_postgres_subdomain: The subdomain of the postgres server.
#   - exported variable: $runtime_postgres_db: The name of the postgres database.
#   - exported variable: $runtime_postgres_user: The name of the postgres user.
#   - exported variable: $runtime_postgres_port: The port of the postgres server.
#   - exported variable: $runtime_postgres_public_host: The public host of the postgres server.
#   - exported variable: $secret_remote_ip: The remote ip address of the production server.
#   - exported function: $runtime_fn_print_line: A function that prints a line the width of the user's terminal. Useful for displaying some forms of data.
# [END OF CONTEXT FOR COPILOT]

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
source ../../.env.sh
# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-docs" "Generates inline comments for copilot and README.md documentation."
runtime_fn_arg_parse "$@"

sed -i '/## Scripts/,$d' README.md
{
  echo "## Scripts"
  echo ""
  echo "The following aliased scripts are available in this repository:"
  echo ""
  for script in scripts/aliased/*.sh; do
    if [ ! -f "$script" ]; then
      break
    fi
    help_text="$($script --print-help)"
    # Escape any characters that don't work well in a markdown code block
    help_text="$(echo "${help_text}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    echo "\`\`\`"
    echo "$help_text"
    echo "\`\`\`"
    echo ""
  done
} >>README.md

n=$'\n'
runtime_docs_header="# - All exported variables from runtime.sh:"
doc_string="$runtime_docs_header$n"
for expected_runtime_variable in "${runtime_expectations[@]}"; do
  expected_runtime_variable_name="$(echo "$expected_runtime_variable" | cut -d "#" -f 1)"
  expected_runtime_variable_description="$(echo "$expected_runtime_variable" | cut -d "#" -f 2)"
  if [[ $expected_runtime_variable_name == "runtime_fn_"* ]]; then
    doc_string="$doc_string#   - exported function: \$$expected_runtime_variable_name: $expected_runtime_variable_description$n"
  else
    doc_string="$doc_string#   - exported variable: \$$expected_runtime_variable_name: $expected_runtime_variable_description$n"
  fi
done
for script in $(find $runtime_repo_dir -name "*.sh"); do
  if [ -n "$(echo "$script" | grep "installer")" ]; then
    continue
  fi
  if [ -n "$(grep "# EXTERNAL_LIB" "$script")" ]; then
    continue
  fi
  if [ "$(basename "$script")" '==' "runtime.sh" ]; then
    continue
  fi
  if [ -z "$(grep "source.*runtime.sh" "$script")" ]; then
    continue
  fi
  start_delimiter="START OF CONTEXT FOR COPILOT"
  end_delimiter="END OF CONTEXT FOR COPILOT"
  start_d_for_sed="\# \[$start_delimiter\]"
  end_d_for_sed="\# \[$end_delimiter\]"
  start_d_for_print="# [$start_delimiter]"
  end_d_for_print="# [$end_delimiter]"

  context_comment="$start_d_for_print$n$doc_string$end_d_for_print"
  sed -i "/$start_d_for_sed/,/$end_d_for_sed/d" "$script"
  sed -i '/^#\!\/.*$/d' "$script"
  new_script_contents="$context_comment$n$(cat "$script")"
  new_script_contents="#!/usr/bin/env bash$n$new_script_contents"
  echo "$new_script_contents" >"$script"
done

IFS=$OLD_IFS
