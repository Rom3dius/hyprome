#!/bin/bash
set -euo pipefail

# ─── Config ─────────────────────────────────────────────────────────
ZSH="${ZSH:-$HOME/.oh-my-zsh}"
DOTS_REPO="https://github.com/Rom3dius/hyprome-dev-dots"
YADM_DIR="$HOME/.local/share/yadm/repo.git"
BOOTSTRAP="$HOME/.config/yadm/bootstrap"

# ─── Functions ──────────────────────────────────────────────────────

install_omz() {
  echo "[OMZ] Installing oh-my-zsh for user $USER..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

update_omz() {
  echo "[OMZ] Updating oh-my-zsh for user $USER..."
  "$ZSH/tools/upgrade.sh" || true
}

reset_yadm_repo() {
  echo "[YADM] Resetting dotfiles from $DOTS_REPO"

  # Remove previous YADM repo if it exists
  if [ -d "$YADM_DIR" ]; then
    echo "[YADM] Removing old repo at $YADM_DIR"
    rm -rf "$YADM_DIR"
  fi

  # Clone fresh
  yadm clone -f "$DOTS_REPO"

  # Checkout and overwrite existing files
  echo "[YADM] Force-checking out dotfiles to $HOME"
  yadm reset --hard
  yadm checkout "$HOME"

  echo "[YADM] Done syncing dotfiles"

  # Run YADM bootstrap if it exists
  if [ -x "$BOOTSTRAP" ]; then
    echo "[YADM] Running bootstrap script..."
    "$BOOTSTRAP"
  else
    echo "[YADM] No executable bootstrap script found at $BOOTSTRAP"
  fi
}

# ─── Main ───────────────────────────────────────────────────────────

echo "[dots] Installing/resetting dotfiles for $USER..."

# Ensure oh-my-zsh is up to date
if [ -d "$ZSH" ]; then
  update_omz
else
  install_omz
fi

# Pull and sync dotfiles via yadm
reset_yadm_repo

echo "[dots] Dotfiles setup!"
