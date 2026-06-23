# flake.nix — Home Manager entry point
# Copy this file to ~/dotfiles/flake.nix in your PRIVATE dotfiles repo.
# Replace CHANGE_ME with your Linux username (the output of `whoami`).
#
# After editing:
#   nix run github:nix-community/home-manager -- switch --flake ~/dotfiles#CHANGE_ME
# On subsequent runs use the alias defined in hosts/workstation.nix:
#   hms
#
# See docs/explanation/stack-architecture.md for the Home Manager/Nix model.
{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, sops-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      mkHome = modules:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            sops-nix.homeManagerModules.sops
          ] ++ modules;
        };
    in {
      homeConfigurations = {
        # Compatibility target used by the bootstrap script.
        "CHANGE_ME" = mkHome [ ./hosts/workstation.nix ];

        # Explicit host profile for the multi-machine layout.
        "CHANGE_ME@workstation" = mkHome [ ./hosts/workstation.nix ];
      };
    };
}
