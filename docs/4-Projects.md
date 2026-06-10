> **Development Workstation** · [Overview](0-Overview.md) · [Stack](1-Stack.md) · [Installation](2-Installation.md) · [Terminal](3-Terminal.md) · **Projects** · [Editors](5-Editors.md) · [Desktop](6-Desktop.md) · [Troubleshooting](7-Troubleshooting.md) · [Workflows](8-DevWorkflows.md)

## Part 8: Per-Project Environments with Devenv

> [!note] **What you now know**
> fzf and zoxide are configured and integrated. The shell init order is correct. `Ctrl-R` searches your full history, `z` navigates by frecency, and the sessionizer's project picker is fast and complete. Part 8 covers the per-project layer: Devenv.

---

> [!note] **What you will understand by the end of this part**
> - How to create a project environment from scratch and what every field in `devenv.nix` does
> - How the `devenv.lock` file guarantees reproducibility — and what the one known exception is
> - The ERPNext v15/v16 split: why v16 manages Python differently and what changes in `devenv.nix`
> - How to evolve the environment over time: updating, rolling back, keeping lock files committed

Part 1 established the principle: Devenv owns per-project tool versions, Docker Compose owns stateful services. This part is the implementation — how to create a project environment from scratch, what every field in `devenv.nix` does, how the lockfile guarantees reproducibility, and how to keep the environment evolving without breaking it.

---

### 8.1 The Problem Devenv Solves

A concrete scenario: your ERPNext project requires Python 3.11 and `pyright` version 1.1.350. Your autoint2 project at Achemex requires Python 3.9 and an older `ruff`. Without isolation, one version is "the system version" and the other requires workarounds — `pyenv`, manual `PATH` manipulation, virtualenv gymnastics — that drift between machines and between developers.

With Devenv, each project declares its own `devenv.nix`. Python 3.11 and Python 3.9 coexist without conflict because they live at different paths in `/nix/store`. Direnv activates the correct one when you `cd` into each project. A teammate cloning the repository gets the exact same versions. CI uses the exact same versions.

The problem does not require a clever workaround. It requires the right layer to own it.

---

### 8.2 Installing Devenv

Devenv is installed by Home Manager (declared in `home.nix` packages as `pkgs.devenv`). Verify:

```bash
devenv --version
```

Expected output: `devenv x.y` — any recent version.

If `devenv` is not found, the Nix profile PATH may not be active in the current shell. Source it:

```bash
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

Then retry. If devenv is still not found, confirm it is in `home.nix` packages and run `hms`.

---

### 8.3 Creating a Project Environment from Scratch

Work through these steps in order for any new project directory.

**Step 1: Initialise devenv**

```bash
cd ~/projects/my-project
devenv init
```

This creates three files:

```
my-project/
  devenv.nix      # The environment declaration — edit this
  devenv.yaml     # Devenv configuration and inputs
  .envrc          # Contains exactly one line: use devenv
```

> [!tip] **Replace the generated `devenv.nix` with the starter template.** The file created by `devenv init` is a minimal skeleton with most fields commented out and no explanations. `workstation-scripts/templates/devenv.nix` is a better starting point — it has the common patterns already laid out (packages, Python, JavaScript, environment variables, secrets loading, git hooks), with comments explaining what each block is for and what does not belong here. Copy it over the generated file:
>
> ```bash
> cp ~/workstation-scripts/templates/devenv.nix devenv.nix
> ```
>
> Keep the `.envrc` and `devenv.yaml` that `devenv init` generated — only `devenv.nix` is replaced. The template is intentionally generic: uncomment and fill in only the blocks your project actually needs. The §8.4 field guide below explains every block in depth.

**Step 2: Install the Python interpreter (ERPNext v16 only)**

> [!note] Skip this step for ERPNext v15 projects. For v16, this must be done before `direnv allow` — the devenv shell activates silently without it, but `bench init` will fail later when it cannot locate a 3.14 interpreter.

```bash
uv python install 3.14   # idempotent — safe to re-run if already installed
```

Verify:

```bash
uv python list   # should show cpython-3.14.x in the output
```

**Step 3: Trust the `.envrc`**

```bash
direnv allow
```

This must be run once per developer per repository. Direnv will not load an `.envrc` it has not been explicitly told to trust. After this, every subsequent `cd` into the directory activates the environment automatically.

**Step 4: Wait for the first activation**

The first activation downloads packages from `cache.nixos.org`. This takes several minutes depending on how many packages the environment declares. You will see Nix progress output in the terminal:

```
direnv: loading ~/projects/my-project/.envrc
direnv: using devenv
Building shell ...
[many lines of Nix evaluation and download output]
direnv: export +DATABASE_URL +DEVENV_DOTDOTDOT ...
```

When the prompt returns with no error, the environment is active.

**Step 5: Verify activation**

The correct check depends on your ERPNext version.

**For ERPNext v15** — Python is provided by devenv, so it appears on `$PATH` from `/nix/store`:

```bash
which python
# Expected: /nix/store/abc123.../bin/python3
# Not expected: /usr/bin/python3
```

**For ERPNext v16** — `languages.python` is absent, so there is no Nix-managed Python on `$PATH`. Verify the tools that _are_ managed by devenv, and confirm uv can see the 3.14 interpreter:

```bash
node --version
# Expected: v24.x.x  (confirms nodejs_24 from devenv is active)

