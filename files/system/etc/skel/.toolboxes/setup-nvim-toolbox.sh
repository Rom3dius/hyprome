#!/bin/bash

set -e

TOOLBOX_NAME="nvim"
DOTFILES_REPO="https://github.com/Rom3dius/lazyvim-romedius"

# Create toolbox if it doesn't exist
if ! toolbox list | grep -q "^$TOOLBOX_NAME"; then
  toolbox create -y --container "$TOOLBOX_NAME"
else
  exit 0
fi

# Install packages inside the toolbox
toolbox run --container "$TOOLBOX_NAME" bash -c "
    sudo dnf install -y \
        neovim ripgrep fzf python3 python3-pip python3-neovim lazygit \
        git curl unzip make rclone zsh

    # Clone dotfiles if not already present
    DOTFILES_DIR=\"\$HOME/.config/nvim\"
    if [ ! -d \"\$DOTFILES_DIR\" ]; then
        git clone $DOTFILES_REPO \"\$DOTFILES_DIR\"
        cd \"\$DOTFILES_DIR\" && make setup 
    fi
"
