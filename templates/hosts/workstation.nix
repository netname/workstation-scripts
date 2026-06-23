# hosts/workstation.nix — current workstation profile
{ ... }: {

  imports = [
    ../homes/CHANGE_ME.nix
    ../modules/cli-tools.nix
    ../modules/dotfile-links.nix
    ../modules/git.nix
    ../modules/secrets.nix
    ../modules/shell.nix
  ];

  programs.zsh.shellAliases = {
    # Apply Home Manager changes for this workstation profile.
    hms = "home-manager switch --flake ~/dotfiles#CHANGE_ME@workstation";
  };
}
