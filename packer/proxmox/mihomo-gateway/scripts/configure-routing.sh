#!/bin/bash
set -euo pipefail

echo "==> Configuring policy routing for TPROXY..."

# Create routing table entry if not exists
if ! grep -q "100 mihomo" /etc/iproute2/rt_tables 2>/dev/null; then
    echo "100 mihomo" >> /etc/iproute2/rt_tables
    echo "==> Added routing table 'mihomo' (100)"
fi

# Create networkd-dispatcher script for persistent routing
# This runs when network interfaces become routable
mkdir -p /etc/networkd-dispatcher/routable.d

cat > /etc/networkd-dispatcher/routable.d/50-mihomo-tproxy << 'EOF'
#!/bin/bash
# Configure policy routing for Mihomo TPROXY
# This script runs when network interfaces become routable

# Only run for the main interface
if [ "$IFACE" = "lo" ]; then
    exit 0
fi

# Add routing rule for marked packets (fwmark 1)
ip rule show | grep -q "fwmark 0x1" || ip rule add fwmark 1 table 100

# Add local route for TPROXY to work
ip route show table 100 | grep -q "local default" || ip route add local default dev lo table 100

logger "Mihomo TPROXY routing configured for $IFACE"
EOF

chmod +x /etc/networkd-dispatcher/routable.d/50-mihomo-tproxy
echo "==> Created networkd-dispatcher script"

# Also create ifupdown script for systems not using systemd-networkd
mkdir -p /etc/network/if-up.d

cat > /etc/network/if-up.d/mihomo-tproxy << 'EOF'
#!/bin/bash
# Configure policy routing for Mihomo TPROXY

# Skip loopback
[ "$IFACE" = "lo" ] && exit 0

# Add routing rule for marked packets
ip rule show | grep -q "fwmark 0x1" || ip rule add fwmark 1 table 100

# Add local route for TPROXY
ip route show table 100 | grep -q "local default" || ip route add local default dev lo table 100
EOF

chmod +x /etc/network/if-up.d/mihomo-tproxy
echo "==> Created ifupdown script"

# Apply routing immediately for the build
ip rule add fwmark 1 table 100 2>/dev/null || true
ip route add local default dev lo table 100 2>/dev/null || true

echo "==> Policy routing configured!"
ip rule show | grep mihomo || ip rule show | grep "fwmark 0x1" || echo "(Rules will be applied after reboot)"
