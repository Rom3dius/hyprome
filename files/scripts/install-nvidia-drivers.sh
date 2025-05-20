#!/usr/bin/bash
set -euo pipefail

KERNEL_VERSION=$(uname -r)
MODULE_DIR="/lib/modules/${KERNEL_VERSION}/extra/nvidia"
BUILD_DIR="/tmp/nvidia-open-build"

# Install required packages
dnf install -y git make gcc kernel-devel-${KERNEL_VERSION}

# Prepare build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Clone NVIDIA Open GPU Kernel Modules
git clone --depth=1 https://github.com/NVIDIA/open-gpu-kernel-modules.git
cd open-gpu-kernel-modules

# Build modules
make modules_install -j$(nproc)

# Disable Nouveau
echo -e "blacklist nouveau\noptions nouveau modeset=0" >/etc/modprobe.d/disable-nouveau.conf

# Configure NVIDIA modules to load
echo -e "nvidia\nnvidia_drm\nnvidia_uvm" >/etc/modules-load.d/nvidia.conf

# Enable DRM KMS
echo "options nvidia-drm modeset=1" >/etc/modprobe.d/nvidia-kms.conf

# Optional: Clean up
rm -rf "${BUILD_DIR}"
