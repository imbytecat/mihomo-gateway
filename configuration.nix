# Mihomo Gateway - NixOS Configuration
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
  ];

  system.stateVersion = "24.11";

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

  environment.systemPackages = with pkgs; [ vim ];

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  users.users.root.hashedPassword = null;
}
