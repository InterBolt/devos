#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# shellcheck source=../../.env.sh
. ../../.env.sh
# shellcheck source=./.runtime/runtime.sh
. ./.runtime/runtime.sh

fn_arg_info "i-apps" "Install the apps listed in apps.txt on the remote server."
fn_arg_parse "$@"

n=$'\n'

prepare_dns() {
  domain=$1
  cname=$2
  zone=$3
  # TODO: implement DNS setup logic for new apps
  log.info "TODO: implement DNS setup logic for new apps"
}

setup_app() {
  domain=$1
  mkdir -p "$runtime_apps_dir/$domain"
}

# this ensures that the loop below includes the last app section
if [ "$(tail -c 2 "$runtime_config_dir/apps.txt")" != "" ]; then
  echo "" >>"$runtime_config_dir/apps.txt"
  echo "" >>"$runtime_config_dir/apps.txt"
fi

section_starts_index=0
for section in $(awk '/^$/{print NR}' "$runtime_config_dir/apps.txt"); do
  section_ends_index=$(echo "$section" | awk '{print $1}')
  section_contents=$(awk "NR >= $section_starts_index && NR < $section_ends_index" "$runtime_config_dir/apps.txt")
  section_contents_singleline=$(echo "$section_contents" | awk '{$1=$1};1')
  section_starts_index=$section_ends_index
  domain="--"
  repo="--"
  cname="--"
  zone="--"
  for word in $section_contents_singleline; do
    key=$(echo "$word" | awk -F= '{print $1}')
    value=$(echo "$word" | awk -F= '{print $2}')
    if [ "$key" '==' "domain" ]; then
      domain=$value
    fi
    if [ "$key" '==' "repo" ]; then
      repo=$value
    fi
    if [ "$key" '==' "cname" ]; then
      cname=$value
    fi
    if [ "$key" '==' "zone" ]; then
      zone=$value
    fi
  done
  if [ "$domain" '==' "" ]; then
    log.throw "[$repo] - domain missing. Fix app.txt:$n$(echo "$section_contents_singleline" | sed 's/ /\n/g')"
  fi
  if [ "$repo" '==' "" ]; then
    log.throw "[$domain] - repo missing. Fix app.txt:$n$(echo "$section_contents_singleline" | sed 's/ /\n/g')"
  fi
  if [ "$cname" '==' "" ]; then
    log.throw "[$domain] - cname missing. Fix app.txt:$n$(echo "$section_contents_singleline" | sed 's/ /\n/g')"
  fi
  if [ "$zone" '==' "" ]; then
    log.throw "[$domain] - zone missing. Fix app.txt:$n$(echo "$section_contents_singleline" | sed 's/ /\n/g')"
  fi
  setup_app "$domain"
  prepare_dns "$domain" "$cname" "$zone"
done
