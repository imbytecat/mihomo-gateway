#!/bin/bash
set -euo pipefail

echo "==> Configuring nftables for TPROXY..."

# Create nftables include directory
mkdir -p /etc/nftables.d

# Copy mihomo nftables rules (already copied by Packer file provisioner)
if [ -f /tmp/files/nftables/mihomo.nft ]; then
    cp /tmp/files/nftables/mihomo.nft /etc/nftables.d/mihomo.nft
    chmod 644 /etc/nftables.d/mihomo.nft
    echo "==> Copied mihomo.nft to /etc/nftables.d/"
fi

# Update main nftables.conf to include our rules
if [ -f /etc/nftables.conf ]; then
    # Backup original
    cp /etc/nftables.conf /etc/nftables.conf.bak
fi

# Create new nftables.conf that includes our rules
cat > /etc/nftables.conf << 'EOF'
#!/usr/sbin/nft -f

# Flush all rules
flush ruleset

# Include Mihomo transparent proxy rules
include "/etc/nftables.d/mihomo.nft"
EOF

echo "==> Updated /etc/nftables.conf"

# Enable nftables service
systemctl enable nftables.service
echo "==> nftables service enabled"

# Test loading the rules
if nft -c -f /etc/nftables.conf; then
    echo "==> nftables configuration syntax OK"
else
    echo "ERROR: nftables configuration has syntax errors!"
    exit 1
fi

# Load rules (will fail if kernel modules not available in chroot, that's OK)
nft -f /etc/nftables.conf 2>/dev/null || echo "==> Rules will be loaded on boot"

echo "==> nftables configuration complete!"
