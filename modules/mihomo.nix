# Mihomo Service + Subscription Module
# Handles: mihomo service + subscription update + fallback config
{
  config,
  pkgs,
  lib,
  ...
}:

let
  # Import shared constants
  constants = import ./constants.nix;
  inherit (constants) tproxyPort routingMark;

  # Paths (relative to StateDirectory)
  stateDir = "/var/lib/mihomo"; # systemd StateDirectory
  configFile = "${stateDir}/config.yaml";
  envFile = "/etc/mihomo/mihomo.env";
  tempConfig = "/tmp/mihomo-new.yaml";

  # Fallback config (used when no subscription or download fails)
  fallbackConfig = pkgs.writeText "mihomo-fallback.yaml" ''
    # Mihomo Fallback Configuration
    # This is used when subscription is unavailable

    # TPROXY settings (must match tproxy.nix)
    tproxy-port: ${toString tproxyPort}
    routing-mark: ${toString routingMark}

    allow-lan: true
    bind-address: "*"
    mode: direct
    log-level: info
    ipv6: false
    find-process-mode: "off"

    # DNS is required even in direct mode for fake-ip resolution
    dns:
      enable: true
      listen: 0.0.0.0:53
      ipv6: false
      enhanced-mode: fake-ip
      fake-ip-range: 198.18.0.1/16
      default-nameserver:
        - 223.5.5.5
        - 119.29.29.29
      nameserver:
        - https://dns.alidns.com/dns-query#h3=true
        - https://doh.pub/dns-query
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

    # Download to temp file (atomic write pattern)
    if ! ${pkgs.curl}/bin/curl -fsSL --connect-timeout 30 --max-time 120 \
         -o "${tempConfig}" "$SUBSCRIPTION_URL"; then
      echo "ERROR: Failed to download subscription"
      exit 1
    fi

    # Force inject TPROXY required fields (override subscription values)
    echo "Injecting TPROXY configuration..."
    ${pkgs.yq-go}/bin/yq -i '
      .tproxy-port = ${toString tproxyPort} |
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

    # Atomic replace
    mv "${tempConfig}" "${configFile}"
    chmod 600 "${configFile}"

    echo "Configuration updated successfully"

    # Restart mihomo if running
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

  # Create config directories
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 root root -"
    "d /etc/mihomo 0755 root root -"
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
      # Use StateDirectory for config
      StateDirectory = "mihomo";
    };
  };
}
