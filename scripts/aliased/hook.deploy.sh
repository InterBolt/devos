#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../lib/defaults.sh
source ../lib/defaults.sh
# shellcheck source=../lib/runtime.sh
source scripts/lib/runtime.sh

runtime_fn_arg_info "h-deploy" "Deploys a built repository from an app directory to a caprover server via a tar file."
runtime_fn_arg_accept 'r:' 'app-dir' 'The output folder for a build that also contains any app specific env files.'
runtime_fn_arg_accept 'd:' 'dist-dir' 'The dir of distribution files generated via the build script'
runtime_fn_arg_parse "$@"

app_dir="$(runtime_fn_get_arg 'app-dir')"
dist_dir="$(runtime_fn_get_arg 'dist-dir')"

if [[ ! $app_dir == $runtime_apps_dir* ]]; then
  log.throw "--app-dir must be a subdirectory of $runtime_apps_dir"
fi
if [[ ! $dist_dir == $runtime_github_dir* ]]; then
  log.throw "--dist-dir must be a subdirectory of $runtime_github_dir"
fi

timestamp=$(date +%s%3N)
deploy_tar=deploy.$timestamp.tar

if [ ! -f "$app_dir"/.env ]; then
  log.throw "Missing .env file in $app_dir"
fi
if [ -f "$dist_dir"/.env ]; then
  log.throw ".env file already exists in $dist_dir. Refactor your build process to not include .env in the dist directory."
fi

cp "$app_dir"/.env "$dist_dir"/.env
tar -cvf "$deploy_tar" "$dist_dir"/.
mv "$deploy_tar" "$app_dir/$deploy_tar"

app_name=$(basename "$app_dir")

caprover deploy -p "$secret_caprover_password" -n $runtime_caprover_name -a "${app_name//./-}" -t "$app_dir/$deploy_tar"
