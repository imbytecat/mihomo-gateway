# Shared Constants for Mihomo Gateway
# Single source of truth for TPROXY configuration
{
  # TPROXY port (Mihomo listens here)
  tproxyPort = 7894;

  # Routing mark for Mihomo's outbound traffic (bypass nftables)
  routingMark = 6666;

  # Fwmark for policy routing
  fwmark = 1;

  # Policy routing table ID
  routingTable = 100;
}
