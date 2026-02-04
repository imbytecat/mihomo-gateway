# Mihomo TPROXY Transparent Proxy Module
{ config, pkgs, lib, ... }:

let
  mihomoPort = 7894;      # TPROXY port
  routingMark = 6666;     # Routing mark for bypass
  fwmark = 1;             # Fwmark for policy routing
in
{
  # ============================================
  # Mihomo Service
  # ============================================
  services.mihomo = {
    enable = true;
    # configFile will be managed separately (contains secrets)
    # Use: /etc/mihomo/config.yaml
  };

  # Override systemd service for TPROXY capabilities
  systemd.services.mihomo = {
    after = [ "network.target" "nftables.service" ];
    wants = [ "nftables.service" ];
    serviceConfig = {
      CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
      AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
      LimitNOFILE = 1000000;
    };
  };

  # ============================================
  # Kernel Parameters (sysctl)
  # ============================================
  boot.kernel.sysctl = {
    # Enable IP forwarding
    "net.ipv4.ip_forward" = 1;

    # Disable reverse path filtering (required for TPROXY)
    "net.ipv4.conf.all.rp_filter" = 0;
    "net.ipv4.conf.default.rp_filter" = 0;

    # Disable ICMP redirects
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
  };

  # ============================================
  # nftables TPROXY Rules
  # ============================================
  networking.nftables = {
    enable = true;
    ruleset = ''
      table inet mihomo {
        set bypass {
          type ipv4_addr
          flags interval
          elements = {
            127.0.0.0/8,
            10.0.0.0/8,
            172.16.0.0/12,
            192.168.0.0/16,
            169.254.0.0/16,
            224.0.0.0/4
          }
        }

        chain prerouting {
          type filter hook prerouting priority mangle; policy accept;
          meta mark ${toString routingMark} return
          ip daddr @bypass return
          meta l4proto { tcp, udp } tproxy to :${toString mihomoPort} meta mark set ${toString fwmark}
        }

        chain output {
          type route hook output priority mangle; policy accept;
          meta mark ${toString routingMark} return
          ip daddr @bypass return
          meta l4proto { tcp, udp } meta mark set ${toString fwmark}
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
          Table = 100;
          Priority = 100;
        }
      ];
      routes = [
        {
          Destination = "0.0.0.0/0";
          Type = "local";
          Table = 100;
        }
      ];
    };
  };

  # ============================================
  # Mihomo Config Template
  # ============================================
  environment.etc."mihomo/config.yaml".text = ''
    # Mihomo Configuration Template
    # Edit this file and add your proxy configuration

    mixed-port: 7890
    tproxy-port: ${toString mihomoPort}
    routing-mark: ${toString routingMark}

    allow-lan: true
    bind-address: "*"
    mode: rule
    log-level: info

    dns:
      enable: true
      listen: 0.0.0.0:53
      enhanced-mode: fake-ip
      fake-ip-range: 198.18.0.1/16
      default-nameserver:
        - 8.8.8.8
      nameserver:
        - https://dns.alidns.com/dns-query

    proxies: []

    proxy-groups:
      - name: PROXY
        type: select
        proxies:
          - DIRECT

    rules:
      - IP-CIDR,127.0.0.0/8,DIRECT
      - IP-CIDR,10.0.0.0/8,DIRECT
      - IP-CIDR,172.16.0.0/12,DIRECT
      - IP-CIDR,192.168.0.0/16,DIRECT
      - MATCH,DIRECT
  '';
}
