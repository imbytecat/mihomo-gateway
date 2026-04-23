{
  description = "Mihomo Gateway - NixOS 透明代理网关";

  nixConfig = {
    substituters = [
      "https://mirror.sjtu.edu.cn/nix-channels/store"
      "https://cache.nixos.org/"
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      disko,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;

      vmConfig = self.nixosConfigurations.vm;
      version = self.shortRev or self.dirtyShortRev or "unknown";
    in
    {
      nixosConfigurations = {
        # qcow2 镜像构建目标（瘦身 profile：minimal + headless，无 nix）
        vm = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./profiles/vm.nix ];
        };

        # 物理机 / nixos-anywhere 目标（完整默认 + disko）
        bare-metal = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            disko.nixosModules.disko
            ./profiles/disko.nix
            ./profiles/bare-metal.nix
          ];
        };
      };

      packages.${system} = {
        default = self.packages.${system}.image;
        image = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          inherit pkgs lib;
          baseName = "mihomo-gateway-${version}";
          config = vmConfig.config;
          format = "qcow2-compressed";
          partitionTableType = "efi";
          diskSize = "auto";
          additionalSpace = "64M";
          copyChannel = false;
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          just
          nixd
          nixfmt
        ];
      };

      formatter.${system} = pkgs.nixfmt;

      checks.${system} = {
        vm = vmConfig.config.system.build.toplevel;
        bare-metal = self.nixosConfigurations.bare-metal.config.system.build.toplevel;
      };
    };
}
