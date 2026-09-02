#!/usr/bin/env bash
#
# Caddy & Bot Deployment Environment Initialisation Script for Debian
# Supports automatic binary download from S3-compatible storage.
#

set -euo pipefail

# S3 and Binary Environment Variables (with fallback defaults)
S3_ENDPOINT="${S3_ENDPOINT:-}"
S3_BUCKET="${S3_BUCKET:-}"
S3_REGION="${S3_REGION:-us-east-1}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"
BIN_URI="${BIN_URI:-caddy-custom-linux-amd64}"

BIN_SOURCE="./${BIN_URI}"
BIN_DEST="/usr/local/bin/caddy"
WWW_ROOT="/var/www"
CADDY_CONF_DIR="/etc/caddy"
CADDY_DATA_DIR="/var/lib/caddy"

# Ensure script is executed with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

echo "==> [1/8] Installing base dependencies..."
apt-get update -qq
apt-get install -y acl libcap2-bin rsync curl unzip

echo "==> [2/8] Ensuring aws-cli is installed..."
if ! command -v aws >/dev/null 2>&1; then
    echo "aws-cli not found, installing via official bundle..."
    TMP_DIR=$(mktemp -d)
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${TMP_DIR}/awscliv2.zip"
    unzip -q "${TMP_DIR}/awscliv2.zip" -d "${TMP_DIR}"
    "${TMP_DIR}/aws/install"
    rm -rf "${TMP_DIR}"
fi

echo "==> [3/8] Resolving Caddy binary..."
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

echo "==> [4/8] Creating system users and groups..."
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

# Create deployment user 'bot'
if ! id -u bot >/dev/null 2>&1; then
    useradd -m -s /bin/bash bot
fi

# Configure SSH directory for bot
install -d -m 700 -o bot -g bot /home/bot/.ssh
touch /home/bot/.ssh/authorized_keys
chown bot:bot /home/bot/.ssh/authorized_keys
chmod 600 /home/bot/.ssh/authorized_keys

echo "==> [5/8] Installing Caddy binary and granting capabilities..."
install -m 750 -o root -g caddy "${BIN_SOURCE}" "${BIN_DEST}"

# Grant capability to bind to privileged ports (<1024) without running as root
setcap 'cap_net_bind_service=+ep' "${BIN_DEST}"

echo "==> [6/8] Setting up web root directory permissions (${WWW_ROOT})..."
mkdir -p "${WWW_ROOT}"

# Set base ownership: bot (deployment) and caddy (web server group)
chown -R bot:caddy "${WWW_ROOT}"

# Directory base permissions (SGID ensures newly created items inherit group 'caddy')
find "${WWW_ROOT}" -type d -exec chmod 2755 {} +
find "${WWW_ROOT}" -type f -exec chmod 644 {} +

# Apply POSIX ACLs: bot has rwx, caddy has read/execute, with default inheritance
setfacl -R -m u:bot:rwx,u:caddy:rX "${WWW_ROOT}"
setfacl -R -d -m u:bot:rwx,u:caddy:rX "${WWW_ROOT}"

echo "==> [7/8] Creating Caddy configuration and sample site..."
mkdir -p "${CADDY_CONF_DIR}"
chown root:caddy "${CADDY_CONF_DIR}"
chmod 755 "${CADDY_CONF_DIR}"

if [ ! -f "${CADDY_CONF_DIR}/Caddyfile" ]; then
    cat <<'EOF' > "${CADDY_CONF_DIR}/Caddyfile"
:80 {
    root * /var/www
    file_server
}
EOF
    chown root:caddy "${CADDY_CONF_DIR}/Caddyfile"
    chmod 644 "${CADDY_CONF_DIR}/Caddyfile"
fi

if [ ! -f "${WWW_ROOT}/index.html" ]; then
    cat <<'EOF' > "${WWW_ROOT}/index.html"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Caddy Ready</title>
</head>
<body>
    <h1>Caddy server is running</h1>
    <p>Static files root: <code>/var/www</code></p>
</body>
</html>
EOF
    chown bot:caddy "${WWW_ROOT}/index.html"
    chmod 644 "${WWW_ROOT}/index.html"
fi

echo "==> [8/8] Configuring systemd service and starting Caddy..."
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
systemctl enable --now caddy

echo "========================================================="
echo " Initialisation finished successfully!"
echo " - Binary: ${BIN_DEST} (Capabilities: cap_net_bind_service)"
echo " - Web Root: ${WWW_ROOT} (Managed by: bot, Read by: caddy)"
echo " - Config: ${CADDY_CONF_DIR}/Caddyfile"
echo " - Status: $(systemctl is-active caddy)"
echo "========================================================="