#!/bin/bash
set -euo pipefail

echo "==> Configuring sysctl for transparent proxy..."

# Create sysctl configuration file
cat > /etc/sysctl.d/99-mihomo.conf << 'EOF'
# Mihomo TPROXY transparent proxy settings

# Enable IP forwarding
net.ipv4.ip_forward = 1

# Disable reverse path filtering (required for TPROXY)
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0

# Disable ICMP redirects (security + prevents routing issues)
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0

# Optional: Increase connection tracking limits for high traffic
# net.netfilter.nf_conntrack_max = 1000000
EOF

echo "==> Created /etc/sysctl.d/99-mihomo.conf"

# Apply sysctl settings
sysctl --system

echo "==> Sysctl configuration applied!"
echo "==> IP forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo "==> rp_filter (all): $(cat /proc/sys/net/ipv4/conf/all/rp_filter)"