uv python list
# Expected: a line containing cpython-3.14.x
# If 3.14 is absent: run `uv python install 3.14` and re-enter the directory
```

If neither check shows devenv-managed output, the environment did not activate. Diagnose:

- Did you run `direnv allow`?
- Is there a syntax error in `devenv.nix`? Run `devenv shell` to see Nix evaluation errors directly.

**Step 6: Commit the generated files**

```bash
git add devenv.nix devenv.yaml devenv.lock .envrc
git commit -m "chore: initialise devenv environment"
```

> [!important] Always commit `devenv.lock` The `devenv.lock` file records the exact Git revision of the nixpkgs input tree. Committing it means every developer who clones the repository gets bit-for-bit identical tool versions. Without it, cloning today and cloning in three months may produce different `ruff` or `pyright` versions. The lockfile is the reproducibility guarantee.

---

### 8.4 The `devenv.nix` Field Guide

The following is a complete, annotated `devenv.nix` for an ERPNext v15/v16 project. Every field is explained: what it does, what happens if it is misconfigured, and what does not belong here.

> [!tip] Just want to copy and paste? Skip to **see the Example devenv.nix section below**, which has the same file without the pedagogical annotations — ready to drop into a project root.

```nix
{ pkgs, lib, config, ... }:

{
  # ── packages ──────────────────────────────────────────────────────────────────
  # System-level binaries added to $PATH when the environment activates.
  # These are available in every shell pane in the tmux session, in Neovim
  # (via PATH inheritance — see §8.5), and in VS Code (via mkhl.direnv).
  #
  # Rule: if a tool's version matters for the project, it goes here.
  # Rule: if a tool is purely personal and any version works, it goes in home.nix.
  #
  # IMPORTANT: debugpy does NOT go here. See the note below the packages block.
  packages = [
    pkgs.git
    pkgs.curl
    pkgs.jq

    # MariaDB and Redis CLI clients — for interacting with the Docker services.
    # The servers themselves run in Docker Compose (§8.6), not here.
    pkgs.mariadb-client
    pkgs.redis

    # C libraries required for Mexican localization.
    # xmlsec1 is needed for SAT XML signing (CFDI 4.0).
    # libxml2 is a dependency of xmlsec1 Python bindings.
    # pkg-config is needed to compile packages that link against these.
    pkgs.pkg-config
    pkgs.libxml2
    pkgs.xmlsec1

    # Project-bound LSP servers — version matters per project.
    # mason = false in Neovim's lsp.lua tells LazyVim to find these
    # on $PATH rather than downloading them via Mason. (§8.11)
    #
    # Note on nodePackages.* namespace: on nixos-unstable (the channel this
    # guide uses), many Node packages have moved from nodePackages.* to
    # top-level attribute names. If pkgs.nodePackages.typescript-language-server
    # fails with "attribute missing", try pkgs.typescript-language-server.
    # Check the correct name at search.nixos.org/packages.
    pkgs.pyright
    pkgs.nodePackages.typescript-language-server

    # Project-bound formatter and linter.
    # conform.nvim and nvim-lint find these via $PATH inheritance. (§8.9, §8.10)
    pkgs.ruff

    # Task runner. just setup, just fmt, just test — one command per workflow.
    pkgs.just
  ];

  # NOTE: debugpy is NOT in packages above.
  # debugpy must be installed into the Python virtualenv via requirements.txt
  # because the DAP adapter command is `python3 -m debugpy.adapter` — Python
  # must be able to import debugpy, not merely find it on $PATH.
  # See §8.13 for the full explanation and setup.

  # ── languages.python ─────────────────────────────────────────────────────────
  # Declares the Python runtime and configures an isolated virtualenv.
  #
  # version: the exact Python minor version.
  # ERPNext v15 requires Python 3.11.
  # ERPNext v16 requires Python 3.14 — see note below.
  # Changing this value and running `devenv update` switches the interpreter.
  #
  # venv.enable: creates .venv/ in the project root when the environment
  # activates. Pyright reads this path from pyrightconfig.json (§8.11).
  # VS Code reads it from .vscode/settings.json (§8.5).
  #
  # venv.requirements: installs these packages into .venv/ on activation.
  # This is where debugpy belongs. Add it here alongside your project deps.

  # ── For ERPNext v15 ──────────────────────────────────────────────────────────
  languages.python = {
    enable  = true;
    version = "3.11";          # stable in nixpkgs, no issues
    venv.enable = true;
    venv.requirements = ./requirements.txt;
  };

  # ── For ERPNext v16 ──────────────────────────────────────────────────────────
  # Python 3.14 is available in nixpkgs, but packages with C extensions
  # (lxml, cryptography, mysqlclient, xmlsec) may have compatibility issues
  # when building against the 3.14 headers in nixpkgs. Do NOT use
  # languages.python for v16. Instead, let uv manage the interpreter:
  #
  #   uv python install 3.14    # run once, installs to ~/.local/share/uv/python/
  #
  # uv is already in your PATH via Home Manager. bench init will pick up the
  # 3.14 interpreter automatically when BENCH_USE_UV = "1" is set in env {}.
  #
  # languages.python is intentionally absent for v16 projects.

  # ── languages.javascript ─────────────────────────────────────────────────────
  # Declares the Node.js runtime.
  #
  # Do NOT also add pkgs.nodejs_24 to the packages list above — defining it
  # here via languages.javascript.package automatically injects Node into $PATH.
  # Adding it again in packages causes a duplicate that may shadow the wrong one.
  #
  # ERPNext v16 requires Node 24 (v15 required Node 22).
  #
  # npm.install.enable: runs `npm install` automatically when the environment
  # activates if package.json is present. Disable this if you prefer to run
  # npm install manually.
  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_24;
    npm.enable = true;
    npm.install.enable = true;
  };

  # ── env ───────────────────────────────────────────────────────────────────────
  # Environment variables set on activation and unset on deactivation.
  # These are visible to all processes in the devenv shell, including Neovim,
  # VS Code (via mkhl.direnv), and any scripts run from the shell.
  #
  # config.devenv.root resolves to the absolute path of the project root —
  # the directory containing devenv.nix. Using it avoids hardcoded paths
  # that break when the project is cloned to a different location.
  #
  # Use this block for: database URLs, feature flags, API base URLs,
  # environment identifiers (APP_ENV=development).
  # Do NOT use this block for: secrets, API keys, passwords.
  # Secrets go in a .env file loaded by enterShell (see below) or in a
  # secrets manager like SOPS.
  env = {
    BENCH_USE_UV = "1";          # tells bench to use uv for venv management
    BENCH_PATH   = "${config.devenv.root}/frappe-bench";
    APP_ENV      = "development";
    # PYTHONPATH: bench/Frappe expects to import app modules relative to the
    # project root. uv's venv takes precedence for package imports — this only
    # affects bare module resolution outside the venv. Do not remove unless
    # bench init/update explicitly stops requiring it.
    PYTHONPATH   = config.devenv.root;
  };

  # ── enterShell ────────────────────────────────────────────────────────────────
  # Shell commands run every time the devenv environment activates.
  # Use for: printing helpful reminders, running a quick health check,
  # loading secrets from a local .env file.
  #
  # The .env loading pattern below is the standard way to handle secrets:
  # .env is in .gitignore, so it is never committed. Each developer creates
  # their own .env with local credentials. `set -a` exports all variables
  # defined in the file; `set +a` restores the default behaviour.
  #
  # NOTE (v16): `python --version` is NOT used here. With languages.python
  # absent, the shell has no Nix-managed Python on $PATH — querying it would
  # print the system Python (misleading) or fail (confusing). Instead, we ask
  # uv which 3.14 interpreter it has installed, which is the interpreter bench
  # will actually use. If the line prints nothing, uv python install 3.14
  # has not been run yet — a clear signal to the developer.
  enterShell = ''
    echo "ERPNext dev environment active"
    echo "  Node:   $(node --version)"
    echo "  uv:     $(uv --version)"
    echo "  Python 3.14 (via uv): $(uv python list 2>/dev/null | grep '3\.14' | head -1 | awk '{print $1, $2}' || echo 'NOT INSTALLED — run: uv python install 3.14')"
    if [ -f .env ]; then
      set -a; source .env; set +a
    fi
  '';

  # ── git-hooks ─────────────────────────────────────────────────────────────────
  # Nix-native git hooks. Only use this block OR .pre-commit-config.yaml —
  # never both. See §8.8 for the full decision guide.
  #
  # If your team all uses this Nix stack: use this block.
  # If any teammate works without Nix: use .pre-commit-config.yaml instead
  # and leave this block commented out or absent.
  #
  # git-hooks.hooks = {
  #   ruff.enable = true;
  #   ruff-format.enable = true;
  # };
}
```

> [!warning] ERPNext v16: Python 3.14 is managed by uv, not nixpkgs — understand the tradeoff
> 
> **Why not just use `languages.python` with `version = "3.14"`?**
> 
> Devenv's `languages.python` block resolves Python interpreters from nixpkgs. Python 3.14 is available in nixpkgs, but Python packages with C extensions — including several in ERPNext's dependency surface (lxml, cryptography, mysqlclient, xmlsec) — may have compatibility issues when building against the 3.14 headers in nixpkgs. For a project with ERPNext's dependency surface this is not a theoretical risk: a single package build failure blocks environment activation entirely.
> 
> The workaround is to let `uv` manage the 3.14 interpreter independently. `uv` fetches CPython builds from its own release channel (Astral's `python-build-standalone` project), which tracks stable CPython releases and has no dependency on nixpkgs compilation. Setting `BENCH_USE_UV = "1"` in `env {}` tells bench to delegate virtualenv creation to `uv` rather than the system venv module, so the entire Python toolchain flows through `uv`.
> 
> **The reproducibility tradeoff you are accepting**
> 
> Unlike every other tool in this environment — where `devenv.lock` records a nixpkgs Git revision that pins exact binary hashes — the Python interpreter for v16 is not recorded anywhere in the repository. `uv python install 3.14` installs the latest 3.14.x patch release available at the time it is run. Two developers running this command a month apart may get 3.14.0 and 3.14.1. Python patch releases are stable by policy, so this is unlikely to cause problems in practice, but it is a conscious departure from the "same hash = same binary" guarantee.
> 
> If strict interpreter reproducibility matters for your project, pin the exact version:
> 
> ```bash
> uv python install 3.14.0
> ```
> 
> **Prerequisites: this step is not automatic**
> 
> `uv python install 3.14` is a manual step that must be run before `direnv allow`. If it is skipped, the devenv shell activates without error (because `languages.python` is absent), but `bench init` will fail when it cannot find a 3.14 interpreter. The `just setup` target and the onboarding flow below (§8.9) include this step explicitly so it cannot be forgotten.
> 
> **Copy-paste version:** The full `devenv.nix` without pedagogical annotations is in see the Example devenv.nix section below.

---

### Example `devenv.nix`

Complete ERPNext v15/v16 development environment. Copy to your project root and run `direnv allow`. For a field-by-field explanation of every block, see **§8.4**.

```nix
# devenv.nix — ERPNext v15/v16 development environment
{ pkgs, lib, config, ... }:

