#!/bin/bash
set -euo pipefail

# ─── Config ─────────────────────────────────────────────────────────
HYPRVOICE_VERSION="v1.0.2"
HYPRVOICE_BIN="$HOME/.local/bin/hyprvoice"
HYPRVOICE_STATE="$HOME/.local/share/hyprome-voice"
VERSION_FILE="$HYPRVOICE_STATE/version"
RELEASE_URL="https://github.com/LeonardoTrapani/hyprvoice/releases/download"
DEFAULT_MODEL="small.en"

# ─── Functions ──────────────────────────────────────────────────────

log() { echo "[hyprvoice] $*"; }

installed_version() {
  if [ -f "$VERSION_FILE" ]; then
    cat "$VERSION_FILE"
  else
    echo "none"
  fi
}

install_hyprvoice() {
  log "Installing hyprvoice $HYPRVOICE_VERSION..."

  mkdir -p "$HOME/.local/bin" "$HYPRVOICE_STATE"

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  curl -fsSL "$RELEASE_URL/$HYPRVOICE_VERSION/hyprvoice-linux-x86_64" \
    -o "$tmp/hyprvoice"
  curl -fsSL "$RELEASE_URL/$HYPRVOICE_VERSION/hyprvoice-linux-x86_64.sha256" \
    -o "$tmp/hyprvoice.sha256"

  log "Verifying checksum..."
  local expected
  expected="$(awk '{print $1}' "$tmp/hyprvoice.sha256")"
  echo "$expected  $tmp/hyprvoice" | sha256sum -c -

  install -m 755 "$tmp/hyprvoice" "$HYPRVOICE_BIN"
  echo "$HYPRVOICE_VERSION" > "$VERSION_FILE"

  log "Binary installed to $HYPRVOICE_BIN"
}

check_whisper_cli() {
  if command -v whisper-cli &>/dev/null || [ -x "$HOME/.local/bin/whisper-cli" ]; then
    log "whisper-cli found"
    return
  fi

  log "WARNING: whisper-cli not found in PATH or ~/.local/bin"
  log "Build it inside a distrobox and copy to ~/.local/bin:"
  log "  git clone --depth 1 -b v1.7.6 https://github.com/ggml-org/whisper.cpp /tmp/whisper.cpp"
  log "  cmake -B /tmp/whisper.cpp/build -S /tmp/whisper.cpp -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF"
  log "  cmake --build /tmp/whisper.cpp/build --target whisper-cli -j\$(nproc)"
  log "  install -m 755 /tmp/whisper.cpp/build/bin/whisper-cli ~/.local/bin/whisper-cli"
}

install_model() {
  local model_dir="$HOME/.local/share/hyprvoice/models/whisper"
  local model_file="ggml-${DEFAULT_MODEL}.bin"
  if [ -f "$model_dir/$model_file" ]; then
    log "Whisper $DEFAULT_MODEL model already present"
    return
  fi

  log "Downloading whisper $DEFAULT_MODEL model..."
  "$HYPRVOICE_BIN" model download "$DEFAULT_MODEL"
  log "Model download complete"
}

# ─── Main ───────────────────────────────────────────────────────────

log "Setting up hyprvoice for $USER..."

# 1. Install hyprvoice daemon binary
if [ "$(installed_version)" != "$HYPRVOICE_VERSION" ]; then
  install_hyprvoice
else
  log "hyprvoice already at $HYPRVOICE_VERSION, skipping"
fi

# 2. Check whisper-cli is available
check_whisper_cli

# 3. Download default whisper model
install_model

log "Setup complete!"
