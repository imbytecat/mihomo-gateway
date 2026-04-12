# Mihomo 网关 - NixOS VM 配置
{
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

  # 精简系统：禁用不需要的功能
  nix.enable = false;
  fonts.fontconfig.enable = false;

  # 使用 systemd-boot 替代 GRUB (更轻量)
  boot.loader.systemd-boot = {
    enable = true;
    graceful = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;
  boot.growPartition = true;

  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "console=tty0"
  ];

  services.qemuGuest.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    autoResize = true;
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  networking = {
    hostName = "mihomo-gateway";
    useNetworkd = true;
    useDHCP = false;
    firewall.enable = false;
  };

  systemd.network.networks."50-ens" = {
    matchConfig.Name = "ens*";
    networkConfig = {
      DHCP = "yes";
      # TPROXY 必需：rp_filter 有效值 = max(conf.all, conf.INTERFACE)，
      # NixOS 内核给已存在接口默认 rp_filter=2，sysctl 的 all/default 无法覆盖。
      IPv4ReversePathFilter = "no";
    };
    dhcpV4Config.UseDNS = true;
    linkConfig.RequiredForOnline = "routable";
  };

  # DNS：从 DHCP 获取上游 DNS，禁用 stub 监听避免与 Mihomo 端口冲突
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
  environment.systemPackages = with pkgs; [
    micro
    curlMinimal
    yq-go
    mihomo
  ];

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