{
  # ── System packages ──────────────────────────────────────────────────────────
  # Binaries added to $PATH when the devenv shell activates.
  # Neovim inherits this $PATH, so these are also available to LSPs and formatters.
  packages = [
    pkgs.git
    pkgs.curl
    pkgs.jq
    pkgs.wget

    # Database and cache CLI clients
    # (servers run in Docker Compose — see the Example docker-compose.yml section below)
    pkgs.mariadb-client
    pkgs.redis

    # C libraries for Mexican localization (CFDI 4.0 / SAT XML signing)
    pkgs.pkg-config
    pkgs.libxml2
    pkgs.xmlsec1

    # LSP servers — mason = false in Neovim's lsp.lua means these
    # are found via $PATH rather than downloaded by Mason
    pkgs.pyright
    pkgs.nodePackages.typescript-language-server
    pkgs.nodePackages.vscode-langservers-extracted  # provides eslint LSP

    # Formatter and linter
    pkgs.ruff

    # Task runner
    pkgs.just

    # NOTE: debugpy is NOT here.
    # It must go in requirements.txt so pip installs it into .venv/.
    # The DAP adapter command is `python3 -m debugpy.adapter` —
    # Python must be able to import it, not just find it on $PATH.
  ];

  # ── Python runtime ───────────────────────────────────────────────────────────
  # ── For ERPNext v15 ──────────────────────────────────────────────────────────
  languages.python = {
    enable  = true;
    version = "3.11";
    venv = {
      enable       = true;
      requirements = ./requirements.txt;  # debugpy>=1.8 must be in here
    };
  };

  # ── For ERPNext v16 ──────────────────────────────────────────────────────────
  # Python 3.14 is available in nixpkgs, but packages with C extensions
  # (lxml, cryptography, mysqlclient, xmlsec) may have compatibility issues
  # when building against the 3.14 headers in nixpkgs. Do NOT use
  # languages.python for v16. Instead, let uv manage the interpreter:
  #
  #   uv python install 3.14    # run once, installs to ~/.local/share/uv/python/
  #
  # uv is already in your PATH via Home Manager. bench init will pick up the
  # 3.14 interpreter automatically when BENCH_USE_UV = "1" is set in env {}.
  #
  # languages.python is intentionally absent for v16 projects.

  # ── Node.js runtime ──────────────────────────────────────────────────────────
  # Do NOT also add pkgs.nodejs_24 to packages above —
  # defining it here injects it into $PATH automatically.
  # ERPNext v16 requires Node 24 (v15 required Node 22).
  languages.javascript = {
    enable  = true;
    package = pkgs.nodejs_24;
    npm = {
      enable         = true;
      install.enable = true;   # runs `npm install` on activation if package.json present
    };
  };

  # ── Environment variables ────────────────────────────────────────────────────
  # Set on activation, unset on deactivation.
  # config.devenv.root = absolute path to the project root (no hardcoded paths).
  # Do NOT put secrets here — use .env loaded in enterShell below.
  env = {
    BENCH_USE_UV = "1";          # tells bench to use uv for venv management
    BENCH_PATH   = "${config.devenv.root}/frappe-bench";
    APP_ENV      = "development";
    # PYTHONPATH: bench/Frappe expects to import app modules relative to the
    # project root. uv's venv takes precedence for package imports — this only
    # affects bare module resolution outside the venv. Do not remove unless
    # bench init/update explicitly stops requiring it.
    PYTHONPATH   = config.devenv.root;
  };

  # ── Shell entry hook ─────────────────────────────────────────────────────────
  # Runs every time the devenv shell activates.
  # The .env loading pattern handles secrets: .env is in .gitignore,
  # each developer creates their own with local credentials.
  #
  # NOTE (v16): Python version is checked via `uv python list`, not
  # `python --version`. With languages.python absent, there is no Nix-managed
  # Python on $PATH. The uv check shows which interpreter bench will actually
  # use, and prints a clear warning if uv python install 3.14 was skipped.
  enterShell = ''
    echo "ERPNext dev environment active"
    echo "  Node:   $(node --version)"
    echo "  uv:     $(uv --version)"
    echo "  Python 3.14 (via uv): $(uv python list 2>/dev/null | grep '3\.14' | head -1 | awk '{print $1, $2}' || echo 'NOT INSTALLED — run: uv python install 3.14')"
    if [ -f .env ]; then
      set -a; source .env; set +a
    fi
  '';

  # ── Git hooks ────────────────────────────────────────────────────────────────
  # CHOOSE ONE: devenv git-hooks (below) OR .pre-commit-config.yaml — not both.
  # Use devenv git-hooks if the entire team uses this Nix stack.
  # Use .pre-commit-config.yaml if any teammate works without Nix.
  # See §8.8 for the full decision guide.
  #
  # git-hooks.hooks = {
  #   trailing-whitespace.enable   = true;
  #   end-of-file-fixer.enable     = true;
  #   check-yaml.enable            = true;
  #   check-toml.enable            = true;
  #   check-added-large-files.enable = true;
  #   ruff = {
  #     enable       = true;
  #     settings.args = ["--fix"];
  #   };
  #   ruff-format.enable = true;
  # };
}
```

---

### 8.5 How `$PATH` Flows to Neovim

This diagram explains why Neovim finds the correct `ruff`, `pyright`, and other project tools without any per-project Neovim configuration:

```
cd ~/projects/my-project
        ↓
