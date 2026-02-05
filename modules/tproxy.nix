# TPROXY Gateway Module
# Handles: sysctl + policy routing + nftables
{ config, lib, ... }:

let
  # Import shared constants
  constants = import ./constants.nix;
  inherit (constants)
    tproxyPort
    routingMark
    fwmark
    routingTable
    ;
in
{
  # ============================================
  # Kernel Parameters (sysctl)
  # ============================================
  boot.kernel.sysctl = {
    # Enable IP forwarding
    "net.ipv4.ip_forward" = 1;

    # Disable reverse path filtering (required for TPROXY)
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;

    # Required for TPROXY to work correctly
    "net.ipv4.conf.all.src_valid_mark" = 1;
    "net.ipv4.conf.default.src_valid_mark" = 1;

    # Disable ICMP redirects
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
  };

  # ============================================
  # nftables TPROXY Rules (PREROUTING only)
  # ============================================
  networking.nftables = {
    enable = true;
    ruleset = ''
      table inet mihomo {
        # IPv4 bypass addresses
        set bypass4 {
          type ipv4_addr
          flags interval
          elements = {
            10.0.0.0/8,        # Private Class A
            100.64.0.0/10,     # CGNAT
            127.0.0.0/8,       # Loopback
            169.254.0.0/16,    # Link-local
            172.16.0.0/12,     # Private Class B
            192.168.0.0/16,    # Private Class C
            224.0.0.0/4,       # Multicast
            240.0.0.0/4        # Reserved
          }
        }

        # TPROXY chain (forwarded traffic only)
        chain prerouting {
          type filter hook prerouting priority mangle; policy accept;

          # Anti-loop: bypass mihomo's own traffic (routing-mark)
          meta mark ${toString routingMark} return

          # Bypass local/broadcast/multicast destinations
          fib daddr type { local, broadcast, multicast } return

          # Bypass private addresses
          ip daddr @bypass4 return

          # TPROXY TCP and UDP
          meta l4proto { tcp, udp } tproxy to :${toString tproxyPort} meta mark set ${toString fwmark}
        }
      }
    '';
  };

  # ============================================
  # Policy Routing (for TPROXY)
  # ============================================
  networking.iproute2.enable = true;

  # Add routing table and rules via systemd-networkd
  systemd.network = {
    enable = true;
    networks."99-tproxy" = {
      matchConfig.Name = "lo";
      routingPolicyRules = [
        {
          FirewallMark = fwmark;
          Table = routingTable;
          Priority = 100;
        }
      ];
      routes = [
        {
          Destination = "0.0.0.0/0";
          Type = "local";
          Table = routingTable;
        }
      ];
    };
  };
}
