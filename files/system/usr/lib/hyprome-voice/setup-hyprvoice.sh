#!/bin/bash
set -euo pipefail

# ─── Config ─────────────────────────────────────────────────────────
HYPRVOICE_VERSION="v1.0.2"
WHISPER_CPP_VERSION="v1.8.4"
WHISPER_CPP_REPO="https://github.com/ggml-org/whisper.cpp.git"
HYPRVOICE_BIN="$HOME/.local/bin/hyprvoice"
WHISPER_CLI_BIN="$HOME/.local/bin/whisper-cli"
HYPRVOICE_STATE="$HOME/.local/share/hyprome-voice"
VERSION_FILE="$HYPRVOICE_STATE/version"
RELEASE_URL="https://github.com/LeonardoTrapani/hyprvoice/releases/download"
MODELS=("small.en" "large-v3-turbo")

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

install_whisper_cli() {
  # Skip if whisper-cli already exists (preserves custom builds e.g. Vulkan)
  if [ -x "$WHISPER_CLI_BIN" ]; then
    log "whisper-cli already installed, skipping (remove to force reinstall)"
    return
  fi

  log "Building whisper-cli $WHISPER_CPP_VERSION (CPU)..."

  # Check build dependencies
  local missing=()
  command -v cmake &>/dev/null || missing+=("cmake")
  command -v g++   &>/dev/null || missing+=("g++")
  command -v git   &>/dev/null || missing+=("git")
  if [ "${#missing[@]}" -gt 0 ]; then
    log "WARNING: Cannot build whisper-cli, missing: ${missing[*]}"
    log "Build manually in a distrobox and copy to ~/.local/bin/whisper-cli"
    return
  fi

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  git clone --depth 1 --branch "$WHISPER_CPP_VERSION" "$WHISPER_CPP_REPO" "$tmp/whisper.cpp"

  cmake -B "$tmp/whisper.cpp/build" -S "$tmp/whisper.cpp" \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_EXAMPLES=ON \
    -DWHISPER_BUILD_TESTS=OFF \
    -DWHISPER_BUILD_SERVER=OFF

  cmake --build "$tmp/whisper.cpp/build" --target whisper-cli -j"$(nproc)"

  mkdir -p "$HOME/.local/bin"
  install -m 755 "$tmp/whisper.cpp/build/bin/whisper-cli" "$WHISPER_CLI_BIN"

  log "whisper-cli (CPU) installed to $WHISPER_CLI_BIN"
}

install_models() {
  local model_dir="$HOME/.local/share/hyprvoice/models/whisper"
  for model in "${MODELS[@]}"; do
    if [ -f "$model_dir/ggml-${model}.bin" ]; then
      log "Whisper $model model already present"
    else
      log "Downloading whisper $model model..."
      "$HYPRVOICE_BIN" model download "$model"
      log "Whisper $model model download complete"
    fi
  done
}

# ─── Main ───────────────────────────────────────────────────────────

log "Setting up hyprvoice for $USER..."

# 1. Install hyprvoice daemon binary
if [ "$(installed_version)" != "$HYPRVOICE_VERSION" ]; then
  install_hyprvoice
else
  log "hyprvoice already at $HYPRVOICE_VERSION, skipping"
fi

# 2. Install whisper-cli (CPU baseline, skips if custom build exists)
install_whisper_cli

# 3. Download whisper models
install_models

log "Setup complete!"
