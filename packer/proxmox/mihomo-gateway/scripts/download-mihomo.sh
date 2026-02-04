#!/bin/bash
set -euo pipefail

# Download Mihomo binary for offline builds
# Usage: ./download-mihomo.sh [arch]
# arch: amd64 (default), arm64, armv7

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES_DIR="${SCRIPT_DIR}/../files/mihomo"

ARCH="${1:-amd64}"

echo "==> Downloading Mihomo for architecture: ${ARCH}"

# Fetch latest release URL from GitHub API
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest \
    | grep "browser_download_url.*mihomo-linux-${ARCH}-v" \
    | grep -v "alpha\|compatible" \
    | head -1 \
    | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Could not find download URL for architecture ${ARCH}"
    exit 1
fi

echo "==> Download URL: $DOWNLOAD_URL"

# Create output directory
mkdir -p "$FILES_DIR"

# Download
FILENAME=$(basename "$DOWNLOAD_URL")
cd /tmp
curl -LO "$DOWNLOAD_URL"

# Extract if compressed
if [[ "$FILENAME" == *.gz ]]; then
    gzip -d "$FILENAME"
    FILENAME="${FILENAME%.gz}"
fi

# Move to files directory
chmod +x "$FILENAME"
mv "$FILENAME" "${FILES_DIR}/mihomo-linux-${ARCH}"

echo "==> Downloaded to: ${FILES_DIR}/mihomo-linux-${ARCH}"
echo "==> Binary version:"
"${FILES_DIR}/mihomo-linux-${ARCH}" -v 2>/dev/null || echo "(Cannot run - may be for different arch)"
echo ""
echo "==> This binary will be bundled in offline builds."
echo "==> Add to .gitignore or git-lfs if you want to version it."
