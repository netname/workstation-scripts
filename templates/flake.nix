# flake.nix — Home Manager entry point
# Copy this file to ~/dotfiles/flake.nix in your PRIVATE dotfiles repo.
# Replace CHANGE_ME with your Linux username (the output of `whoami`).
#
# After editing:
#   nix run github:nix-community/home-manager -- switch --flake ~/dotfiles#CHANGE_ME
# On subsequent runs use the alias defined in home.nix:
#   hms
#
# See docs/1-Stack.md §1.4 for a full explanation of flake.nix vs flake.lock vs home.nix.
{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      homeConfigurations."CHANGE_ME" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
    };
}
