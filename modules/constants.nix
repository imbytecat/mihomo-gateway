# Shared constants (single source of truth)
{
  tproxyPort = 7894;

  # Single mark value used for both:
  # - nftables: set on intercepted packets for policy routing
  # - mihomo: routing-mark to bypass interception (avoid loops)
  routingMark = 6666;

  routingTable = 100;
}
