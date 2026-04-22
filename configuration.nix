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

  nix.enable = false;
  fonts.fontconfig.enable = false;

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
      # rp_filter 必须逐接口禁用：sysctl all/default 覆盖不了已存在接口的默认值 2
      IPv4ReversePathFilter = "no";
    };
    dhcpV4Config.UseDNS = true;
    linkConfig.RequiredForOnline = "routable";
  };

  # 禁用 stub 监听，避免和 Mihomo DNS (1053) 抢 53
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
