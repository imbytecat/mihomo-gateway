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
      # Tarball (no privilege required - CI friendly)
      mihomo-gateway-tarball = 
        self.nixosConfigurations.mihomo-gateway.config.system.build.tarball;
      
      # VM image (requires KVM/privileged)
      mihomo-gateway-image = 
        self.nixosConfigurations.mihomo-gateway.config.system.build.image;
    };

    # Development shell
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        nil        # Nix LSP
        nixfmt-rfc-style   # Formatter
      ];
    };
  };
}
