# homes/CHANGE_ME.nix — user identity and personal preferences
# Rename this file to homes/$(whoami).nix after replacing CHANGE_ME.
{ ... }: {

  # ── Identity ────────────────────────────────────────────────────────────────
  # These values must match your Linux user and the key in flake.nix.
  home.username = "CHANGE_ME";
  home.homeDirectory = "/home/CHANGE_ME";
  home.stateVersion = "24.11";
}
