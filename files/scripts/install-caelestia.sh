#!/usr/bin/env bash
# Builds and installs the caelestia-dots desktop shell (quickshell-based) on
# top of wayblue's Hyprland image. wayblue's own waybar/rofi-wayland/wofi/
# dunst/hyprlock/hyprpaper/kitty (and pavucontrol, superseded by
# pwvucontrol) are removed in recipe.yml's rpm-ostree module, since
# caelestia-shell fully replaces their functionality (bar, launcher,
# notifications, lock screen, wallpaper) and duplicate apps serving the same
# role aren't wanted here. caelestia's own hypr/hyprland/execs.lua execs
# `caelestia shell -d` on start.
set -oue pipefail

log() { echo "=== $* ==="; }

CAELESTIA_SHELL_VERSION="v1.4.2"   # https://github.com/caelestia-dots/shell/releases
CAELESTIA_CLI_VERSION="v1.0.5"     # https://github.com/caelestia-dots/cli/releases
CAVA_VERSION="0.10.6"              # https://github.com/LukashonakV/cava/releases

###############################################################################
# COPR: quickshell-git
###############################################################################
# wayblue's own Hyprland COPR (craftidore/wayblueorg-hyprland) is already
# enabled via the base image, so we do NOT add another Hyprland COPR here
# (avoids the package-set conflicts that both wayblue and hyprblue-caelestia
# have separately hit when mixing Hyprland/Qt builds from different COPRs).
log "Enabling errornointernet/quickshell COPR..."
dnf5 -y copr enable errornointernet/quickshell || true

###############################################################################
# PACKAGES
###############################################################################
# quickshell-git and its close runtime deps not already covered by wayblue's
# common-modules.yml (NetworkManager, bluez, wireplumber, thunar, grim/slurp,
# playerctl, ddcutil, brightnessctl, wl-clipboard, papirus-icon-theme, etc.
# are already present from the base image — not repeated here).
#
# Qt6 packages are deliberately NOT hand-pinned here: quickshell-git declares
# its own Qt6 (qtbase/qtdeclarative/...) dependencies and dnf's resolver will
# pull compatible versions. Both wayblue and hyprblue-caelestia have hit real
# Qt6 version conflicts when explicitly forcing qt6-* packages (see the
# existing "qt6 packages conflict with wayblue's qt6-qtbase version" note in
# recipe.yml) — trust dependency resolution instead of repeating that.
QS_PKGS=(
    quickshell-git
)

CAELESTIA_RUNTIME=(
    foot
    fish
    btop
    lm_sensors
    socat
    ImageMagick
    jq
    adw-gtk3-theme
    qt6ct
    qalculate
    libqalculate
    trash-cli
    hyprpicker
    ydotool
    # NOTE: caelestia's own default audioSettings var wants `pwvucontrol`,
    # but it isn't available in any repo we have enabled for Fedora 44 (not
    # in Fedora/updates, rpmfusion, or any COPR here) — --skip-unavailable
    # would silently drop it below. wayblue's own `pavucontrol` (kept
    # installed, see recipe.yml) is used instead; hypr-vars.lua overrides
    # audioSettings to match.
)

BUILD_DEPS=(
    git
    cmake
    ninja-build
    gcc
    gcc-c++
    pkg-config
    meson
    fftw-devel
    iniparser-devel
    ncurses-devel
    portaudio-devel
    alsa-lib-devel
    pulseaudio-libs-devel
    pipewire-devel
    qt6-qtbase-devel
    qt6-qtdeclarative-devel
    qt6-qtbase-private-devel
    libdrm-devel
    wayland-devel
    wayland-protocols-devel
    aubio-devel
    libqalculate-devel
    nodejs
    nodejs-npm
    python3-build
    python3-installer
    python3-hatch-vcs
    python3
    python3-pip
)

log "Installing packages..."
dnf5 install --setopt=install_weak_deps=False --skip-unavailable -y \
    "${QS_PKGS[@]}" \
    "${CAELESTIA_RUNTIME[@]}" \
    "${BUILD_DEPS[@]}"

# dart-sass via npm — redirect home/cache to /tmp to avoid broken symlinks in bootc
HOME=/tmp npm install -g sass --prefix /usr --cache /tmp/npm-cache

# starship prompt — not in Fedora standard repos, install from release binary
curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir /usr/bin

