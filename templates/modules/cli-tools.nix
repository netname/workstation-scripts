# modules/cli-tools.nix — global command-line tools
{ pkgs, ... }: {

  # ── Global packages ─────────────────────────────────────────────────────────
  # Global tools installed here are available in every shell, across all projects.
  # Project-specific tools (pyright, ruff, etc.) belong in devenv.nix, not here.
  home.packages = with pkgs; [
    # Version control
    lazygit
    gh
    delta

    # Shell utilities
    fzf
    bat
    eza
    jq
    ripgrep
    fd
    zoxide
    tree

    # Build tools (required by some Nix derivations)
    gcc

    # Project environment tooling
    devenv
    just
    uv

    # Secret management
    # sops edits encrypted files, age provides encryption, and ssh-to-age
    # derives Age recipients from existing SSH public keys.
    sops
    age
    ssh-to-age

    # Editor + terminal multiplexer binaries
    # Config lives in ~/dotfiles/nvim/ and ~/dotfiles/tmux/ respectively.
    neovim
    tmux
    tree-sitter

    # Runtime for npm-installed global tools (e.g. Claude Code, language servers)
    nodejs_22

    # Clipboard (include both; each is a no-op on the wrong display server)
    xclip
    wl-clipboard

    # JetBrainsMono Nerd Font renders icons in WezTerm, tmux, and Neovim.
    nerd-fonts.jetbrains-mono
  ];
}
