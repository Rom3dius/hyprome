#!/usr/bin/env bash
# Builds and installs the caelestia-dots desktop shell (quickshell-based) on
# top of wayblue's Hyprland image. wayblue's own waybar/rofi-wayland/wofi/
# dunst/hyprlock/hyprpaper (and pavucontrol/thunar, superseded by
# pwvucontrol/nautilus... see below) are removed in recipe.yml's rpm-ostree
# module, since caelestia-shell fully replaces their functionality (bar,
# launcher, notifications, lock screen, wallpaper) and duplicate apps serving
# the same role aren't wanted here. caelestia's own hypr/hyprland/execs.lua
# execs `caelestia shell -d` on start.
#
# Deliberate deviations from caelestia's own defaults, each overridden via
# hyprome-dev-dots' hypr-vars.lua: terminal stays kitty (not foot), shell
# stays zsh (not fish, no fish package installed here), file manager is
# GNOME's Nautilus (not thunar) — pavucontrol stays for audio (pwvucontrol
# isn't packaged anywhere we have access to on Fedora 44).
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

# NOTE: caelestia-shell's CMakeLists.txt defaults both INSTALL_QMLDIR and
# INSTALL_LIBDIR to *relative* paths that already start with "usr/" (e.g.
# "usr/lib/qt6/qml") — combined with CMAKE_INSTALL_PREFIX=/usr, CMake joins
# them into a doubled /usr/usr/... (a real bug hit in an earlier build, for
# INSTALL_QMLDIR specifically). Setting both explicitly, without the
# redundant "usr/" segment, makes them land at the intended /usr/lib64/...
# and /usr/lib/caelestia — no symlink workaround needed either way.
cmake -B build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DINSTALL_QMLDIR=lib64/qt6/qml \
    -DINSTALL_LIBDIR=lib/caelestia \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DINSTALL_QSCONFDIR=/usr/share/quickshell/caelestia

cmake --build build -j"$(nproc)"
cmake --install build

mkdir -p /etc/xdg/quickshell
ln -sf /usr/share/quickshell/caelestia /etc/xdg/quickshell/caelestia

ldconfig
cd /tmp && rm -rf /tmp/caelestia-shell

###############################################################################
# BUILD CAELESTIA-CLI
###############################################################################
log "Building caelestia-cli ${CAELESTIA_CLI_VERSION}..."

git clone --depth=1 --branch "${CAELESTIA_CLI_VERSION}" \
    https://github.com/caelestia-dots/cli.git /tmp/caelestia-cli

cd /tmp/caelestia-cli

# NOTE: --prefix=/usr is required here. Two earlier versions of this script
# got this wrong in different ways:
#   1. --target /usr/lib/python3/dist-packages — Debian/Ubuntu's dpkg
#      convention, Fedora's python3 never searches that path.
#   2. No --target/--prefix at all — pip's default "not a system package
#      manager" scheme installs to /usr/local/lib/python3.14/site-packages,
#      but /usr/local is a symlink to ../var/usrlocal on this ostree-based
#      image (/usr must stay read-only, so /usr/local is redirected into
#      /var). This build's own post_build.sh does `rm -rf /var/*` as a final
#      cleanup step, silently wiping the "successfully installed" package
#      before the image was even finished. --prefix=/usr forces pip to
#      install into /usr/lib64/python3.14/site-packages instead, alongside
#      where caelestia-cli itself lands two lines down.
pip3 install materialyoucolor --break-system-packages --prefix=/usr
python3 -m build --wheel --no-isolation
python3 -m installer --prefix /usr dist/*.whl

# caelestia-cli only ships a fish completion, and fish isn't installed here
# (kept zsh) — nothing to install.

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
# caelestia-shell's own UI (config/AppearanceConfig.qml) hardcodes its font
# defaults: material="Material Symbols Rounded" (fetched below — not part of
# any nerd-fonts bundle), mono="CaskaydiaCove NF" (fetched below — hyprome's
# own `nerd-fonts` package, via the che/nerd-fonts COPR, turned out to only
# ship the symbols-only glyph set, not full patched font families, so this
# can't be skipped), sans/clock="Rubik" (installed as a package in
# recipe.yml via google-rubik-fonts). Verified CaskaydiaCove's shipped family
# name is exactly "CaskaydiaCove NF" — no fontconfig alias needed for it,
# unlike the JetBrains Mono naming mismatch hit (and dropped) in an earlier
# version of this script when foot was still in use.
log "Installing Material Symbols Rounded + CaskaydiaCove Nerd Font..."

FONT_DIR="/usr/share/fonts/caelestia"
install -d "${FONT_DIR}"

curl -fsSL \
    "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" \
    -o "${FONT_DIR}/MaterialSymbolsRounded.ttf"

curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.zip" \
    -o /tmp/CascadiaCode.zip
unzip -oq /tmp/CascadiaCode.zip "CaskaydiaCoveNerdFont-*.ttf" -d "${FONT_DIR}"
rm -f /tmp/CascadiaCode.zip

fc-cache -f "${FONT_DIR}"

###############################################################################
# DISABLE COPR
###############################################################################
log "Disabling errornointernet/quickshell COPR..."
dnf5 -y copr disable errornointernet/quickshell || true

log "caelestia install complete."