direnv activates devenv shell
        ↓
$PATH = /nix/store/abc-ruff-0.4.1/bin
      : /nix/store/def-pyright-1.1.350/bin
      : /nix/store/ghi-just-1.27/bin
      : ... (rest of PATH)
        ↓
nvim app/services/orders.py
        ↓
Neovim inherits the shell's $PATH
        ↓
conform.nvim runs "ruff_format"
  → finds /nix/store/abc-ruff-0.4.1/bin/ruff   ← devenv's pinned version
  → ruff reads pyproject.toml → applies project rules

nvim-lint runs "ruff"
  → same binary, same rules

nvim-lspconfig starts "pyright"
  → finds /nix/store/def-pyright-1.1.350/bin/pyright-langserver
  → reads pyrightconfig.json → applies project type-checking rules
```

The project specificity comes entirely from two sources: `$PATH` (devenv provides the pinned binary) and the project config file (pyproject.toml, pyrightconfig.json). Neovim itself has no project-specific configuration — it discovers the right tools by looking at `$PATH` at startup.

This is why the `mason = false` setting in `lua/plugins/lsp.lua` (§8.11) is essential: without it, LazyVim would use Mason's downloaded binary instead of devenv's pinned one, and version consistency would be lost.

---

### 8.6 Docker Compose for Stateful Services

The governing principle from §1.8: Devenv owns tools, Docker Compose owns state.

ERPNext requires MariaDB and three Redis instances. None of these belong in `devenv.nix` — their data must survive `devenv update` and project environment rebuilds. Docker Compose gives each service a named volume that persists independently of the devenv environment.

Create `docker-compose.yml` in your project root. For a project that uses MariaDB and Redis, start from the template in `workstation-scripts`:

```bash
cp ~/workstation-scripts/templates/docker-compose.yml docker-compose.yml
```

The template gives you MariaDB 11.8 and Redis 7-alpine with named volumes, health checks, and a commented-out second Redis instance for queue separation — the minimum structure for most projects. For ERPNext specifically, the example at the end of this section has ERPNext's required MariaDB flags and three separate Redis instances (cache, queue, socketio). Key points about how Docker Compose is used here:

**Named volumes persist through everything.** `docker compose down` stops containers but preserves volumes. `docker compose down -v` stops containers _and_ destroys volumes — use this only for a full reset.

**The three Redis instances are required by ERPNext.** ERPNext separates cache, queue, and socketio traffic across three Redis instances for isolation and performance. They are all `redis:7-alpine` but on different host ports (13000, 13001, 13002).

**ERPNext v16 requires specific service versions.** The full list of minimum versions for a v16 installation:

|Service|Minimum version|Image used|
|---|---|---|
|MariaDB|11.8|`mariadb:11.8`|
|Redis|6+|`redis:7-alpine`|
|Node.js|24+|`pkgs.nodejs_24` (in devenv.nix)|
|Python|3.14+|managed by uv (see §8.4)|
|Yarn|1.22+|installed by bench automatically|

**MariaDB requires specific flags for ERPNext.** The `--character-set-server=utf8mb4` and `--collation-server=utf8mb4_unicode_ci` flags are not optional — ERPNext's database setup assumes these character settings.

**Common daily commands:**

```bash
# Start all services in the background
docker compose up -d

