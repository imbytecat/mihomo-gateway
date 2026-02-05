{
  description = "Mihomo Gateway - NixOS VM 透明代理网关";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };

      packages.${system} = {
        default = self.nixosConfigurations.default.config.system.build.toplevel;
        image = self.nixosConfigurations.default.config.system.build.image;
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
