#!/usr/bin/env bash

set -euo pipefail

# Helper function to print and execute commands
run_cmd() {
    echo ">> Running: $*"
    "$@"
}

# Determine sudo requirement
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

echo "=== Starting tosutil installation for Linux ==="

# Architecture Detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        BIN_URL="https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/linux/amd64/tosutil"
        SHA_URL="https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/linux/amd64/tosutil.sha256sum"
        echo "Detected architecture: amd64 (${ARCH})"
        ;;
    aarch64|arm64)
        BIN_URL="https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/linux/arm64/tosutil"
        SHA_URL="https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/linux/arm64/tosutil.sha256sum"
        echo "Detected architecture: arm64 (${ARCH})"
        ;;
    *)
        echo "Error: Unsupported architecture: ${ARCH}" >&2
        exit 1
        ;;
esac

TARGET_PATH="/usr/local/bin/tosutil"

# Create isolated temporary directory
TMP_DIR=$(mktemp -d /tmp/tosutil-install.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR"

# Download binary and checksum
echo -e "\n[1/5] Downloading tosutil binary and SHA256 checksum..."
run_cmd wget -q --show-progress -O tosutil "$BIN_URL"
run_cmd wget -q --show-progress -O tosutil.sha256sum "$SHA_URL"

# Verify SHA256
echo -e "\n[2/5] Verifying SHA256 checksum..."
if grep -q "tosutil" tosutil.sha256sum; then
    run_cmd sha256sum -c tosutil.sha256sum
else
    EXPECTED_HASH=$(awk '{print $1}' tosutil.sha256sum)
    echo ">> Running: echo \"$EXPECTED_HASH  tosutil\" | sha256sum -c -"
    echo "$EXPECTED_HASH  tosutil" | sha256sum -c -
fi

# Move binary to /usr/local/bin
echo -e "\n[3/5] Moving binary to ${TARGET_PATH}..."
run_cmd $SUDO mv tosutil "$TARGET_PATH"

# Set ownership and permissions
echo -e "\n[4/5] Setting owner and permissions..."
run_cmd $SUDO chown root:root "$TARGET_PATH"
run_cmd $SUDO chmod 755 "$TARGET_PATH"

# Completion check
echo -e "\n[5/5] Checking installation..."
run_cmd tosutil version || true

echo -e "\n========================================================"
echo -e "✅ tosutil installed successfully to ${TARGET_PATH}."
echo -e "========================================================"
echo -e "\nNext Steps:"
echo -e "1. Initialise and configure your credentials:"
echo -e '   tosutil config -i "${TOS_ACCESS_KEY}" -k "${TOS_SECRET_KEY}" -e "${TOS_ENDPOINT}" -re "${TOS_REGION}"'
echo -e "\n2. For more detailed documentation, visit:"
echo -e "   https://docs.volcengine.com/docs/6349/148775?lang=zh\n"