# Verify all services are running and healthy
docker compose ps

# Watch logs from a specific service
docker compose logs -f mariadb

# Stop services (data preserved in named volumes)
docker compose down

# Full reset — destroys all data (use with caution)
docker compose down -v && docker compose up -d
```

---

### Example `docker-compose.yml`

MariaDB and three Redis instances for ERPNext. Place in the project root alongside `devenv.nix`.

```yaml
# docker-compose.yml
# ERPNext v16 minimum service versions:
#   MariaDB 11.8  — v16 requires 11.x; 10.6 is not supported
#   Redis 7       — satisfies the v16 minimum of Redis 6+
services:
  mariadb:
    image: mariadb:11.8
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
    environment:
      MYSQL_ROOT_PASSWORD: "123"
    volumes:
      - mariadb-data:/var/lib/mysql
    ports:
      - "3306:3306"
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis-cache:
    image: redis:7-alpine
    ports:
      - "13000:6379"

  redis-queue:
    image: redis:7-alpine
    ports:
      - "13001:6379"

  redis-socketio:
    image: redis:7-alpine
    ports:
      - "13002:6379"

volumes:
  mariadb-data:
```

---

### 8.7 VS Code Integration

Two settings are required for VS Code to use the devenv environment correctly. Both are covered in full in Part 3; this section covers only the devenv-specific parts.

**`mkhl.direnv` extension** reads `.envrc` and activates the devenv environment inside VS Code's process. Without it, VS Code extensions find only the system `$PATH` and either fail to find tools or find the wrong global versions. This extension is in `vscode/extensions.json`; install it with the rest of your extensions as described in [5-Editors.md §11.3](5-Editors.md).

**`.vscode/settings.json`** must point `python.defaultInterpreterPath` at the virtualenv created by devenv:

```json
{
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python"
}
```

The `.venv/` directory is created by `languages.python.venv.enable = true` in `devenv.nix`. If the path shown in VS Code's Python interpreter selector does not start with `.venv`, the `mkhl.direnv` extension is not active or `direnv allow` has not been run.

---

### 8.8 Pre-commit vs. Devenv Git-hooks: Choose One

> [!important] Use one system, not both Running both `.pre-commit-config.yaml` and `devenv.nix` git-hooks causes every commit to run hooks twice — once from each system. This wastes time and produces confusing duplicate output. Pick one approach per project and omit the other entirely.

**The recommendation:** use devenv git-hooks if your entire team uses this Nix stack. Use `.pre-commit-config.yaml` if any teammate works without Nix.

#### Option A: Devenv Git-hooks (Nix-native)

Defined in the `git-hooks.hooks` block of `devenv.nix`:

```nix
git-hooks.hooks = {
  ruff.enable = true;
  ruff-format.enable = true;
};
```

The hook binary versions are pinned by Nix — the same mechanism as all other devenv packages. No separate install step is needed per developer: the hooks install automatically when the devenv shell activates. Every developer on the team gets the same hook binary versions.

_When to use this:_ The entire team uses this Nix stack. No exceptions.

_Limitation:_ Teammates without Nix cannot use this path. CI pipelines that do not use devenv cannot use this path.

#### Option B: `.pre-commit-config.yaml` (universal)

A YAML file in the project root that works for any developer on any OS:

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.1
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
```

Hook versions are pinned via the `rev:` field. Any developer can use this regardless of whether they have Nix installed. Requires one manual step per developer per repository:

```bash
pre-commit install
```

This is absorbed into `just setup` so it is never forgotten (§8.9).

_When to use this:_ Any teammate works without Nix, or CI does not use devenv.

_Note:_ `pre-commit` itself is installed via `uv tool install pre-commit` — it is a global tool managed by `uv`, not a project-level devenv package. It is available in every project regardless of that project's devenv configuration.

#### CI Behaviour is Identical either way

Regardless of which approach you choose, CI runs the same checks:

```yaml
# .github/workflows/ci.yml (excerpt)
- name: Run linting
  run: ruff check .
- name: Run formatting check
  run: ruff format --check .
```

CI invokes the tools directly, not through pre-commit or devenv. Both hook systems enforce the same rules locally that CI enforces in the pipeline. The choice between them is about local developer experience, not about CI compatibility.

---

### 8.9 Task Management with Just

`just` is the project's task runner. It replaces `make` for project-level commands with cleaner syntax, no tab-indentation requirement, and no `.PHONY` boilerplate. It is declared in `devenv.nix` packages so its version is pinned per project. A global copy in `home.nix` is acceptable as a fallback for use outside any devenv project, but the devenv-declared version takes precedence inside a project (because devenv prepends to `$PATH`).

