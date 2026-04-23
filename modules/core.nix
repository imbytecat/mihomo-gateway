{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./tproxy.nix
    ./mihomo.nix
  ];

  # 纯 flake 工作流
  nix.enable = true;
  nix.channel.enable = false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.nixPath = lib.mkForce [ ];
  # gateway 在国内网络，自己 rebuild 时走 SJTU；开发机 / CI 因为本机构建 + SCP 推送，无需配镜像
  nix.settings.substituters = [
    "https://mirror.sjtu.edu.cn/nix-channels/store"
    "https://cache.nixos.org/"
  ];

  system.stateVersion = "25.11";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" ];
  fonts.fontconfig.enable = false;

  networking = {
    hostName = "mihomo-gateway";
    useNetworkd = true;
    useDHCP = false;
    firewall.enable = false;
  };

  # 单臂拓扑，所有 ethernet 通吃
  systemd.network.networks."50-lan" = {
    matchConfig.Name = "en* eth*";
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
