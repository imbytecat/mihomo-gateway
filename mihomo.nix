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
}
