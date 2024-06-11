#!/bin/bash

fn() {
  local assets=()
  local asset_args_count=0
  local args=("${@}")
  local seperator_exists=false
  for arg in "${args[@]}"; do
    if [[ ${arg} = "--" ]]; then
      seperator_exists=true
    fi
  done
  if [[ ${seperator_exists} = false ]]; then
    echo "Invalid argument list. No seperator '--' found in the firejail function." >&2
    return 1
  fi
  while [[ ${1} != "--" ]]; do
    asset_args_count=$((asset_args_count + 1))
    local divider_arg_is_next=false
    if [[ ${2} = "--" ]]; then
      divider_arg_is_next=true
    fi
    if [[ $((asset_args_count % 2)) -eq 1 ]] && [[ ${divider_arg_is_next} = true ]]; then
      echo "Invalid argument list. An odd number of FS arguments supplied to the firejail function." >&2
      return 1
    fi
    assets+=("${1}")
    shift
  done
  local asset_count=$((asset_count / 2))

}

fn "asset_name1" "asset_path1" "asset_name2" "asset_path2" -- "executable_path1" "executable_path2"
echo "EXPECT RETURN_CODE: 0 - FOUND: $?"
fn "asset_name1" "asset_path1" "asset_name2" -- "executable_path1" "executable_path2"
echo "EXPECT RETURN_CODE: 1 - FOUND: $?"
fn -- "executable_path1" "executable_path2"
echo "EXPECT RETURN_CODE: 0 - FOUND: $?"
fn "asset_name1" "asset_path1" "asset_name2" "asset_path2" "asset_name3" "asset_path3" -- "executable_path1" "executable_path2"
echo "EXPECT RETURN_CODE: 0 - FOUND: $?"
fn "asset_name1" "asset_path1" "asset_name2" "asset_path2" "asset_name3" "asset_path3"
echo "EXPECT RETURN_CODE: 1 - FOUND: $?"
