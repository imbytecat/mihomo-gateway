# Mihomo TPROXY Transparent Proxy Module
{
  config,
  pkgs,
  lib,
  ...
}:

let
  mihomoPort = 7894; # TPROXY port
  routingMark = 6666; # Routing mark for bypass
  fwmark = 1; # Fwmark for policy routing

  # Paths
  configDir = "/etc/mihomo";
  configFile = "${configDir}/config.yaml";
  envFile = "${configDir}/subscription.env";
  tempConfig = "/tmp/mihomo-new.yaml";

  # Fallback config (used when no subscription or download fails)
  fallbackConfig = pkgs.writeText "mihomo-fallback.yaml" ''
    # Mihomo Fallback Configuration
    # This is used when subscription is unavailable

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

  # Subscription update script with validation
  subscribeScript = pkgs.writeShellScript "mihomo-subscribe" ''
    set -euo pipefail

    # Load subscription URL from environment file
    if [ ! -f "${envFile}" ]; then
      echo "No subscription configured: ${envFile} not found"
      echo "Create it with: echo 'SUBSCRIPTION_URL=https://your-subscription-url' > ${envFile}"
      exit 0
    fi

    source "${envFile}"

    if [ -z "''${SUBSCRIPTION_URL:-}" ]; then
      echo "SUBSCRIPTION_URL not set in ${envFile}"
      exit 0
    fi

    echo "Fetching subscription from: ''${SUBSCRIPTION_URL:0:50}..."

    # Download to temp file
    if ! ${pkgs.curl}/bin/curl -fsSL --connect-timeout 30 --max-time 120 \
         -o "${tempConfig}" "$SUBSCRIPTION_URL"; then
      echo "ERROR: Failed to download subscription"
      exit 1
    fi

    # Force inject TPROXY required fields (override subscription values)
    echo "Injecting TPROXY configuration..."
    ${pkgs.yq-go}/bin/yq -i '
      .tproxy-port = ${toString mihomoPort} |
      .routing-mark = ${toString routingMark} |
      .allow-lan = true |
      .find-process-mode = "off"
    ' "${tempConfig}"

    # Validate config with mihomo -t
    echo "Validating configuration..."
    if ! ${pkgs.mihomo}/bin/mihomo -t -f "${tempConfig}" 2>&1; then
      echo "ERROR: Configuration validation failed"
      rm -f "${tempConfig}"
      exit 1
    fi

    echo "Validation passed, applying new configuration..."

    # Backup current config
    if [ -f "${configFile}" ]; then
      cp "${configFile}" "${configFile}.bak"
    fi

    # Apply new config
    mv "${tempConfig}" "${configFile}"
    chmod 600 "${configFile}"

    echo "Configuration updated successfully"

    # Reload mihomo if running
    if systemctl is-active --quiet mihomo; then
      echo "Restarting mihomo service..."
      systemctl restart mihomo
    fi
  '';
