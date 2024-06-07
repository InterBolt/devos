#!/usr/bin/env bash

profile_plugins__dir="${HOME}/.solos/plugins"

plugins=()
while IFS= read -r plugin; do
  plugins+=("${plugin}")
done < <(ls -1 "${profile_plugins__dir}")
if [[ ${#plugins[@]} -eq 0 ]]; then
  echo "No plugins installed."
fi

echo "plugins - ${plugins[@]}"
