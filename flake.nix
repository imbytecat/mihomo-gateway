{
  description = "Mihomo Gateway - NixOS module: 透明代理网关 (Mihomo + nftables TPROXY)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
    in
    {
      nixosModules = {
        default = ./modules;
        mihomo-gateway = ./modules;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixd
          nixfmt
        ];
      };

      formatter.${system} = pkgs.nixfmt;

      # 最小 host evaluate module 能否 build；只验集成，不构建镜像
      checks.${system}.module =
        (lib.nixosSystem {
          inherit system;
          modules = [
            self.nixosModules.default
            {
              boot.loader.systemd-boot.enable = true;
              boot.loader.efi.canTouchEfiVariables = false;
              fileSystems."/" = {
                device = "none";
                fsType = "tmpfs";
              };
              fileSystems."/boot" = {
                device = "none";
                fsType = "vfat";
              };
              system.stateVersion = "25.11";
              networking.hostName = "mihomo-gateway-check";
            }
          ];
        }).config.system.build.toplevel;
    };
}
