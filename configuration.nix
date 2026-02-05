# Mihomo 网关 - NixOS 配置
{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:

{
  imports = [
    ./modules/tproxy.nix
    ./modules/mihomo.nix
    "${modulesPath}/virtualisation/lxc-container.nix"
    "${modulesPath}/profiles/minimal.nix"
  ];

  system.stateVersion = "25.11";

  # 镜像优化
  documentation.enable = false;
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  environment.defaultPackages = lib.mkForce [ ];
  programs.command-not-found.enable = false;
  nix.enable = false;

  networking = {
    hostName = "mihomo-gateway";
    useNetworkd = true;
    useDHCP = false;
    firewall.enable = false;
    useHostResolvConf = lib.mkForce true;
  };

  systemd.network.networks."50-eth" = {
    matchConfig.Name = "eth*";
    networkConfig.DHCP = "yes";
  };

  services.resolved.enable = false;

  time.timeZone = "Asia/Shanghai";

  environment.systemPackages = with pkgs; [ nano ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.hashedPassword = null;
}
