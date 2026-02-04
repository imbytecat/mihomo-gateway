# Mihomo Gateway - NixOS Configuration
{ config, pkgs, lib, modulesPath, ... }:

{
  imports = [
    ./mihomo.nix
    # Tarball output (no privilege required)
    "${modulesPath}/installer/cd-dvd/channel.nix"
    # VM image format modules (requires privilege)
    "${modulesPath}/image/repart.nix"
  ];

  # System
  system.stateVersion = "24.11";

  # Image configuration
  image.repart = {
    name = "mihomo-gateway";
    partitions = {
      "esp" = {
        contents = {
          "/EFI/BOOT/BOOT*.EFI".source = "${config.system.build.toplevel}/EFI/BOOT/";
        };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = "256M";
        };
      };
      "root" = {
        storePaths = [ config.system.build.toplevel ];
        repartConfig = {
          Type = "root";
          Format = "ext4";
          Label = "nixos";
          Minimize = "guess";
        };
      };
    };
  };

  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # Networking
  networking = {
    hostName = "mihomo-gateway";
    useDHCP = true;
    firewall.enable = false;  # We use nftables directly
  };

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
