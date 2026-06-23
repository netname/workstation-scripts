# modules/git.nix — global git configuration
{ ... }: {

  # ── Git ──────────────────────────────────────────────────────────────────────
  # Home Manager writes ~/.config/git/config from this block.
  # Never run `git config --global` manually — it writes to the same file and
  # will be overwritten by hms.
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "YOUR_FULL_NAME"; # your full name, e.g. "Jane Smith"
        email = "YOUR_EMAIL";    # email registered on GitHub
      };
      core.pager = "delta";
      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
      pull.rebase = true;
      init.defaultBranch = "main";
      alias = {
        lg = "log --oneline --graph --decorate --all";
        st = "status --short";
        sw = "switch";
        co = "checkout -b";
        pushf = "push --force-with-lease --force-if-includes";
        psu = "push --set-upstream origin HEAD";
      };
    };
    # Silence the "no signing format" warning emitted by newer Home Manager versions.
    signing.format = null;
  };
}
