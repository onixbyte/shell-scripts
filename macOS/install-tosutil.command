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

echo "=== Starting tosutil installation for macOS ==="

# 1. Architecture Detection
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        BIN_URL="https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/darwin/amd64/tosutil"
        SHA_URL="https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/darwin/amd64/tosutil.sha256sum"
        echo "Detected architecture: Intel (amd64)"
        ;;
    arm64)
        BIN_URL="https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/darwin/arm64/tosutil"
        SHA_URL="https://m645b3e1bb36e-mrap.mrap.accesspoint.tos-global.volces.com/darwin/arm64/tosutil.sha256sum"
        echo "Detected architecture: Apple Silicon (arm64)"
        ;;
    *)
        echo "Error: Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

TARGET_DIR="/usr/local/bin"
TARGET_PATH="${TARGET_DIR}/tosutil"

# 2. Create isolated temporary directory
TMP_DIR=$(mktemp -d /tmp/tosutil-install.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT
cd "$TMP_DIR"

# Step 1: Download binary and checksum via curl
echo -e "\n[1/5] Downloading tosutil binary and SHA256 checksum..."
run_cmd curl -fsSL -o tosutil "$BIN_URL"
run_cmd curl -fsSL -o tosutil.sha256sum "$SHA_URL"

# Step 2: Verify SHA256
echo -e "\n[2/5] Verifying SHA256 checksum..."
EXPECTED_HASH=$(awk '{print $1}' tosutil.sha256sum)
echo ">> Running: echo \"$EXPECTED_HASH  tosutil\" | shasum -a 256 -c -"
echo "$EXPECTED_HASH  tosutil" | shasum -a 256 -c -

# Step 3: Ensure /usr/local/bin exists and move binary
echo -e "\n[3/5] Moving binary to ${TARGET_PATH}..."
if [ ! -d "$TARGET_DIR" ]; then
    run_cmd $SUDO mkdir -p "$TARGET_DIR"
fi
run_cmd $SUDO mv tosutil "$TARGET_PATH"

# Step 4: Set permissions and bypass macOS Gatekeeper quarantine
echo -e "\n[4/5] Setting permissions and removing quarantine flag..."
run_cmd $SUDO chown root:wheel "$TARGET_PATH"
run_cmd $SUDO chmod 755 "$TARGET_PATH"
# Remove quarantine attribute if present
if run_cmd $SUDO xattr -d com.apple.quarantine "$TARGET_PATH" 2>/dev/null; then
    echo "Removed quarantine attribute."
fi

# Step 5: Verify installation
echo -e "\n[5/5] Checking installation..."
run_cmd tosutil version || run_cmd tosutil --version || true

echo -e "\n========================================================"
echo -e "✅ tosutil installed successfully to ${TARGET_PATH}."
echo -e "========================================================"
echo -e "\nNext Steps:"
echo -e "1. Initialise and configure your credentials:"
echo -e '   tosutil config -i "${TOS_ACCESS_KEY}" -k "${TOS_SECRET_KEY}" -e "${TOS_ENDPOINT}" -re "${TOS_REGION}"'
echo -e "\n2. For more detailed documentation, visit:"
echo -e "   https://docs.volcengine.com/docs/6349/148775?lang=zh\n"