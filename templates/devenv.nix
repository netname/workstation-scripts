# devenv.nix — per-project development environment
# Copy this file to the root of each project repository.
# Commit it — every developer who clones the repo gets the same environment.
#
# Activate:  direnv allow   (once per developer per repo)
# Update:    devenv update  (pulls latest locked versions)
# Roll back: git checkout devenv.nix devenv.lock && devenv update
#
# See docs/4-Projects.md §8.3 for a step-by-step setup walkthrough.
# See docs/1-Stack.md §1.7 for the Devenv vs Home Manager distinction.
{ pkgs, ... }: {

  # ── Packages ─────────────────────────────────────────────────────────────────
  # Binaries added to $PATH when inside this project directory.
  # LSP servers and formatters go here so every developer uses the same version.
  packages = [
    pkgs.just          # task runner — keep version pinned per project

    # Uncomment as needed:
    # pkgs.pyright     # Python LSP server
    # pkgs.ruff        # Python formatter + linter
    # pkgs.nodejs_22   # Node runtime (if not using languages.javascript below)
    # pkgs.typescript-language-server
  ];

  # ── Python (ERPNext v15 / pip-based projects) ────────────────────────────────
  # For projects that manage Python via Nix. The version here is pinned in
  # devenv.lock — run `devenv update` to pull a newer patch release.
  # Do NOT use this block for ERPNext v16 — see the uv note below.
  #
  # languages.python = {
  #   enable = true;
  #   version = "3.11";          # pin to the version your project requires
  #   venv.enable = true;
  #   venv.requirements = ./requirements.txt;
  # };

  # ── Python (ERPNext v16 / uv-managed projects) ───────────────────────────────
  # v16 uses uv to manage the interpreter and virtualenv. Omit the
  # languages.python block entirely and install uv via home.nix instead.
  # Before running `direnv allow`, install the interpreter once:
  #   uv python install 3.14
  # See docs/4-Projects.md §8.3 Step 2 for the full v16 flow.

  # ── JavaScript / TypeScript ──────────────────────────────────────────────────
  # languages.javascript = {
  #   enable = true;
  #   npm.enable = true;
  # };

  # ── Environment variables ─────────────────────────────────────────────────────
  # Exported into the shell when the environment activates.
  # Never put secrets here — .envrc is committed to git.
  # Load secrets from .env via enterShell below instead.
  env = {
    # DATABASE_URL = "mysql://root:root@localhost:3306/mydb";
    # REDIS_URL    = "redis://localhost:6379";
  };

  # ── Shell hook ───────────────────────────────────────────────────────────────
  # Runs each time the environment activates (on `cd` into the directory).
  # Loads a local .env file if present — keep .env in .gitignore.
  # See docs/1-Stack.md §1.10 for the secrets pattern.
  enterShell = ''
    if [ -f .env ]; then
      set -a; source .env; set +a
    fi
  '';

  # ── Git hooks (optional) ─────────────────────────────────────────────────────
  # Enforces code quality checks before every commit — shared across the team.
  # See docs/4-Projects.md §8.8 for the full git-hooks setup.
  #
  # git-hooks.hooks = {
  #   ruff.enable = true;
  #   ruff-format.enable = true;
  # };
}
