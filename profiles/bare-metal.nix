{
  ...
}:

{
  imports = [
    ../modules/core.nix
  ];

  # 物理机 / nixos-anywhere 目标机：保留 nix，后续可 nixos-rebuild switch
  # 不引入 minimal/headless，保持完整默认以便调试
  nix.enable = true;

  boot.loader.systemd-boot.enable = true;
  # 物理机安装 / rebuild 后需要写 EFI 变量更新启动项
  boot.loader.efi.canTouchEfiVariables = true;
}
