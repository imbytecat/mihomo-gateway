{
  config,
  pkgs,
  lib,
  ...
}:

let
  constants = import ./constants.nix;
  inherit (constants) tproxyPort dnsPort routingMark;

  stateDir = "/var/lib/mihomo";
  configFile = "${stateDir}/config.yaml";
  envFile = "/etc/mihomo/mihomo.env";

  baseConfig = {
    tproxy-port = tproxyPort;
    routing-mark = routingMark;
    bind-address = "*";
    allow-lan = true;
    find-process-mode = "off";
    ipv6 = false;
    dns = {
      enable = true;
      listen = "0.0.0.0:${toString dnsPort}";
      ipv6 = false;
    };
  };

  fallbackConfig = baseConfig // {
    mode = "direct";
    log-level = "info";
    dns = baseConfig.dns // {
      enhanced-mode = "redir-host";
      default-nameserver = [ "223.5.5.5" "119.29.29.29" ];
      nameserver = [
        "https://dns.alidns.com/dns-query#h3=true"
        "https://doh.pub/dns-query"
      ];
    };
  };

  yamlFormat = pkgs.formats.yaml { };
  baseConfigYaml = yamlFormat.generate "base-config.yaml" baseConfig;
  fallbackConfigYaml = yamlFormat.generate "fallback.yaml" fallbackConfig;

  subscribeScript = pkgs.writeShellScript "mihomo-subscribe" ''
    set -euo pipefail
    umask 077

    if [ ! -f "${envFile}" ]; then
      echo "No subscription configured: ${envFile} not found"
      echo "Create it with: echo 'SUBSCRIPTION_URL=https://your-url' > ${envFile}"
      echo "Optional: add SECRET=your-secret for API authentication"
      exit 0
    fi

    source "${envFile}"

    if [ -z "''${SUBSCRIPTION_URL:-}" ]; then
      echo "SUBSCRIPTION_URL not set in ${envFile}"
      exit 0
    fi

    tmp="$(mktemp -p "${stateDir}" .mihomo-config.XXXXXX.yaml)"
    new="${configFile}.new"

    cleanup() {
      rm -f "$tmp" "$new"
    }
    trap cleanup EXIT

    echo "Fetching subscription..."
    ${pkgs.curlMinimal}/bin/curl -fsSL --connect-timeout 30 --max-time 120 \
      --retry 3 --retry-delay 2 --retry-all-errors \
      -o "$tmp" "$SUBSCRIPTION_URL"

    ${pkgs.yq-go}/bin/yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' \
      "$tmp" "${baseConfigYaml}" > "$tmp.merged"
    mv "$tmp.merged" "$tmp"

    if [ -n "''${SECRET:-}" ]; then
      ${pkgs.yq-go}/bin/yq -i '.secret = "'"$SECRET"'"' "$tmp"
    fi

    echo "Validating configuration..."
    ${pkgs.mihomo}/bin/mihomo -t -f "$tmp" >/dev/null

    if [ -f "${configFile}" ] && ${pkgs.diffutils}/bin/cmp -s "$tmp" "${configFile}"; then
      echo "No changes; skip restart"
      exit 0
    fi

    ${pkgs.coreutils}/bin/install -m 600 "$tmp" "$new"
    if [ -f "${configFile}" ]; then
      ${pkgs.coreutils}/bin/cp -f "${configFile}" "${configFile}.bak"
    fi
    ${pkgs.coreutils}/bin/mv -f "$new" "${configFile}"

    echo "Configuration updated; restarting mihomo"
    systemctl restart mihomo
  '';
in
{
  services.mihomo = {
    enable = true;
    configFile = configFile;
  };

  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 root root -"
    "d /etc/mihomo 0750 root root -"
  ];

  system.activationScripts.mihomo-config = ''
    if [ ! -f "${configFile}" ]; then
      cp ${fallbackConfigYaml} ${configFile}
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

      UMask = "0077";
      PrivateTmp = true;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      SystemCallArchitectures = "native";

      ReadWritePaths = [ stateDir ];
      ReadOnlyPaths = [ envFile ];
    };
  };

  systemd.timers.mihomo-subscribe = {
    description = "Periodic Mihomo subscription update";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "6h";
      RandomizedDelaySec = "5min";
      Persistent = true;
    };
  };

  systemd.services.mihomo = {
    after = [
      "network.target"
      "nftables.service"
    ];
    wants = [ "nftables.service" ];
    requires = [ "nftables.service" ];

    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";

      AmbientCapabilities = lib.mkForce [ "CAP_NET_ADMIN" ];
      CapabilityBoundingSet = lib.mkForce [ "CAP_NET_ADMIN" ];
      PrivateUsers = lib.mkForce false;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      LockPersonality = true;
      RestrictSUIDSGID = true;

      LimitNOFILE = 1000000;
      StateDirectory = "mihomo";
    };
  };
}
