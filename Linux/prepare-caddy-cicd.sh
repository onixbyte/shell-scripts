#!/usr/bin/env bash
#
# Caddy CI/CD Serving Preparation for Debian/Ubuntu
# Prepares the server so a CI/CD pipeline can publish content that Caddy
# serves: creates the deployment user 'bot' with its SSH access, creates and
# hands over the web root to bot:caddy with ACLs that keep it readable by the
# Caddy server, writes the default site Caddyfile and sample page, then starts
# the Caddy service. The web root defaults to /var/www and can be overridden
# by exporting the WEB_ROOT environment variable before running.
#

set -euo pipefail

# Web root served by Caddy; override by exporting WEB_ROOT before running
WEB_ROOT="${WEB_ROOT:-/var/www}"
CADDY_CONF_DIR="/etc/caddy"

# Ensure script is executed with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

if [ ! -f /etc/systemd/system/caddy.service ]; then
    echo "Error: caddy.service not found. Run install-caddy.sh first." >&2
    exit 1
fi

if ! getent group caddy >/dev/null 2>&1; then
    echo "Error: group 'caddy' does not exist. Run install-caddy.sh first." >&2
    exit 1
fi

echo "==> [1/5] Creating deployment user 'bot'..."
# Create deployment user 'bot'
if ! id -u bot >/dev/null 2>&1; then
    useradd -m -s /bin/bash bot
fi

echo "==> [2/5] Configuring SSH directory for bot..."
# Configure SSH directory for bot
install -d -m 700 -o bot -g bot /home/bot/.ssh
touch /home/bot/.ssh/authorized_keys
chown bot:bot /home/bot/.ssh/authorized_keys
chmod 600 /home/bot/.ssh/authorized_keys

echo "==> [3/5] Creating web root and handing it to bot (${WEB_ROOT})..."
if [ ! -d "${WEB_ROOT}" ]; then
    mkdir -p "${WEB_ROOT}"

    cat <<EOF > "${WEB_ROOT}/index.html"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Caddy Ready</title>
</head>
<body>
    <h1>Caddy server is running</h1>
    <p>Static files root: <code>${WEB_ROOT}</code></p>
</body>
</html>
EOF
else
    echo "    '${WEB_ROOT}' already exists - leaving existing content untouched."
fi

# Set base ownership: bot (deployment) and caddy (web server group)
chown -R bot:caddy "${WEB_ROOT}"

# Directory base permissions (SGID ensures newly created items inherit group 'caddy')
find "${WEB_ROOT}" -type d -exec chmod 2755 {} +
find "${WEB_ROOT}" -type f -exec chmod 644 {} +

# Apply POSIX ACLs: bot has rwx, caddy has read/execute, with default inheritance
setfacl -R -m u:bot:rwx,u:caddy:rX "${WEB_ROOT}"
setfacl -R -d -m u:bot:rwx,u:caddy:rX "${WEB_ROOT}"

echo "==> [4/5] Writing site Caddyfile (${CADDY_CONF_DIR}/Caddyfile)..."
mkdir -p "${CADDY_CONF_DIR}"
chown root:caddy "${CADDY_CONF_DIR}"
chmod 755 "${CADDY_CONF_DIR}"

if [ ! -f "${CADDY_CONF_DIR}/Caddyfile" ]; then
    cat <<EOF > "${CADDY_CONF_DIR}/Caddyfile"
:80 {
    root * ${WEB_ROOT}
    file_server
}
EOF
    chown root:caddy "${CADDY_CONF_DIR}/Caddyfile"
    chmod 644 "${CADDY_CONF_DIR}/Caddyfile"
else
    echo "    '${CADDY_CONF_DIR}/Caddyfile' already exists - leaving it untouched."
fi

echo "==> [5/5] Starting Caddy service..."
systemctl enable --now caddy

echo "========================================================="
echo " Caddy CI/CD preparation finished successfully!"
echo " - Deployment user: bot (SSH keys accepted in authorized_keys)"
echo " - Web Root: ${WEB_ROOT} (owned by bot:caddy, readable by caddy)"
echo " - Config: ${CADDY_CONF_DIR}/Caddyfile"
echo " - Status: $(systemctl is-active caddy)"
echo "========================================================="
