# modules/shell.nix — shell, prompt, and environment activation
{ ... }: {

  # Required — lets Home Manager manage itself (update command, generations, etc.)
  programs.home-manager.enable = true;

  # ── Default editor ─────────────────────────────────────────────────────────
  # Used by git, gh, and other CLI tools when they need a full editor.
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # ── Shell ────────────────────────────────────────────────────────────────────
  # Home Manager generates ~/.zshrc from this block. Never edit ~/.zshrc
  # directly — it will be silently overwritten on the next hms run.
  programs.zsh = {
    enable = true;

    shellAliases = {
      # eza replaces ls
      ls = "eza --icons";
      ll = "eza -l --icons --git";
      la = "eza -la --icons --git";
      lt = "eza --tree --icons";

      # bat replaces cat
      cat = "bat";

      # Editor shortcut
      n = "nvim";

      # Git shortcuts (longer workflows use lazygit)
      g = "git";
      lg = "lazygit";
    };

    # Shell initialisation: order matters for Nix, direnv, zoxide, fzf, and starship.
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

      # 6. fzf key bindings (Ctrl-R history, Ctrl-T, Alt-C key bindings) are sourced
      # automatically by Home Manager via programs.fzf.enableZshIntegration = true.
      # Do NOT add eval "$(fzf --zsh)" here — it is redundant and the generated
      # path may not exist for Nix-installed fzf.

      # 7. Starship — MUST be last (wraps PS1; anything after breaks the prompt)
      eval "$(starship init zsh)"
    '';
  };

  # ── Shell prompt ─────────────────────────────────────────────────────────────
  # Starship renders the prompt. Customise via programs.starship.settings.
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;
      # Add custom modules here — see https://starship.rs/config/
    };
  };

  # ── Direnv ────────────────────────────────────────────────────────────────────
  # enableZshIntegration is intentionally false here.
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
