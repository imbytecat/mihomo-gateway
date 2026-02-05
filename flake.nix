{
  description = "Mihomo Gateway - NixOS VM 透明代理网关";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      nixosConfig = self.nixosConfigurations.default;
    in
    {
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };

      packages.${system} = {
        default = nixosConfig.config.system.build.toplevel;
        image = import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
          inherit pkgs lib;
          config = nixosConfig.config;
          format = "qcow2-compressed";
          partitionTableType = "efi";
          diskSize = "auto";
          additionalSpace = "64M";
          copyChannel = false;
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nil
          nixfmt
        ];
      };

      formatter.${system} = pkgs.nixfmt;

      checks.${system}.build = self.packages.${system}.default;
    };
}
