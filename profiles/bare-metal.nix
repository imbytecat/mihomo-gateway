{
  ...
}:

{
  imports = [
    ../modules/core.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # KVM/QEMU 目标需要；stock initrd 默认只有 ahci/nvme/sata，虚拟磁盘会看不到导致 boot 后进 emergency
  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
    "virtio_net"
  ];
}
