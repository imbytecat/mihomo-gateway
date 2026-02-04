#!/bin/bash
set -euo pipefail

echo "==> Installing Mihomo (Clash Meta)..."

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  MIHOMO_ARCH="amd64" ;;
    aarch64) MIHOMO_ARCH="arm64" ;;
    armv7l)  MIHOMO_ARCH="armv7" ;;
    *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "==> Detected architecture: $MIHOMO_ARCH"

# Check for pre-bundled binary first (for offline builds)
PREBUNDLED_BINARY="/tmp/files/mihomo/mihomo-linux-${MIHOMO_ARCH}"

if [ -f "$PREBUNDLED_BINARY" ]; then
    echo "==> Found pre-bundled binary: $PREBUNDLED_BINARY"
    cp "$PREBUNDLED_BINARY" /usr/local/bin/mihomo
    chmod +x /usr/local/bin/mihomo
else
    echo "==> No pre-bundled binary found, downloading from GitHub..."
    
    # Fetch latest release URL from GitHub API
    DOWNLOAD_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest \
        | grep "browser_download_url.*mihomo-linux-${MIHOMO_ARCH}-v" \
        | grep -v "alpha\|compatible" \
        | head -1 \
        | cut -d '"' -f 4)

    if [ -z "$DOWNLOAD_URL" ]; then
        echo "ERROR: Could not find download URL for architecture $MIHOMO_ARCH"
        echo "TIP: Pre-bundle the binary at files/mihomo/mihomo-linux-${MIHOMO_ARCH}"
        exit 1
    fi

    echo "==> Downloading from: $DOWNLOAD_URL"

    # Download and extract
    cd /tmp
    curl -LO "$DOWNLOAD_URL"
    FILENAME=$(basename "$DOWNLOAD_URL")

    # Handle different compression formats
    if [[ "$FILENAME" == *.gz ]]; then
        gzip -d "$FILENAME"
        FILENAME="${FILENAME%.gz}"
    fi

    # Install binary
    chmod +x "$FILENAME"
    mv "$FILENAME" /usr/local/bin/mihomo
fi

echo "==> Mihomo installed at /usr/local/bin/mihomo"
/usr/local/bin/mihomo -v

# Create configuration directory
mkdir -p /etc/mihomo
echo "==> Created /etc/mihomo directory"

# Copy config template (already copied by Packer file provisioner)
if [ -f /tmp/files/mihomo/config.yaml.template ]; then
    cp /tmp/files/mihomo/config.yaml.template /etc/mihomo/config.yaml
    echo "==> Copied config template to /etc/mihomo/config.yaml"
fi

# Copy systemd service (already copied by Packer file provisioner)
if [ -f /tmp/files/systemd/mihomo.service ]; then
    cp /tmp/files/systemd/mihomo.service /etc/systemd/system/mihomo.service
    echo "==> Installed systemd service"
fi

# Set permissions
chown -R root:root /etc/mihomo
chmod 755 /etc/mihomo
chmod 644 /etc/mihomo/config.yaml 2>/dev/null || true

# Enable service (don't start - config is template)
systemctl daemon-reload
systemctl enable mihomo.service
echo "==> Mihomo service enabled (will start after config is provided)"

echo "==> Mihomo installation complete!"
