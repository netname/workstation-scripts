# modules/secrets.nix — SOPS + Age secret management
{ config, ... }: {

  # The Age private key is intentionally outside git. Back it up separately.
  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    # After creating ~/dotfiles/secrets/workstation.yaml with `sops`, declare
    # secrets here. Keep encrypted files in the private dotfiles repo only.
    #
    # defaultSopsFile = ../secrets/workstation.yaml;
    # secrets."example/api-token" = {};
  };
}
