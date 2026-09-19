# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hyprome is a custom Fedora Atomic OS image built using BlueBuild. It's based on wayblueorg/hyprland and uses the Hyprland window manager with [caelestia-dots](https://github.com/caelestia-dots/caelestia) (a quickshell-based shell) as the desktop UI — see `files/scripts/install-caelestia.sh` for how caelestia-shell/caelestia-cli are built into the image. wayblue's own waybar/rofi/wofi/dunst/hyprlock/hyprpaper stay installed as a fallback but aren't the default UI anymore. The login shell drops users into a distrobox container by default for dev tooling (unrelated to the desktop shell).

## Build Commands

**Local build and test:**
```bash
bluebuild build -B podman recipes/recipe.yml
podman save --format oci-archive -o /var/tmp/hyprome.tar localhost/hyprome:latest
sudo rpm-ostree rebase ostree-unverified-image:oci-archive:/var/tmp/hyprome.tar
```

**Rollback if issues occur:**
```bash
rpm-ostree rollback
rpm-ostree cleanup -p
```

**Generate offline ISO (on Fedora Atomic only):**
Follow instructions at https://blue-build.org/learn/universal-blue/#fresh-install-from-an-iso

## Repository Structure

- `recipes/recipe.yml` - Main BlueBuild recipe defining the image (base image, packages, flatpaks, systemd units)
- `files/system/` - Files copied directly into the image root filesystem
  - `etc/` - System configuration (sddm, greetd, gtk settings, systemd user units)
  - `usr/lib/` - Custom scripts (sync-dots.sh)
  - `usr/share/sddm/themes/sddm-hyprome-theme/` - Custom SDDM login theme (QML)
- `files/scripts/` - Scripts run by `type: script` recipe modules during the image build (`install-caelestia.sh`)
- `modules/` - Custom BlueBuild modules (currently empty)
- `cosign.key` - Public key for image signature verification

## Recipe Schema

The recipe follows the BlueBuild recipe-v1 schema: https://schema.blue-build.org/recipe-v1.json

Key module types used:
- `files` - Copy files from `files/` into image
- `rpm-ostree` - Add COPR repos, install/remove packages
- `script` - Run a script from `files/scripts/` during the build (used for caelestia's COPR/source-build install)
- `default-flatpaks` - Configure system/user flatpaks
- `bling` - Install additional tools (1password)
- `soar` - Package manager with auto-upgrade
- `systemd` - Enable system/user services

## CI/CD

GitHub Actions builds the image daily at 06:00 UTC and on push (excluding markdown-only changes). Images are signed with cosign and published to ghcr.io.
