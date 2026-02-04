{
  description = "Personal IaC - NixOS Infrastructure";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    # NixOS Configurations
    nixosConfigurations = {
      mihomo-gateway = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./hosts/mihomo-gateway ];
      };
    };

    # Build outputs
    packages.${system} = {
      # LXC tarball (no privilege required - CI friendly)
      mihomo-gateway-tarball = 
        self.nixosConfigurations.mihomo-gateway.config.system.build.tarball;
    };

    # Development shell
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        nil        # Nix LSP
        nixfmt-rfc-style   # Formatter
      ];
    };

    # Formatter (nix fmt)
    formatter.${system} = pkgs.nixfmt-rfc-style;

    # Checks (nix flake check)
    checks.${system} = {
      mihomo-gateway = self.nixosConfigurations.mihomo-gateway.config.system.build.toplevel;
    };
  };
}
