{
  description = "Mihomo Gateway - NixOS LXC 透明代理网关";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # NixOS Configuration
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./configuration.nix ];
      };

      # Build outputs
      packages.${system} = {
        default = self.nixosConfigurations.default.config.system.build.toplevel;
        tarball = self.nixosConfigurations.default.config.system.build.tarball;
      };

      # Development shell
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nil
          nixfmt
        ];
      };

      # Formatter
      formatter.${system} = pkgs.nixfmt;

      # Checks
      checks.${system}.build = self.packages.${system}.default;
    };
}
