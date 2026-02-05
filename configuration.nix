# Mihomo 网关 - NixOS VM 配置
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
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/profiles/headless.nix"
  ];

  system.stateVersion = "25.11";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];

  # Appliance 模式优化
  nix.enable = false;

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.growPartition = true;

  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=tty0"
  ];

  systemd.services."serial-getty@ttyS0".enable = true;

  services.qemuGuest.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  networking = {
    hostName = "mihomo-gateway";
    useNetworkd = true;
    useDHCP = false;
    firewall.enable = false;
  };

  systemd.network.networks."50-ens" = {
    matchConfig.Name = "ens*";
    networkConfig.DHCP = "yes";
    dhcpV4Config.UseDNS = true;
    linkConfig.RequiredForOnline = "routable";
  };

  # DNS: Stubless Resolved - 从 DHCP 获取 DNS，禁用 stub listener 避免与 Mihomo 冲突
  services.resolved = {
    enable = true;
    settings.Resolve = {
      FallbackDNS = "";
      DNSSEC = "no";
      DNSStubListener = "no";
    };
  };
  environment.etc."resolv.conf".source = lib.mkForce "/run/systemd/resolve/resolv.conf";

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
