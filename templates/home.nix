# home.nix — compatibility wrapper
# Copy this file to ~/dotfiles/home.nix in your PRIVATE dotfiles repo.
#
# Apply changes:   hms   (alias defined in hosts/workstation.nix for: home-manager switch --flake ~/dotfiles#username@workstation)
# Roll back:       home-manager generations  →  /nix/store/<hash>-home-manager-generation/activate
#
# See docs/explanation/nix-home-manager-boundary.md for the Home Manager mental model.
{ ... }: {
  imports = [ ./hosts/workstation.nix ];
}
