#!/usr/bin/env bash

set -euo pipefail

# ==========================================
# Repository Settings
# ==========================================
GITHUB_USER="0urr-acid"
GITHUB_REPO="caddy-acid"

# ==========================================
# Variables and Temporary Files
# ==========================================
DOWNLOAD_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/latest/caddy-acid-latest.deb"
TMP_DIR=$(mktemp -d)
DEB_FILE="${TMP_DIR}/caddy-acid-latest.deb"

# Automatic cleanup of temporary files on exit
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

echo "[1/5] Checking existing configuration..."
if command -v caddy-acid &>/dev/null && [ -f /etc/caddy/Caddyfile ]; then
    if ! caddy-acid validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null 2>&1; then
        echo "Error: Current /etc/caddy/Caddyfile contains syntax errors. Update cancelled." >&2
        exit 1
    fi
fi

echo "[2/5] Downloading latest .deb package..."
if ! wget -q -O "${DEB_FILE}" "${DOWNLOAD_URL}"; then
    echo "Error: Failed to download file from ${DOWNLOAD_URL}" >&2
    exit 1
fi

# Verify that the downloaded file is a valid .deb package
if [ ! -s "${DEB_FILE}" ] || ! file "${DEB_FILE}" | grep -q 'Debian binary package'; then
    echo "Error: Downloaded file is corrupted or not a valid .deb package." >&2
    exit 1
fi

echo "[3/5] Installing package..."
sudo apt-get install -y "${DEB_FILE}"

echo "[4/5] Validating configuration after update..."
if ! caddy-acid validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
    echo "Critical error: New binary rejected existing Caddyfile!" >&2
    exit 1
fi

echo "[5/5] Reloading Caddy service..."
sudo systemctl reload-or-restart caddy

if systemctl is-active --quiet caddy; then
    echo "--------------------------------------------------"
    echo " Success! Caddy updated and running."
    echo " Version: $(caddy-acid version)"
    echo "--------------------------------------------------"
else
    echo "Error: Caddy service failed to start." >&2
    sudo systemctl status caddy --no-pager
    exit 1
fi