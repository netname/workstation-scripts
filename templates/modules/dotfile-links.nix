# modules/dotfile-links.nix — mutable config symlinks
{ config, pkgs, ... }: {

  # ── Fonts ────────────────────────────────────────────────────────────────────
  fonts.fontconfig.enable = true;

  # Symlink JetBrainsMono into ~/.local/share/fonts so Flatpak apps
  # (WezTerm) can see it. Flatpak sandboxes cannot access ~/.nix-profile/share/fonts.
  home.file.".local/share/fonts/JetBrainsMono".source =
    "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";

  # ── Neovim config: mutable symlink outside /nix/store ───────────────────────
  # LazyVim writes lazy-lock.json at runtime, so it needs a mutable directory.
  # mkOutOfStoreSymlink creates ~/.config/nvim -> ~/dotfiles/nvim directly,
  # bypassing the read-only /nix/store.
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/nvim";

  # ── tmux config: mutable symlink outside /nix/store ─────────────────────────
  # TPM writes plugin state to ~/.tmux/plugins at runtime.
  # mkOutOfStoreSymlink creates ~/.config/tmux/tmux.conf -> ~/dotfiles/tmux/tmux.conf.
  home.file.".config/tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/tmux/tmux.conf";
}
