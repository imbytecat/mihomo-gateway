{
  modulesPath,
  ...
}:

{
  imports = [
    ../modules/core.nix
    # qcow2 体积敏感，三个 profile 都是为了瘦身：
    # qemu-guest 加载 guest agent + virtio 驱动；minimal 砍 doc/nixos-rebuild/... ；headless 砍 X/终端
    "${modulesPath}/profiles/qemu-guest.nix"
    "${modulesPath}/profiles/minimal.nix"
    "${modulesPath}/profiles/headless.nix"
  ];

  # appliance 内不跑 nix，砍掉 nix + channels 能省几百 MB
  nix.enable = false;

  boot.loader.systemd-boot = {
    enable = true;
    graceful = true;
  };
  # 镜像构建时没有 efivarfs，必须关闭
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