Every project's `justfile` must include a `setup` target. This is the single onboarding command a new developer runs after `direnv allow` — it installs pre-commit hooks and updates the devenv lockfile so nothing is forgotten:

```makefile
# justfile

# Default: list all available targets
default:
    @just --list

# Onboarding — run once after cloning
setup:
    uv python install 3.14   # idempotent — no-op if already installed; required for bench
    pre-commit install
    devenv update

# Format
fmt:
    ruff format .

# Lint (with autofix)
lint:
    ruff check --fix .

# Type check (fast, local only — mypy runs in CI, not here)
typecheck:
    pyright .

# Run tests
test:
    pytest tests/ -v

# Start development server
serve:
    bench serve --port 8000

# Start background worker
worker:
    bench worker --queue default

# Full reset (destroys Docker data — use with caution)
reset:
    docker compose down -v
    docker compose up -d
    devenv update
```

> [!warning] Use only `justfile` for project commands — not devenv `scripts` devenv has a native `scripts` block that can define shell commands. Do not use it alongside a `justfile`. Defining commands in both places creates two sources of truth for project workflows and leads to inconsistencies. Use `justfile` exclusively and leave the `scripts` block out of `devenv.nix`.

**The new developer onboarding flow** for a project using this setup:

```bash
git clone https://github.com/org/project.git
cd project
uv python install 3.14   # v16 prerequisite — installs the interpreter bench will use
direnv allow             # activates devenv, downloads packages (several minutes first time)
just setup               # installs pre-commit hooks, updates lockfile
docker compose up -d     # starts MariaDB and Redis
just serve               # starts the development server
```

> [!note] `uv python install 3.14` must come before `direnv allow` The devenv shell activates successfully without it — `languages.python` is absent for v16, so devenv has nothing to check. The failure is silent until `bench init` runs and cannot locate a 3.14 interpreter. Running this step first eliminates that confusion. It is idempotent: running it again when 3.14 is already installed is a no-op.

Five commands from zero to running development server, with reproducible tool versions.

---

### 8.10 Updating and Lockfiles

#### Why the Lockfile Matters

`devenv.nix` declares _which_ packages you want. `devenv.lock` records the exact Git revision of the nixpkgs input tree that was used to resolve those package declarations. Two developers with the same `devenv.nix` but different `devenv.lock` files may have different binary versions if nixpkgs was updated between their lockfile generations.

Committing `devenv.lock` is not optional. It is the mechanism that makes "same `devenv.nix`, same tools" a guarantee rather than an approximation.

#### When to Update

|Situation|Action|
|---|---|
|You added a package to `devenv.nix`|Save the file; Direnv re-activates automatically; run `devenv update` if the lock needs to change, then commit both `devenv.nix` and `devenv.lock`|
|You want newer tool versions (security patches, bug fixes)|Run `devenv update` explicitly; verify the project still works; commit|
|A teammate updated `devenv.lock` and pushed|`git pull`; Direnv re-activates with the new lockfile automatically|
|CI fails with a different tool version than local|Check that `devenv.lock` is committed and both local and CI are using it|

#### The Update Workflow

```bash
# 1. Update the lockfile to the latest nixpkgs commit
devenv update

# 2. Verify the project still works
just test

# 3. Commit both files together
git add devenv.nix devenv.lock
git commit -m "chore: update devenv lockfile"
git push
```

Always commit `devenv.nix` and `devenv.lock` together in the same commit. A `devenv.nix` with a new package but no corresponding lockfile update leaves the environment in an inconsistent state for teammates until they run `devenv update` themselves.

---

### 8.11 How to Evolve a Project Environment

|What you want to do|Where|How to apply|
|---|---|---|
|Add a binary tool (LSP, formatter, CLI)|`devenv.nix` packages list|Save file; Direnv re-activates automatically|
|Change Python version (v15)|`devenv.nix` `languages.python.version`|Save; `devenv update`|
|Change Python version (v16)|`uv python install <version>` — no `languages.python` block|See §8.4|
|Add a Python package|`requirements.txt`|Save; Direnv re-activates and re-installs|
|Add an environment variable|`devenv.nix` `env` block|Save; Direnv re-activates|
|Add a git hook|`devenv.nix` git-hooks block or `.pre-commit-config.yaml`|`just setup`|
|Add a project task|`justfile`|Available immediately after saving|
|Add a stateful service|`docker-compose.yml`|`docker compose up -d`|
|Remove a tool|Remove from `devenv.nix` packages|Save; next activation excludes it|
|Update all tool versions|`devenv update`|Commit the updated `devenv.lock`|

After any change to `devenv.nix` or `devenv.lock`:

```
1. Edit    → modify devenv.nix (or devenv.lock via devenv update)
2. Apply   → save the file — direnv re-activates automatically
3. Verify  → confirm the tool version or behaviour changed as expected
4. Commit  → git add devenv.nix devenv.lock && git commit && git push
```

Step 4 is never optional — an uncommitted `devenv.lock` change means teammates run `devenv update` to get your environment.

---

### Part 8 Summary

Devenv is the per-project layer: everything in `devenv.nix` is project-specific and applies to everyone working on that project. Everything in `home.nix` is personal and applies only to you across all projects. The boundary matters because crossing it in either direction creates problems — personal tools in `devenv.nix` create unnecessary version churn for teammates; project tools in `home.nix` are not portable to a new machine without extra steps.

The `$PATH` propagation chain (§8.5) — devenv → direnv → shell → Neovim LSP → VS Code extension — is the most frequent source of "my LSP can't find the binary" complaints. When in doubt, verify `which pyright` from the project directory and compare it to what the editor reports.

The v15/v16 split in `devenv.nix` is not a quirk — it reflects a genuine structural difference in how ERPNext manages Python across major versions. Read §8.3–8.4 carefully before setting up a new project.

