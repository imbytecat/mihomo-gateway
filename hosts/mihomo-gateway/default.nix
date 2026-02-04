# Mihomo Gateway - NixOS Configuration
{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    ./mihomo.nix
    # LXC container support (no privilege required)
    "${modulesPath}/virtualisation/lxc-container.nix"
  ];

  # System
  system.stateVersion = "24.11";

  # Networking
  networking = {
    hostName = "mihomo-gateway";
    useDHCP = true;
    firewall.enable = false;  # We use nftables directly
    # Use traditional resolv.conf (LXC uses host's DNS)
    useHostResolvConf = lib.mkForce true;
  };

  # Disable systemd-resolved (conflicts with useHostResolvConf)
  services.resolved.enable = false;

  # Timezone
  time.timeZone = "Asia/Shanghai";

  # Base packages
  environment.systemPackages = with pkgs; [
    curl
    htop
    vim
  ];

  # SSH
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";  # TODO: Adjust for production
  };

  # Root user (for initial access)
  users.users.root.initialPassword = "nixos";
}
