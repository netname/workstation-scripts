# home.nix — declarative user environment
# Copy this file to ~/dotfiles/home.nix in your PRIVATE dotfiles repo.
# Replace every CHANGE_ME placeholder before running hms.
#
# Apply changes:   hms   (alias for: home-manager switch --flake ~/dotfiles#username)
# Roll back:       home-manager generations  →  /nix/store/<hash>-home-manager-generation/activate
#
# See docs/1-Stack.md §1.4 for the full Home Manager mental model.
{ config, pkgs, ... }: {

  # ── Identity ────────────────────────────────────────────────────────────────
  # §1.4 — These two values must match your Linux user and the key in flake.nix.
  home.username = "CHANGE_ME";
  home.homeDirectory = "/home/CHANGE_ME";
  home.stateVersion = "24.11";

  # Required — lets Home Manager manage itself (update command, generations, etc.)
  programs.home-manager.enable = true;

  # ── Default editor ─────────────────────────────────────────────────────────
  # Used by git, gh, and other CLI tools when they need a full editor.
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # ── Global packages ─────────────────────────────────────────────────────────
  # §1.4 — Tools installed here are available in every shell, across all projects.
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

    # Editor + terminal multiplexer binaries
    # Config lives in ~/dotfiles/nvim/ and ~/dotfiles/tmux/ respectively — §1.5
    neovim
    tmux
    tree-sitter

    # Runtime for npm-installed global tools (e.g. Claude Code, language servers)
    nodejs_22

    # Clipboard (include both; each is a no-op on the wrong display server)
    xclip
    wl-clipboard

    # §3.2 — JetBrainsMono Nerd Font renders icons in WezTerm, tmux, and Neovim.
    nerd-fonts.jetbrains-mono
  ];

  # ── Fonts ────────────────────────────────────────────────────────────────────
  fonts.fontconfig.enable = true;

  # §3.2 — Symlink JetBrainsMono into ~/.local/share/fonts so Flatpak apps
  # (WezTerm) can see it. Flatpak sandboxes cannot access ~/.nix-profile/share/fonts.
  home.file.".local/share/fonts/JetBrainsMono".source =
    "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";

  # ── Neovim config: mutable symlink outside /nix/store ───────────────────────
  # §10.2 — LazyVim writes lazy-lock.json at runtime — it needs a mutable directory.
  # mkOutOfStoreSymlink creates ~/.config/nvim → ~/dotfiles/nvim directly,
  # bypassing the read-only /nix/store.
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/nvim";

  # ── tmux config: mutable symlink outside /nix/store ─────────────────────────
  # §4.7 — TPM writes plugin state to ~/.tmux/plugins at runtime.
  # mkOutOfStoreSymlink creates ~/.config/tmux/tmux.conf → ~/dotfiles/tmux/tmux.conf.
  home.file.".config/tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/tmux/tmux.conf";

  # ── Shell ────────────────────────────────────────────────────────────────────
  # §1.4 — Home Manager generates ~/.zshrc from this block. Never edit ~/.zshrc
  # directly — it will be silently overwritten on the next hms run.
  programs.zsh = {
    enable = true;

    shellAliases = {
      # Apply Home Manager changes — §1.4
      hms = "home-manager switch --flake ~/dotfiles#CHANGE_ME";

      # eza replaces ls
      ls  = "eza --icons";
      ll  = "eza -l --icons --git";
      la  = "eza -la --icons --git";
      lt  = "eza --tree --icons";

      # bat replaces cat
      cat = "bat";

      # Editor shortcut
      n   = "nvim";

      # Git shortcuts (longer workflows use lazygit)
      g   = "git";
      lg  = "lazygit";
    };

    # Shell initialisation — ORDER MATTERS (see docs/3-Terminal.md §7.4)
    initContent = ''
      # 1. PATH — ensure ~/.local/bin and Nix profile binaries are available
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.nix-profile/bin:$PATH"

      # 2. Nix profile (needed when shell is started outside of a login session)
      . "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true

      # 3. Direnv — must come before fzf/zoxide so project $PATH is set first
      eval "$(direnv hook zsh)"

      # 4. cd alias — MUST come before zoxide init (zoxide checks for this alias on init)
      alias cd='z'

      # 5. zoxide (smarter cd — routes through frecency when you type cd or z)
      eval "$(zoxide init zsh)"

      # 6. fzf key bindings (Ctrl-R history, Ctrl-T file picker) are sourced
      # automatically by Home Manager via programs.fzf.enableZshIntegration = true.
      # Do NOT add eval "$(fzf --zsh)" here — it is redundant and the generated
      # path may not exist for Nix-installed fzf.

      # 7. Starship — MUST be last (wraps PS1; anything after breaks the prompt)
      eval "$(starship init zsh)"
    '';
  };

  # ── Shell prompt ─────────────────────────────────────────────────────────────
  # §1.4 — Starship renders the prompt. Customise via programs.starship.settings.
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      # Add custom modules here — see https://starship.rs/config/
    };
  };

  # ── Git ──────────────────────────────────────────────────────────────────────
  # §1.4 — Home Manager writes ~/.config/git/config from this block.
  # Never run `git config --global` manually — it writes to the same file and
  # will be overwritten by hms.
  programs.git = {
    enable = true;
    settings = {
      user = {
        name  = "CHANGE_ME";              # your full name
        email = "CHANGE_ME@example.com";  # email registered on GitHub
      };
      core.pager = "delta";
      delta = {
        navigate     = true;
        side-by-side = true;
        line-numbers = true;
      };
      pull.rebase        = true;
      init.defaultBranch = "main";
      alias = {
        lg    = "log --oneline --graph --decorate --all";
        st    = "status --short";
        sw    = "switch";
        co    = "checkout -b";
        pushf = "push --force-with-lease --force-if-includes";
        psu   = "push --set-upstream origin HEAD";
      };
    };
    # Silence the "no signing format" warning emitted by newer Home Manager versions.
    signing.format = null;
  };

  # ── Direnv ────────────────────────────────────────────────────────────────────
  # §1.6 — enableZshIntegration is intentionally false here.
  # When true, Home Manager appends eval "$(direnv hook zsh)" at the END of
  # .zshrc — but direnv must be initialised EARLY (position 3 in initContent
  # above) so that tmux pane shells have it active before the initial window
  # command fires. Setting this to true produces a duplicate hook at the wrong
  # position, causing environment activation to silently fail in new tmux panes.
  programs.direnv = {
    enable = true;
    enableZshIntegration = false;
    nix-direnv.enable = true;
  };

  # ── fzf ──────────────────────────────────────────────────────────────────────
  # enableZshIntegration = true lets Home Manager generate and source the fzf
  # shell integration file (Ctrl-R, Ctrl-T, Alt-C key bindings). The integration
  # file is sourced automatically at the correct point in the generated .zshrc.
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
