#!/bin/bash
set -e

ZSH="${ZSH:-$HOME/.oh-my-zsh}"

install_omz() {
  echo "[OMZ] Installing for user $USER..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

update_omz() {
  echo "[OMZ] Updating for user $USER..."
  "$ZSH/tools/upgrade.sh" || true
}

# Check for oh-my-zsh install
if [ -d "$ZSH" ]; then
  update_omz
else
  install_omz
fi
