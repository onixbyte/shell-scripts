#!/usr/bin/env bash
#
# Caddy Installation for Debian/Ubuntu
# Downloads the Caddy binary (from a local file or S3-compatible storage),
# creates the caddy:caddy system user and group, installs the binary with
# cap_net_bind_service, prepares the config directory and registers the
# systemd unit. The service itself is started by prepare-caddy-cicd.sh once
# the site Caddyfile and web root exist.
#

set -euo pipefail

# S3 and binary environment variables (with fallback defaults)
S3_ENDPOINT="${S3_ENDPOINT:-}"
S3_BUCKET="${S3_BUCKET:-}"
S3_REGION="${S3_REGION:-us-east-1}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"
BIN_URI="${BIN_URI:-caddy-custom-linux-amd64}"

BIN_SOURCE="./${BIN_URI}"
BIN_DEST="/usr/local/bin/caddy"
CADDY_CONF_DIR="/etc/caddy"
CADDY_DATA_DIR="/var/lib/caddy"

# Ensure script is executed with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

echo "==> [1/5] Resolving Caddy binary..."
if [ ! -f "${BIN_SOURCE}" ]; then
    if [ -n "${S3_BUCKET}" ]; then
        echo "Local binary '${BIN_SOURCE}' not found. Downloading from S3 bucket '${S3_BUCKET}'..."

        # Export AWS credentials for the current execution
        export AWS_ACCESS_KEY_ID="${S3_ACCESS_KEY}"
        export AWS_SECRET_ACCESS_KEY="${S3_SECRET_KEY}"
        export AWS_DEFAULT_REGION="${S3_REGION}"

        AWS_CMD_ARGS=()
        if [ -n "${S3_ENDPOINT}" ]; then
            AWS_CMD_ARGS+=(--endpoint-url "${S3_ENDPOINT}")
        fi

        aws s3 cp "s3://${S3_BUCKET}/${BIN_URI}" "${BIN_SOURCE}" "${AWS_CMD_ARGS[@]}"
        echo "Successfully downloaded '${BIN_URI}' from S3."
    else
        echo "Error: Local binary '${BIN_SOURCE}' not found, and S3_BUCKET is empty. Cannot continue." >&2
        exit 1
    fi
else
    echo "Found local binary at '${BIN_SOURCE}', skipping S3 download."
fi

echo "==> [2/5] Creating caddy system user and group..."
# Create caddy system user and group (no login shell, dedicated home)
if ! getent group caddy >/dev/null 2>&1; then
    groupadd --system caddy
fi

if ! id -u caddy >/dev/null 2>&1; then
    useradd --system \
        --gid caddy \
        --create-home \
        --home-dir "${CADDY_DATA_DIR}" \
        --shell /usr/sbin/nologin \
        --comment "Caddy web server" \
        caddy
fi

echo "==> [3/5] Installing Caddy binary and granting capabilities..."
install -m 750 -o root -g caddy "${BIN_SOURCE}" "${BIN_DEST}"

# Grant capability to bind to privileged ports (<1024) without running as root
setcap 'cap_net_bind_service=+ep' "${BIN_DEST}"

echo "==> [4/5] Preparing config directory (${CADDY_CONF_DIR})..."
mkdir -p "${CADDY_CONF_DIR}"
chown root:caddy "${CADDY_CONF_DIR}"
chmod 755 "${CADDY_CONF_DIR}"

echo "==> [5/5] Registering systemd service..."
# The unit is only registered here; prepare-caddy-cicd.sh starts it once the
# site Caddyfile and web root are in place.
cat <<'EOF' > /etc/systemd/system/caddy.service
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

echo "========================================================="
echo " Caddy installation finished successfully!"
echo " - Binary: ${BIN_DEST} (Capabilities: cap_net_bind_service)"
echo " - User/Group: caddy:caddy"
echo " - Config dir: ${CADDY_CONF_DIR}"
echo " - Service registered but not yet started."
echo " - Next: run prepare-caddy-cicd.sh to create the site config"
echo "         and web root, then start Caddy."
echo "========================================================="