###############################################################################
# BUILD CAVA (provides libcava + pkg-config, used by caelestia-shell's visualizer)
###############################################################################
log "Building cava ${CAVA_VERSION}..."

curl -fsSL "https://github.com/LukashonakV/cava/archive/refs/tags/${CAVA_VERSION}.tar.gz" \
    -o /tmp/cava.tar.gz
cd /tmp && tar xf cava.tar.gz && cd "cava-${CAVA_VERSION}"

CC=gcc CXX=g++ meson setup build --prefix=/usr --buildtype=release
CC=gcc CXX=g++ meson compile -C build -j"$(nproc)"
meson install -C build

ln -sf /usr/lib64/pkgconfig/cava.pc /usr/lib64/pkgconfig/libcava.pc
ldconfig
cd /tmp && rm -rf "cava-${CAVA_VERSION}" cava.tar.gz

###############################################################################
# BUILD CAELESTIA-SHELL
###############################################################################
log "Building caelestia-shell ${CAELESTIA_SHELL_VERSION}..."

git clone --depth=1 --branch "${CAELESTIA_SHELL_VERSION}" \
    https://github.com/caelestia-dots/shell.git /tmp/caelestia-shell

cd /tmp/caelestia-shell

cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DINSTALL_QSCONFDIR=/usr/share/quickshell/caelestia

cmake --build build -j"$(nproc)"
cmake --install build

mkdir -p /etc/xdg/quickshell
ln -sf /usr/share/quickshell/caelestia /etc/xdg/quickshell/caelestia

mkdir -p /usr/lib64/qt6/qml
ln -sf /usr/lib/qt6/qml/Caelestia /usr/lib64/qt6/qml/Caelestia

ldconfig
cd /tmp && rm -rf /tmp/caelestia-shell

###############################################################################
# BUILD CAELESTIA-CLI
###############################################################################
log "Building caelestia-cli ${CAELESTIA_CLI_VERSION}..."

git clone --depth=1 --branch "${CAELESTIA_CLI_VERSION}" \
    https://github.com/caelestia-dots/cli.git /tmp/caelestia-cli

cd /tmp/caelestia-cli

pip3 install materialyoucolor --break-system-packages --target /usr/lib/python3/dist-packages
python3 -m build --wheel --no-isolation
python3 -m installer --prefix /usr dist/*.whl

install -Dm644 completions/caelestia.fish \
    /usr/share/fish/vendor_completions.d/caelestia.fish

cd /tmp && rm -rf /tmp/caelestia-cli

###############################################################################
# INSTALL APP2UNIT
###############################################################################
log "Installing app2unit..."

git clone --depth=1 \
    https://github.com/Vladimir-csp/app2unit.git /tmp/app2unit

install -Dpm755 /tmp/app2unit/app2unit              -t /usr/bin
install -Dpm755 /tmp/app2unit/app2unit-open          -t /usr/bin
install -Dpm755 /tmp/app2unit/app2unit-open-scope    -t /usr/bin
install -Dpm755 /tmp/app2unit/app2unit-open-service  -t /usr/bin
install -Dpm755 /tmp/app2unit/app2unit-term          -t /usr/bin
install -Dpm755 /tmp/app2unit/app2unit-term-scope    -t /usr/bin
install -Dpm755 /tmp/app2unit/app2unit-term-service  -t /usr/bin

rm -rf /tmp/app2unit

###############################################################################
# INSTALL FONTS
###############################################################################
# hyprome's own recipe.yml already installs the `nerd-fonts` meta-package
# (via the che/nerd-fonts COPR), which covers JetBrains Mono Nerd / Cascadia
# Code Nerd already — no need to re-download nerd fonts here. Material
# Symbols Rounded is caelestia-shell's one hard icon-font dependency and
# isn't part of any nerd-fonts bundle, so that's the only font we fetch.
log "Installing Material Symbols Rounded..."

FONT_DIR="/usr/share/fonts/caelestia"
install -d "${FONT_DIR}"

curl -fsSL \
    "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
    -o "${FONT_DIR}/MaterialSymbolsRounded.ttf"

fc-cache -f "${FONT_DIR}"

###############################################################################
# DISABLE COPR
###############################################################################
log "Disabling errornointernet/quickshell COPR..."
dnf5 -y copr disable errornointernet/quickshell || true

log "caelestia install complete."
