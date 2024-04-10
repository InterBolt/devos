#!/usr/bin/env bash

if [ "$(basename "$(pwd)")" != "bin" ]; then
  echo "error: must be run from the bin folder"
  exit 1
fi

# shellcheck source=solos.sh
. "__shared__/static.sh"
# shellcheck source=solos.utils.sh
. "__shared__/static.sh"
# shellcheck source=__shared__/static.sh
. "__shared__/static.sh"

LIB_CACHE_DIR=".cache"

cache.del() {
  mkdir -p "$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR"
  local tmp_filepath="$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR/$1"
  rm -f "$tmp_filepath"
}
cache.clear() {
  mkdir -p "$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR"
  # shellcheck disable=SC2115
  rm -rf "$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR"
}
cache.get() {
  mkdir -p "$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR"
  local tmp_filepath="$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR/$1"
  if [ -f "$tmp_filepath" ]; then
    cat "$tmp_filepath"
  else
    echo ""
  fi
}
cache.set() {
  mkdir -p "$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR"
  local tmp_filepath="$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR/$1"
  if [ ! -f "$tmp_filepath" ]; then
    touch "$tmp_filepath"
  fi
  echo "$2" >"$tmp_filepath"
}
cache.prompt() {
  mkdir -p "$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR"
  local input
  input="$(cache.get "$1")"
  if [ -z "$input" ]; then
    echo -n "Enter the $1:"
    read -r input
    if [ -z "$input" ]; then
      log.error "the $1 cannot be empty. Exiting."
      exit 1
    fi
    cache.set "$1" "$input"
  fi
  cache.get "$1"
}
cache.overwrite_on_empty() {
  mkdir -p "$vSTATIC_MY_CONFIG_ROOT/$LIB_CACHE_DIR"
  local cached_val
  cached_val="$(cache.get "$1")"
  local next_val="$2"
  if [ -z "$cached_val" ]; then
    cache.set "$1" "$next_val"
  fi
  cache.get "$1"
}