#!/usr/bin/bash
set -euo pipefail

echo "[1Password] Importing GPG key …"
rpm --import https://downloads.1password.com/linux/keys/1password.asc

echo "[1Password] Writing yum repo file …"
cat > /etc/yum.repos.d/1password.repo <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
