#!/usr/bin/bash
set -euo pipefail

echo "[1Password] Importing GPG key and adding repo …"
rpm --import https://downloads.1password.com/linux/keys/1password.asc
cat >/etc/yum.repos.d/1password.repo <<'EOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
EOF

echo "[1Password] Installing GUI + CLI RPMs …"
dnf -y install 1password 1password-cli

echo "[1Password] Relocating payload into /usr/lib …"
mkdir -p /usr/lib/1password
cp -a /opt/1Password/* /usr/lib/1password/
rm -rf /opt/1Password
ln -s /usr/lib/1password /opt/1Password

sed -i 's|/opt/1Password/1password|/usr/lib/1password/1password|' \
  /usr/share/applications/1password.desktop

echo "[1Password] Installed: $(/usr/bin/1password --version)"
