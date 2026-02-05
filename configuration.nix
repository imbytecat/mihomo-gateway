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
    "${modulesPath}/virtualisation/proxmox-lxc.nix"
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/profiles/perlless.nix"
    "${modulesPath}/profiles/headless.nix"
    "${modulesPath}/profiles/image-based-appliance.nix"
  ];

  system.stateVersion = "25.11";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  # 使用 NixOS 管理 hostname，不使用 PVE 的
  proxmoxLXC.manageHostName = true;
  networking = {
    hostName = "mihomo-gateway";
    firewall.enable = false;
    useHostResolvConf = lib.mkForce true;  # 使用宿主机 DNS
  };

  # 网络由 proxmox-lxc.nix 自动配置 (systemd-networkd + DHCP)
  # 添加 eth* 匹配规则
  systemd.network.networks."50-eth" = {
    matchConfig.Name = "eth*";
    networkConfig.DHCP = "yes";
  };

  services.resolved.enable = false;
  time.timeZone = "Asia/Shanghai";
  environment.systemPackages = with pkgs; [ micro ];

  # openssh 由 proxmox-lxc.nix 默认启用，只需配置认证
  services.openssh.settings = {
    PermitRootLogin = "prohibit-password";
    PasswordAuthentication = false;
  };

  users.users.root = {
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDRTOo48gzzRGT+bF9dzJCFJu61YgsQVONFtxU9kTPIg"
    ];
  };
}