**What carries forward:** Part 9 covers git and GitHub tooling — the layer that owns commits, branches, and collaboration workflows.

---

## Part 9: Git & GitHub Tooling Setup

> [!note] **What you now know**
> You can create a project environment with a `devenv.nix`, activate it with `direnv allow`, and get reproducible tool versions for every project. The ERPNext v15/v16 split is handled. Part 9 covers git and GitHub tooling.

---

> [!note] **What you will understand by the end of this part**
> - What gets installed, what the bootstrap already configured, and what still requires manual steps
> - Why delta must be configured for both `git` and `gh` independently
> - The three shell utility functions (`repo-status`, `gpr`, `gh-poi`) and how to add them to `home.nix`

_Installation and one-time configuration only. Day-to-day git workflows — branching, committing, PR lifecycle, rebasing — are in Dev Workflows._

This part covers what gets installed, what the bootstrap configures automatically, the two post-bootstrap manual steps specific to git tooling, and the three shell utility functions that must be added to `home.nix` during setup.

---

### 9.1 What Gets Installed and Why

Every tool in this table is installed by Home Manager (`home.nix` packages) unless noted otherwise.

|Tool|Role|Why this one|
|---|---|---|
|`git`|Version control|Foundational|
|`gh`|GitHub CLI|PRs, issues, CI status, and release management from the terminal without switching to a browser|
|`delta`|Diff viewer|Syntax-highlighted, side-by-side diffs with line numbers; dramatically easier to read than raw `git diff` output|
|`lazygit`|Visual git TUI|Hunk-level staging, interactive rebase, and visual commit history — operations that are impractical on the command line|
|`fzf`|Fuzzy search|Powers the `gpr` PR checkout function; also used throughout lazygit's interactive interfaces|
|`pre-commit`|Git hook manager|Enforces formatting and linting at commit time, editor-agnostically; installed via `uv tool install` (global tool, not per-project)|

`pre-commit` is the one tool not managed by Home Manager. It is installed via `uv tool install pre-commit` — `uv` manages it as a global tool available everywhere. `uv` itself is in `home.nix` packages.

---

### 9.2 What the Bootstrap Configures Automatically

The bootstrap handles several git-specific configuration steps that do not require user interaction.

#### Git Identity

Git identity — `user.name`, `user.email`, `init.defaultBranch` — is managed **declaratively by Home Manager** via `home.nix`. The bootstrap does not write `git config --global` calls. Instead, Step 5 of the bootstrap runs `hms`, which builds your Home Manager configuration and generates `~/.config/git/config` (or `~/.gitconfig`) from the values you declared in `home.nix`.

To verify your identity is configured correctly after the bootstrap:

```bash
git config --global user.name
git config --global user.email
```

To change your identity later, edit `home.nix` and run `hms` — not `git config --global`. The Home Manager–generated config will overwrite any manual changes on the next `hms` run.

#### Delta as Pager for `git` and `gh`

The delta pager for `git` is declared in `home.nix` via `programs.git` and applied by Home Manager. The `gh` pager is a runtime config value (`~/.config/gh/config.yml`) that Home Manager does not expose as a declarative option — the bootstrap sets it imperatively in Step 8 via `gh config set pager delta`.

> [!important] Two separate settings are required. `git` and `gh` have completely independent output pipelines. Home Manager manages the git pager. The bootstrap sets the gh pager. If you ever find that `gh pr diff` does not show delta highlighting but `git diff` does, run `gh config get pager` — it should print the path to the delta binary. If it does not, run `gh config set pager "$(which delta)"`.

```bash
# Verify both are set after bootstrap:
git config --global core.pager     # should print: delta (or path to delta)
gh config get pager                # should print: /home/you/.nix-profile/bin/delta
```

#### Git Aliases

These aliases are configured globally and used throughout Dev Workflows's workflows:

|Alias|Expands to|Purpose|
|---|---|---|
|`git sw`|`git switch`|Switch to an existing branch|
|`git co`|`git checkout -b`|Create and switch to a new branch|
|`git st`|`git status --short`|Compact status — changed files only, no prose|
|`git pushf`|`git push --force-with-lease --force-if-includes`|Force push safely — fails if remote has moved or was fetched but not incorporated|
|`git lg`|`git log --oneline --graph --decorate --all`|Visual commit graph across all branches|

`git pushf` deserves specific attention: `--force-with-lease` checks that the remote branch has not moved since your last fetch before overwriting it, and `--force-if-includes` adds a second guard that blocks the push if fetched remote commits are not reachable from your local branch. Plain `--force` overwrites regardless of what is there, including a teammate's commits. `git pushf` makes the safe option the default.

#### `pre-commit` Installation

```bash
uv tool install pre-commit
```

This installs `pre-commit` as a global tool available in all projects. It does not install hooks in any project — that step is per-repository and is handled by `just setup` (§9.9).

---

### 9.3 Post-Bootstrap Manual Steps

Two git-specific manual steps cannot be automated.

#### `gh auth login`

Covered in §2.5 Manual Step 2. Repeated here for completeness: GitHub CLI requires browser OAuth and cannot be scripted. Run `gh auth login` and confirm `repo` and `workflow` scopes are granted. Verify with `gh auth status`.

Without this step, every `gh` command fails with an authentication error. The `gpr` function (§9.4) and every PR-related workflow in Dev Workflows depends on `gh` being authenticated.

#### Per-repository `pre-commit install`

`pre-commit install` must be run once per developer per repository to install the hooks into `.git/hooks/`. This step is absorbed into `just setup` (§9.9) so it is never a separate manual step to remember — running `just setup` after cloning any project handles it automatically.

For repositories that do not have a `justfile`, run explicitly:

```bash
cd ~/projects/my-project
pre-commit install
```

Verify the hooks are installed:

```bash
ls .git/hooks/ | grep pre-commit
```

Expected output: `pre-commit` and `pre-commit.legacy` (or similar). If the directory is empty or missing these files, `pre-commit install` did not run successfully.

---

