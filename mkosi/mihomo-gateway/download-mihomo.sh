#!/bin/bash
set -euo pipefail

# Download Mihomo binary for mkosi build

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="${1:-amd64}"
OUTPUT="${SCRIPT_DIR}/mkosi.extra/usr/local/bin/mihomo"

echo "==> Downloading Mihomo for: linux-${ARCH}"

DOWNLOAD_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest \
    | grep "browser_download_url.*mihomo-linux-${ARCH}-v" \
    | grep -v "alpha\|compatible" \
    | head -1 \
    | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "ERROR: Could not find download URL"
    exit 1
fi

echo "==> URL: $DOWNLOAD_URL"

cd /tmp
FILENAME=$(basename "$DOWNLOAD_URL")
curl -LO "$DOWNLOAD_URL"

if [[ "$FILENAME" == *.gz ]]; then
    gzip -d "$FILENAME"
    FILENAME="${FILENAME%.gz}"
fi

chmod +x "$FILENAME"
mv "$FILENAME" "$OUTPUT"

echo "==> Saved to: $OUTPUT"
