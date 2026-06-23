# devenv.nix — per-project development environment
# Copy this file to the root of each project repository.
# Commit it — every developer who clones the repo gets the same environment.
#
# Activate:  direnv allow   (once per developer per repo)
# Update:    devenv update  (pulls latest locked versions)
# Roll back: git checkout devenv.nix devenv.lock && devenv update
#
# See docs/tutorials/first-project-environment.md for a guided setup.
# See docs/explanation/project-tooling-model.md for the Devenv vs Home Manager distinction.
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
  # languages.python block entirely and use the uv binary provided by Home
  # Manager in modules/cli-tools.nix.
  # Before running `direnv allow`, install the project-required interpreter once:
  #   uv python install <required-python-version>
  # See docs/reference/project-environment-config.md for project environment conventions.

  # ── JavaScript / TypeScript ──────────────────────────────────────────────────
  # languages.javascript = {
  #   enable = true;
  #   npm.enable = true;
  # };

  # ── Environment variables ─────────────────────────────────────────────────────
  # Exported into the shell when the environment activates.
  # Put only non-secret values here: local URLs, feature flags, environment names.
  # Never put API keys, passwords, or tokens here: Nix expressions can leak into
  # the store or logs. Shared secrets belong in SOPS-encrypted files; personal
  # throwaway secrets can stay in ignored .env files.
  env = {
    # APP_ENV = "development";
    # SERVICE_HOST = "127.0.0.1";
  };

  # ── Shell hook ───────────────────────────────────────────────────────────────
  # Runs each time the environment activates (on `cd` into the directory).
  # Secret tiers:
  #   1. SOPS-encrypted shared secrets: commit secrets/development.env encrypted.
  #   2. Local-only personal secrets: keep .env ignored and uncommitted.
  # See docs/explanation/secrets-model.md for the full model.
  enterShell = ''
    if [ -f secrets/development.env ]; then
      set -a; source <(sops -d secrets/development.env); set +a
    fi

    if [ -f .env ]; then
      set -a; source .env; set +a
    fi

    # Derive connection URLs after SOPS and .env values have been loaded.
    # export DATABASE_URL="mysql://${MARIADB_USER}:${MARIADB_PASSWORD}@127.0.0.1:${MARIADB_PORT:-3306}/${MARIADB_DATABASE:-mydb}"
    # export REDIS_URL="redis://127.0.0.1:${REDIS_PORT:-6379}"
  '';

  # ── Git hooks (optional) ─────────────────────────────────────────────────────
  # Enforces code quality checks before every commit — shared across the team.
  # See docs/reference/project-environment-config.md for project environment conventions.
  #
  # git-hooks.hooks = {
  #   ruff.enable = true;
  #   ruff-format.enable = true;
  # };
}
