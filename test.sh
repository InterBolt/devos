viSOLOS_DIR="${HOME}/.solos"
viSOLOS_VSCODE_BASHRC_FILE="${viSOLOS_DIR}/vscode.bashrc"

{
  echo "source \"\${HOME}/.solos/src/bin/vscode.bashrc\""
  echo ""
  echo "# This file is sourced inside of the docker container when the command is run."
  echo "# Add your customizations:"
} >"${viSOLOS_VSCODE_BASHRC_FILE}"