### 9.4 The Three Shell Utility Functions

These three functions belong in `home.nix` `programs.zsh.initContent`. They are referenced throughout Dev Workflows and must be installed during setup — adding them after the fact means they are missing the first time you need them.

Add all three to `programs.zsh.initContent` after the shell integration setup:

#### `repo-status` — Full Repository Snapshot

Runs all orientation commands at once. Use this at the start of every working session to answer four questions in one command: where am I, what has my attention, what's moving, what was I working on.

```bash
repo-status() {
  echo "════ Local State ══════════════════════════════"
  git branch -vv
  echo ""
  git st
  git stash list
  echo ""
  echo "════ Recent Commits ═══════════════════════════"
  git lg -5
  echo ""
  echo "════ PR & Review State ════════════════════════"
  gh pr status
  echo ""
  echo "════ Recent CI ════════════════════════════════"
  gh run list --limit 3
}
```

What each section shows:

- `git branch -vv`: all local branches with their remote tracking targets and ahead/behind counts
- `git st`: changed files in compact format
- `git stash list`: anything saved mid-work that might be forgotten
- `git lg -5`: the last five commits on the current graph — what were you working on?
- `gh pr status`: your open PRs, review requests, and CI status
- `gh run list --limit 3`: the three most recent CI runs

#### `gpr` — Fuzzy PR Checkout

Presents all open PRs as an fzf picker with a preview panel showing the PR body and CI status. Selecting a PR runs `gh pr checkout` to switch your local branch to that PR's branch.

```bash
gpr() {
  local pr
  pr=$(
    gh pr list \
      --json number,title,author,headRefName,statusCheckRollup \
      --template '{{range .}}{{tablerow .number .title .author.login .headRefName}}{{end}}' \
    | fzf \
      --prompt="  checkout PR: " \
      --pointer="▶" \
      --preview='gh pr view {1}' \
      --preview-window=right:60%:wrap \
      --border=rounded \
      --height=60% \
    | awk '{print $1}'
  )
  [ -n "$pr" ] && gh pr checkout "$pr"
}
```

Usage: type `gpr` from any terminal in a git repository. The fzf picker opens with all open PRs. The right panel shows the full PR description, status, and CI result for the highlighted PR. Press Enter to check out the branch locally.

This is faster than `gh pr checkout` with a PR number because you do not need to remember or look up the number — fuzzy search by title or author is enough.

#### `gh poi` — Delete Merged Local Branches

Deletes all local branches whose upstream has been merged or deleted. Keeps `main`, `master`, and `develop` untouched.

```bash
# Add as a gh CLI alias (run once, stored in gh config):
gh alias set poi 'pr list --state merged --json headRefName --jq ".[].headRefName" | xargs -I{} git branch -d {}'
```

Or as a shell function if you prefer it in `home.nix`:

```bash
poi() {
  echo "Fetching merged branches..."
  git fetch --prune
  git branch --merged main \
    | grep -vE '^\*|main|master|develop' \
    | xargs -r git branch -d
  echo "Done. Remaining local branches:"
  git branch
}
```

Usage: run `gh poi` (or `poi` if using the shell function) periodically — after a sprint, after a batch of PRs merges, or any time `git branch -a` becomes unreadably long. Merged branches are dead weight: they clutter branch lists, create confusion about what is still active, and slow down tools that scan branches.

> [!tip] Run `poi` at the start of each working week A week of active development typically produces 3–8 merged branches. Running `poi` Monday morning keeps the branch list manageable and makes `git lg --all` readable.

---

### 9.5 How to Add a New Git Tool

If you need a new git-related tool (a different diff viewer, a commit message linter, a git statistics tool):

**If it is a binary available in nixpkgs:**

```nix
# In home.nix packages:
home.packages = with pkgs; [
  # ...existing tools...
  your-new-git-tool
];
```

Apply: `hms`. Commit: `git add home.nix && git commit -m "feat: add your-new-git-tool"`.

**If it requires git configuration** (like delta's `core.pager` setting):

Add the config to `home.nix` `programs.git`:

```nix
programs.git = {
  enable = true;
  settings = {
    your-tool.setting = "value";
  };
};
```

**If it is a shell function:**

Add it to `home.nix` `programs.zsh.initContent` in the aliases block, following the pattern in §9.4. Apply with `hms`.

**If it is a `gh` CLI extension** (like `gh poi`):

```bash
gh extension install owner/repo-name
```

`gh` extensions are stored in `~/.local/share/gh/extensions/`. They are not managed by Home Manager. After installing, note the install command in a comment in `home.nix` so a new machine setup reminds you to run it:

```nix
# home.nix programs.zsh.initContent comment:
# Post-bootstrap: gh extension install nicokosi/gh-poi
```

---

### 9.6 How to Evolve Git Tooling

Every change to global git tooling follows the same loop:

```
1. Edit    → modify home.nix (programs.git, programs.zsh.initContent)
2. Apply   → hms
3. Verify  → confirm the tool or setting works as expected
4. Commit  → cd ~/dotfiles && git add home.nix && git commit && git push
```

---

### Part 9 Summary

All git configuration — identity, delta pager, aliases — is declared in `home.nix` `programs.git`. This means git config is reproducible across machines and never set manually. The bootstrap does not write a single line of `git config` directly.

The `gh`/`delta`/`lazygit` trio covers the three modes of git work: repository operations from the shell (`gh`), diff review (`delta`), and interactive branching and staging (`lazygit`). `gh poi` (or the local `poi()` shell function) solves the branch accumulation problem that builds up silently over weeks of feature work.

`gh` extensions are not managed by Home Manager. After a fresh bootstrap, they must be reinstalled manually. Leave a comment in `home.nix` as a reminder for new machine setup.

**What carries forward:** Part 10 covers Neovim with LazyVim — the most complex section of the guide, and the one that introduces the "project owns its config" philosophy that applies equally to VS Code.

---

**Next:** [5-Editors.md — Editor Configuration](5-Editors.md)