in
{
  # ============================================
  # Mihomo Service
  # ============================================
  services.mihomo = {
    enable = true;
    configFile = configFile;
  };

  # Create config directory and fallback config
  systemd.tmpfiles.rules = [
    "d ${configDir} 0755 root root -"
  ];

  # Ensure fallback config exists on activation
  system.activationScripts.mihomo-config = ''
    if [ ! -f "${configFile}" ]; then
      cp ${fallbackConfig} ${configFile}
      chmod 600 ${configFile}
    fi
  '';

  # ============================================
  # Subscription Update Service
  # ============================================
  systemd.services.mihomo-subscribe = {
    description = "Fetch and validate Mihomo subscription";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = subscribeScript;
      # Retry on failure
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  # Timer for periodic subscription updates
  systemd.timers.mihomo-subscribe = {
    description = "Periodic Mihomo subscription update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # First run 2 minutes after boot
      OnBootSec = "2min";
      # Then every 6 hours
      OnUnitActiveSec = "6h";
      # Randomize to avoid thundering herd
      RandomizedDelaySec = "5min";
    };
  };

  # Override systemd service for TPROXY capabilities
  systemd.services.mihomo = {
    after = [
      "network.target"
      "nftables.service"
    ];
    wants = [ "nftables.service" ];
    serviceConfig = {
      CapabilityBoundingSet = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
        "CAP_NET_BIND_SERVICE"
      ];
      AmbientCapabilities = [
        "CAP_NET_ADMIN"
        "CAP_NET_RAW"
        "CAP_NET_BIND_SERVICE"
      ];
      LimitNOFILE = 1000000;
    };
  };

  # ============================================\r
  # Kernel Parameters (sysctl)\r
  # ============================================\r
  boot.kernel.sysctl = {\r
    # Enable IP forwarding\r
    "net.ipv4.ip_forward" = 1;\r
\r
    # Disable reverse path filtering (required for TPROXY)\r
    "net.ipv4.conf.all.rp_filter" = 0;\r
    "net.ipv4.conf.default.rp_filter" = 0;\r
\r
    # Required for TPROXY to work correctly\r
    "net.ipv4.conf.all.src_valid_mark" = 1;\r
    "net.ipv4.conf.default.src_valid_mark" = 1;\r
\r
    # Disable ICMP redirects\r
    "net.ipv4.conf.all.send_redirects" = 0;\r
    "net.ipv4.conf.default.send_redirects" = 0;\r
  };\r

  # ============================================\r
  # nftables TPROXY Rules\r
  # ============================================\r
  networking.nftables = {\r
    enable = true;\r
    ruleset = ''\r
      table inet mihomo {\r
        # IPv4 bypass addresses\r
        set bypass4 {\r
          type ipv4_addr\r
          flags interval\r
          elements = {\r
            0.0.0.0/8,         # Current network\r
            10.0.0.0/8,        # Private Class A\r
            100.64.0.0/10,     # CGNAT\r
            127.0.0.0/8,       # Loopback\r
            169.254.0.0/16,    # Link-local\r
            172.16.0.0/12,     # Private Class B\r
            192.168.0.0/16,    # Private Class C\r
            224.0.0.0/4,       # Multicast\r
            240.0.0.0/4,       # Reserved\r
            255.255.255.255/32 # Broadcast\r
          }\r
        }\r
\r
        # DNS redirect: redirect all DNS queries to mihomo\r
        chain prerouting_dns {\r
          type nat hook prerouting priority dstnat; policy accept;\r
          fib daddr type local return\r
          meta l4proto { tcp, udp } th dport 53 redirect to :53\r
        }\r
\r
        # TPROXY for TCP and UDP (except DNS which is already handled)\r
        chain prerouting {\r
          type filter hook prerouting priority mangle; policy accept;\r
          # Bypass mihomo's own traffic (routing-mark)\r
          meta mark ${toString routingMark} return\r
          # Bypass local/broadcast/multicast destinations\r
          fib daddr type { local, broadcast, multicast } return\r
          # Bypass private addresses\r
          ip daddr @bypass4 return\r
          # Skip DNS (already redirected to mihomo:53)\r
          meta l4proto { tcp, udp } th dport 53 return\r
          # TPROXY everything else\r
          meta l4proto { tcp, udp } tproxy to :${toString mihomoPort} meta mark set ${toString fwmark}\r
        }\r
\r
        # Handle locally generated traffic\r
        chain output {\r
          type route hook output priority mangle; policy accept;\r
          # Bypass loopback\r
          oifname "lo" return\r
          # Bypass mihomo's own traffic\r
          meta mark ${toString routingMark} return\r
          # Bypass local destinations\r
          fib daddr type { local, broadcast, multicast } return\r
          # Bypass private addresses\r
          ip daddr @bypass4 return\r
          # Skip DNS and mihomo ports\r
          meta l4proto { tcp, udp } th dport 53 return\r
          meta l4proto tcp th sport ${toString mihomoPort} return\r
          # Mark for policy routing\r
          meta l4proto { tcp, udp } meta mark set ${toString fwmark}\r
        }\r
      }\r
    '';\r
  };\r

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
}
