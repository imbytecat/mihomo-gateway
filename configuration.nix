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
    "${modulesPath}/profiles/perlless.nix"
    "${modulesPath}/profiles/headless.nix"
    "${modulesPath}/profiles/image-based-appliance.nix"
  ];

  system.stateVersion = "25.11";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

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
  environment.systemPackages = with pkgs; [ micro ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDRTOo48gzzRGT+bF9dzJCFJu61YgsQVONFtxU9kTPIg"
    ];
  };
}
