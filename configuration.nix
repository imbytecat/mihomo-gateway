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
    # LXC container support (no privilege required)
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  # System
  system.stateVersion = "24.11";

  # Networking (use systemd-networkd, required by lxc-container.nix)
  networking = {
    hostName = "mihomo-gateway";
    useNetworkd = true;
    useDHCP = false; # Managed by networkd below
    firewall.enable = false; # We use nftables directly
    # Use traditional resolv.conf (LXC uses host's DNS)
    useHostResolvConf = lib.mkForce true;
  };

  # DHCP via networkd
  systemd.network.networks."50-eth" = {
    matchConfig.Name = "eth*";
    networkConfig.DHCP = "yes";
  };

  # Disable systemd-resolved (conflicts with useHostResolvConf)
  services.resolved.enable = false;

  # Timezone
  time.timeZone = "Asia/Shanghai";

  # Base packages (minimal for gateway)
  environment.systemPackages = with pkgs; [
    vim
  ];

  # SSH (no default password, key-only recommended)
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password"; # Key-only
      PasswordAuthentication = false;
    };
  };

  # Root user (no default password - inject keys via deployment)
  users.users.root = {
    # No password set - use SSH keys
    hashedPassword = null;
  };
}
