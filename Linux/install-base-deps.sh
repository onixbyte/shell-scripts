#!/usr/bin/env bash
#
# Base Dependencies Installation for Debian/Ubuntu
# Installs the packages required by the other server initialisation scripts.
#

set -euo pipefail

# Ensure script is executed with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

echo "==> Updating package index..."
apt-get update -qq

echo "==> Installing base dependencies (acl, libcap2-bin, rsync, curl, unzip)..."
apt-get install -y acl libcap2-bin rsync curl unzip

echo "========================================================="
echo " Base dependencies installed successfully!"
echo "========================================================="
