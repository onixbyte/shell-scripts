#!/usr/bin/env bash
#
# AWS CLI Installation for Debian/Ubuntu
# Installs the AWS CLI v2 via the official installer bundle when it is not
# already available on the system. Required by install-caddy.sh for
# downloading the Caddy binary from S3-compatible storage.
#

set -euo pipefail

# Ensure script is executed with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

if command -v aws >/dev/null 2>&1; then
    echo "==> aws-cli already installed at '$(command -v aws)'. Nothing to do."
    exit 0
fi

echo "==> aws-cli not found, installing via official bundle..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${TMP_DIR}/awscliv2.zip"
unzip -q "${TMP_DIR}/awscliv2.zip" -d "${TMP_DIR}"
"${TMP_DIR}/aws/install"

echo "========================================================="
echo " aws-cli installed successfully: $(command -v aws)"
echo "========================================================="
