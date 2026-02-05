# Mihomo service + subscription management
{
  config,
  pkgs,
  lib,
  ...
}:

let
  constants = import ./constants.nix;
  inherit (constants) tproxyPort routingMark;

  stateDir = "/var/lib/mihomo";
  configFile = "${stateDir}/config.yaml";
  envFile = "/etc/mihomo/mihomo.env";
  tempConfig = "/tmp/mihomo-new.yaml";

  fallbackConfig = pkgs.writeText "mihomo-fallback.yaml" ''
    tproxy-port: ${toString tproxyPort}
    routing-mark: ${toString routingMark}
    allow-lan: true
    bind-address: "*"
    mode: direct
    log-level: info
    ipv6: false
    find-process-mode: "off"

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

  subscribeScript = pkgs.writeShellScript "mihomo-subscribe" ''
    set -euo pipefail

    if [ ! -f "${envFile}" ]; then
      echo "No subscription configured: ${envFile} not found"
      echo "Create it with: echo 'SUBSCRIPTION_URL=https://your-url' > ${envFile}"
      exit 0
    fi

    source "${envFile}"

    if [ -z "''${SUBSCRIPTION_URL:-}" ]; then
      echo "SUBSCRIPTION_URL not set in ${envFile}"
      exit 0
    fi

    echo "Fetching subscription..."

    if ! ${pkgs.curl}/bin/curl -fsSL --connect-timeout 30 --max-time 120 \
         -o "${tempConfig}" "$SUBSCRIPTION_URL"; then
      echo "ERROR: Failed to download subscription"
      exit 1
    fi

    ${pkgs.yq-go}/bin/yq -i '
      .tproxy-port = ${toString tproxyPort} |
      .routing-mark = ${toString routingMark} |
      .allow-lan = true |
      .find-process-mode = "off"
    ' "${tempConfig}"

    echo "Validating configuration..."
    if ! ${pkgs.mihomo}/bin/mihomo -t -f "${tempConfig}" 2>&1; then
      echo "ERROR: Configuration validation failed"
      rm -f "${tempConfig}"
      exit 1
    fi

    if [ -f "${configFile}" ]; then
      cp "${configFile}" "${configFile}.bak"
    fi

    mv "${tempConfig}" "${configFile}"
    chmod 600 "${configFile}"

    echo "Configuration updated"

    if systemctl is-active --quiet mihomo; then
      systemctl restart mihomo
    fi
  '';
in
{
  services.mihomo = {
    enable = true;
    configFile = configFile;
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 root root -"
    "d /etc/mihomo 0755 root root -"
  ];

  system.activationScripts.mihomo-config = ''
    if [ ! -f "${configFile}" ]; then
      cp ${fallbackConfig} ${configFile}
      chmod 600 ${configFile}
    fi
  '';

  systemd.services.mihomo-subscribe = {
    description = "Fetch and validate Mihomo subscription";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = subscribeScript;
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  systemd.timers.mihomo-subscribe = {
    description = "Periodic Mihomo subscription update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "6h";
      RandomizedDelaySec = "5min";
    };
  };

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
      StateDirectory = "mihomo";
    };
  };
}
