{
  modulesPath,
  ...
}:

{
  imports = [
    ../modules/core.nix
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/profiles/headless.nix"
  ];

  boot.loader.systemd-boot = {
    enable = true;
    graceful = true;
  };
  # 镜像构建时无 efivarfs
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
}
