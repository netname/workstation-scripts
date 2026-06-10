> **Development Workstation** · [Overview](0-Overview.md) · **Stack** · [Installation](2-Installation.md) · [Terminal](3-Terminal.md) · [Projects](4-Projects.md) · [Editors](5-Editors.md) · [Desktop](6-Desktop.md) · [Troubleshooting](7-Troubleshooting.md) · [Workflows](8-DevWorkflows.md)

## Part 1: Understanding the Stack — Read This First

_Understanding the model prevents hours of debugging later. Do not skip this._

This guide describes a layered, reproducible development environment using Nix, Home Manager, Devenv, Direnv, and Docker. It emphasizes clear ownership boundaries, predictable workflows, and recovery strategies.

> [!note] **What you will understand by the end of this part**
> - Why traditional development environment setups break, and what properties a solution needs
> - How the six-layer stack divides responsibility, and why those boundaries exist
> - What each tool (Nix, Home Manager, Devenv, Direnv, Docker) owns — and critically, what it does not own
> - How to diagnose any environment problem by identifying which layer is responsible
> - The Edit → Apply → Verify → Commit loop that governs every change you will ever make to this stack

---

### 1.1 The Problem with Traditional Setup

Consider this scene: a developer joins a project. The README says "install Python 3.11 and run `pip install -r requirements.txt`." They do it. Then they discover their system already has Python 3.9 for another project, and now both are broken. They install `pyenv`. It works. Three weeks later, `brew upgrade` runs in the background and silently upgrades Python 3.11 to 3.12. The project breaks on Friday afternoon with no obvious cause.

This is not bad luck. It is the predictable consequence of three specific problems:

**Tool version conflicts between projects.** Project A needs Python 3.11. Project B needs Python 3.9. Without isolation, only one can be "the system Python," and the other requires a workaround that inevitably drifts.

**No rollback when an update breaks something.** When `brew upgrade` or `apt upgrade` changes a tool version, there is no record of what changed and no one-command path back to the previous state. The environment accumulates changes that nobody tracks.

**New machine setup takes a full day.** The process is "install these twelve things, configure each one, copy some dotfiles, debug the parts that didn't transfer." It takes all day and the result is never quite identical to the original.

Each of these problems maps directly to a solution in the stack this guide assembles:

|Problem|Solution|
|---|---|
|Version conflicts between projects|Devenv: per-project isolated tool versions|
|No rollback|Home Manager generations: every change is reversible|
|New machine setup takes a day|Bootstrap script: one command, 20–40 minutes, reproducible result|

> [!important] The Goal By the end of this guide, your workstation is a version-controlled artifact. Setting up a new machine means cloning one repository and running one script. Changing a setting means editing one file and running one command. Breaking something means running one command to roll back.

---

### 1.2 The Layered Model

The stack has six layers. Each layer owns a specific concern. Each layer explicitly does _not_ own everything else. This boundary is the most important thing to understand: when something breaks, the boundary tells you exactly where to look.

|Layer|Owns|Does not own|
|---|---|---|
|**Host OS**|Hardware, kernel, display server|Package management|
|**Nix**|Reproducible packages in `/nix/store`|User config, project tools|
|**Home Manager**|Shell, global CLIs, stable dotfiles|Project-specific tools, secrets|
|**Devenv**|Per-project runtimes, LSPs, formatters|Stateful services, personal aliases|
|**Docker Compose**|Databases, caches, queues|Application code, dev tools|
|**Direnv**|Automatic environment activation on `cd`|Project tools, shell config, secrets|

**The debugging heuristic.** When something is broken or missing, use this table before reaching for a search engine:

|Symptom|Layer to inspect|Where to fix|
|---|---|---|
|Wrong tool version (e.g., `python --version` shows 3.9, expected 3.11)|Devenv|Edit `devenv.nix` packages — §1.7, [4-Projects.md §8.4](4-Projects.md)|
|Global alias or command missing (e.g., `lazygit` not found)|Home Manager|Edit `home.nix` packages — §1.4|
|Database not starting or connection refused|Docker Compose|Check `docker-compose.yml` and `docker compose ps` — §1.8, [4-Projects.md §8.6](4-Projects.md)|
|Environment not activating when you `cd` into a project|Direnv|Run `direnv allow`; check hook order — §1.6, [4-Projects.md §8.4](4-Projects.md)|
|Shell prompt looks wrong or missing icons|Home Manager (starship config) or Nerd Font|Edit `home.nix` programs.starship — §1.4; verify font — [3-Terminal.md §6.3](3-Terminal.md)|
|Neovim LSP not attaching|Devenv (binary missing from `$PATH`) or Home Manager (Neovim itself)|Check `which pyright-langserver`; verify `mason = false` — [5-Editors.md §10.11](5-Editors.md)|

This heuristic will not be correct one hundred percent of the time, but it will be correct ninety percent of the time, and it will get you to the right layer in under a minute.

---

### 1.3 Nix: The Foundation

#### What Nix Is

Nix is a package manager with one unusual property: every package is stored at a path that includes a cryptographic hash of all its inputs.

```
/nix/store/abc123def456-python-3.11.9/bin/python3
           ↑────────────┘
           Hash of: source code + all dependencies + build flags
```

This content-addressing model has a consequence that is difficult to appreciate until you have experienced it: two versions of the same package can coexist on the same machine without conflict, because they are stored at different paths. Python 3.9 and Python 3.11 are simply two different directories under `/nix/store`. Neither is "the system Python." Both exist. Each project uses whichever one its environment specifies.

The same expression evaluated on any machine produces the same result. If your colleague has the same `devenv.nix` as you, they have the same Python version, the same `ruff` version, the same `pyright` version. Not "approximately the same." Bit-for-bit identical.

#### What Nix Is Not

Nix is not a container. It does not sandbox processes at runtime the way Docker does. Two programs using different Nix-installed libraries can still communicate normally — the isolation is at install time (separate paths in `/nix/store`), not at runtime.

Nix does not replace Docker. Databases and caches have runtime state (data on disk, running processes, network ports). Nix manages packages, not runtime state. This is exactly why Docker Compose owns the service layer.

Nix does not manage secrets. Never put API keys, passwords, or private keys in Nix expressions.

#### The `/nix/store` Model in Practice

You will rarely interact with `/nix/store` directly. What matters is understanding why it behaves the way it does:

- **First activation of a new environment takes several minutes.** Nix is downloading packages from `cache.nixos.org` and placing them in `/nix/store`. This happens once per package version per machine. Every subsequent activation is instant.
- **Packages are never overwritten.** Upgrading a package installs a new entry in `/nix/store` alongside the old one. Nothing breaks until you explicitly switch.
- **Removing an old package is explicit.** Run `nix-collect-garbage` to remove packages no longer referenced by any active environment. This is like garbage collection in a programming language. Two important variants:
  - `nix-collect-garbage` — safe; removes unreferenced store paths but preserves all Home Manager generations (rollback history intact)
  - `nix-collect-garbage -d` — **destructive**; deletes all old generations before collecting, permanently removing your ability to roll back to any previous Home Manager state. Only use this when disk space is critically low and you are certain your current environment is stable. When in doubt, use the form without `-d`.

  **Why generations survive plain GC:** Each Home Manager generation is registered as a GC root — a pointer that tells Nix "this store path is still in use, do not collect it." Plain `nix-collect-garbage` respects those roots and leaves them alone. The `-d` flag removes the roots first, then collects, which is why it is irreversible. Your dotfiles repository is a separate safety net: even if all generations are deleted, you can always rebuild from `home.nix`. The generation history and the repository serve different purposes — generations give you instant rollback without a rebuild; the repository gives you recovery on a new machine.

> [!tip] Why this matters for you day-to-day When your colleague says "can you reproduce the bug I'm seeing?", the answer is yes — not because you trust that your machines are similar, but because your `devenv.lock` file records the exact Nix store hash for every tool in the project environment. Same hash = same binary = reproducible behavior.

> [!tip] **Common confusion: "which Python is the system Python?"**
> If you find yourself asking this, that is the right question — and the answer is: *there isn't one*. Nix does not replace or shadow a system Python. Each environment specifies the exact Python version it uses. `python3` in your global shell is the one declared in `home.nix`. `python3` inside a Devenv project is the one declared in `devenv.nix`. They are different binaries at different `/nix/store` paths and neither affects the other.

> [!tip] **Try it once the bootstrap completes**
> ```bash
> which git                     # /home/you/.nix-profile/bin/git — not /usr/bin/git
> readlink $(which git)         # resolves to a /nix/store/... path
> ls /nix/store | wc -l        # hundreds of store paths; each hash = a unique build
> ```
> The store path encodes the exact build inputs. Same hash on your machine = same binary as your colleague's.

---

### 1.4 Home Manager: Your Declarative User Environment

#### What Home Manager Manages

Home Manager is the layer that makes _your workstation_ reproducible. It manages:

- Your shell (`zsh`, with configuration and initialization hooks)
- Your global command-line tools (`lazygit`, `gh`, `fzf`, `bat`, `eza`, `ripgrep`, `fd`, `uv`, `tmux` binary, Neovim binary, and more)
- Your shell prompt (Starship)
- Your git configuration and aliases
- Your delta pager configuration
- The direnv hook that activates project environments
- Clipboard providers (`xclip` for X11, `wl-clipboard` for Wayland)

All of this is declared in a single file: `home.nix`.

#### How Home Manager Works

`hms` is a shell alias for `home-manager switch --flake ~/dotfiles#yourusername`. It is the one command you run after editing `home.nix`.

```
You edit home.nix
         ↓
hms  (= home-manager switch --flake ~/dotfiles#yourusername)
         ↓
Nix evaluates the expression
         ↓
Downloads any missing packages to /nix/store
         ↓
Generates ~/.zshrc (and other config files) from templates in home.nix
         ↓
Creates symlinks: ~/.zshrc → /nix/store/.../generated-zshrc
         ↓
Creates a new "generation" — a snapshot of this exact state
```

The generation system is the rollback mechanism. Every `hms` creates a new generation. If something breaks:

```bash
# See all generations — output includes the /nix/store path for each
home-manager generations

# Roll back to a previous generation: copy the store path and run its activate script
# Example (your path will differ):
/nix/store/rjzjszmwfrhmwzvqxhgy4l2a4rrr2xma-home-manager-generation/activate
```

> [!warning] Never edit `~/.zshrc` directly Home Manager generates `~/.zshrc` from templates in `home.nix`. Any edit you make to `~/.zshrc` directly will be silently overwritten the next time you run `hms`. All shell configuration goes in `home.nix`. This is not a limitation — it is what makes rollback work.

#### How to Evolve This Layer

**Adding a new global CLI tool:**

```nix
# In home.nix, add to home.packages:
home.packages = with pkgs; [
  # ... existing tools ...
  your-new-tool  # add here
];
```

Then apply the change:

```bash
hms
```

**What `hms` actually does.** When you run this command, Home Manager evaluates the Nix expression in `home.nix`, resolves every declared package to its exact path in `/nix/store`, downloads any packages that are not already cached, regenerates managed config files like `~/.zshrc` (from the templates you have declared in `home.nix`), creates symlinks from those generated files into your home directory, and finally records a new _generation_ — a snapshot of the complete resulting state. The old generation remains intact and reachable for rollback. The switch itself is atomic: either the entire new generation is activated, or the old one stays active. There is no partial state.

**Updating all packages to their latest Nix versions:**

```bash
# In your dotfiles directory:
nix flake update
hms
```

**What `nix flake update` does — and why it is a separate step.** Your `flake.nix` declares _which_ nixpkgs channel to use (for example, `github:nixos/nixpkgs/nixos-unstable`). But `flake.lock` records the exact Git commit hash of that channel that was used the last time you updated. This is what makes your environment reproducible: two machines with the same `flake.lock` get the exact same package versions, even if the channel has moved forward since you last updated.

`nix flake update` fetches the current commit hash of the nixpkgs channel and writes it into `flake.lock`. After this, `hms` rebuilds your environment using the newly pinned commit — meaning every package in `home.nix` is resolved against the updated nixpkgs tree and newer versions are downloaded and installed.

This is deliberately a two-step operation. If `nix flake update` automatically applied the changes, you would have no opportunity to review what changed before activating it. Keeping them separate means you can run `nix flake update` to pull the new lockfile, inspect the diff, and only then run `hms` to apply.

> [!important] Commit `flake.lock` after updating
> After `nix flake update && hms`, commit the updated `flake.lock` to your dotfiles repository. This records which version of nixpkgs your current environment is built from, and ensures a second machine running the bootstrap gets the same package versions — not whatever happens to be current at the time of that bootstrap.

**Rolling back if something breaks:**

```bash
home-manager generations
# Copy the /nix/store path of the generation you want
/nix/store/<hash>-home-manager-generation/activate
```

Rollback activates the previous generation by re-running its stored activation script. Because each generation is a complete self-contained snapshot in `/nix/store`, the rollback does not require re-downloading anything — it is instantaneous. The packages, generated config files, and symlinks from the previous generation are all already on disk.

> [!tip] **Common confusion: `flake.nix` vs `flake.lock` vs `home.nix`**
> These are three different files with three different jobs. `flake.nix` declares *which* nixpkgs channel to track (e.g. `nixos-unstable`). `flake.lock` records the exact Git commit of that channel currently in use — this is what makes builds reproducible across machines. `home.nix` declares *what to install* from that pinned channel. The mental model: `flake.nix` says "watch this channel," `flake.lock` says "use this exact snapshot of it," `home.nix` says "give me these packages from that snapshot."

> [!tip] **Try it once the bootstrap completes**
> ```bash
> home-manager generations           # see your full generation history
> ls -la ~/.zshrc                     # it is a symlink, not a regular file
> readlink ~/.zshrc                   # resolves to /nix/store/.../zshrc
> head -3 ~/.zshrc                    # first line: "# Generated by Home Manager. Do not edit."
> ```
> The symlink and the "do not edit" header are the generation system made visible. Every `hms` creates a new entry in `home-manager generations` and repoints these symlinks atomically.

---

### 1.5 The Dotfile Boundary: What Home Manager Manages vs. What You Manage Directly

_This is the most important design decision in the stack. Everything else depends on understanding this boundary._

Not every configuration file benefits from going through the Nix build step. Some tools need to be tuned frequently, and the iteration cycle of "edit file → wait 30–60 seconds for Nix evaluation → see result" is too slow for that kind of tuning. For those tools, a faster pattern exists: manage the file directly, symlink it into place, reload in under a second.

The stack uses both patterns. Here is the complete boundary:

#### Home Manager Manages (Stable, Benefit from Reproducibility guarantee)

These tools are configured in `home.nix` and rebuilt by Home Manager:

- **Shell**: `zsh` and all its initialization hooks
- **Shell prompt**: Starship
- **Direnv**: the hook that runs `eval "$(direnv hook zsh)"` — placed manually at position 3 in `initContent` rather than via `enableZshIntegration`, so it loads early enough for tmux pane shells (see [3-Terminal.md §7.4](3-Terminal.md))
- **Git**: `user.name`, `user.email`, delta as pager, standard aliases
- **Delta**: diff pager configuration
- **All global CLI binaries**: `gh`, `lazygit`, `fzf`, `bat`, `eza`, `ripgrep`, `fd`, `uv`, `just`, `tmux` (the binary), Neovim (the binary), `tree-sitter`, `gcc`, `xclip`/`wl-clipboard`

These are stable tools that you set up once and rarely change. The reproducibility guarantee is worth the rebuild overhead.

#### You Manage Directly (Frequently Tuned, Instant Reload needed)

These files live in `~/dotfiles/` and are symlinked into place by the bootstrap script. They bypass the Nix build step entirely:

|File|Symlink target|Reload command|
|---|---|---|
|`~/dotfiles/wezterm/wezterm.lua`|`~/.config/wezterm/wezterm.lua`|`SUPER+SHIFT+R` (under 1 second)|
|`~/dotfiles/tmux/tmux.conf`|`~/.config/tmux/tmux.conf`|`prefix r` (under 1 second)|
|`~/dotfiles/scripts/sessionizer`|`~/.local/bin/sessionizer`|Takes effect immediately|

**Why WezTerm and tmux are user-managed.** Font size, color scheme, padding, and `default_prog` in WezTerm are tuned to your specific hardware: monitor DPI, whether you're on a laptop or external display, personal preference for font rendering. A single-pixel padding change should take one second, not sixty. The same logic applies to tmux: prefix key choice, status bar layout, and keybindings are deeply personal and change often during the first weeks of use.

These files are still version-controlled in your dotfiles repository. The boundary is not between "version-controlled" and "not version-controlled" — it is between "rebuilt by Nix" and "symlinked directly."

> [!important] The symlink model Both categories of files end up in the same place: version-controlled in `~/dotfiles/`, accessible at their expected config paths. The difference is how they get there.
> 
> - Home Manager files: `home.nix` → Nix build → generated files in `/nix/store` → symlinked to `~/.*`
> - User-managed files: `~/dotfiles/file` → bootstrap symlink → `~/.config/file`
> 
> The bootstrap script handles both. §2.4 covers the exact symlink commands.

#### How to Evolve This Layer

The key question when making any change is: _which side of the boundary does this fall on?_ The answer determines both where you edit and how you apply the change.

**Path A — Changing something Home Manager manages (shell, git, global tools, prompt):**

The workflow is always the same:

```bash
# 1. Edit the file
nvim ~/dotfiles/home.nix

# 2. Apply — Nix evaluates home.nix, rebuilds the relevant outputs,
#    regenerates ~/.zshrc (and other managed files), updates symlinks,
#    and records a new generation.
hms

# 3. Verify in a new shell (the current shell has the old .zshrc in memory)
exec zsh   # or open a new terminal

# 4. Commit
cd ~/dotfiles
git add home.nix
git commit -m "describe what changed"
git push
```

Note that step 3 requires a new shell for shell-config changes: `hms` writes the new `~/.zshrc`, but the shell you are currently running has already loaded the old one into memory. Opening a new terminal (or running `exec zsh`) picks up the regenerated file.

**Path B — Changing something you manage directly (WezTerm, tmux, sessionizer):**

The workflow is faster and requires no Nix evaluation:

```bash
# 1. Edit the file in your dotfiles directory
nvim ~/dotfiles/wezterm/wezterm.lua   # or tmux/tmux.conf, scripts/sessionizer

# 2. Apply — because the file is symlinked directly, the tool reads the
#    updated file the moment it is saved. You just need to signal the tool
#    to re-read it.
#    - WezTerm:   press SUPER+SHIFT+R (takes effect in under 1 second)
#    - tmux:      press prefix r       (takes effect in under 1 second)
#    - sessionizer: takes effect immediately (it is re-executed on each call)

# 3. Verify visually or behaviourally

# 4. Commit
cd ~/dotfiles
git add wezterm/wezterm.lua   # (or the relevant file)
git commit -m "describe what changed"
git push
```

The speed difference is why the boundary exists at all. For tools you tune during initial setup — tweaking font size, adjusting padding, experimenting with tmux keybindings — the difference between a 1-second reload and a 30–60-second Nix rebuild changes how you work. You can iterate in real time instead of waiting.

The table below maps common changes to the correct path:

|What you want to change|Where to make the change|How to apply|
|---|---|---|
|Add a global CLI tool|`home.nix` packages list|`hms`|
|Change shell prompt appearance|`home.nix` programs.starship|`hms`|
|Change git aliases|`home.nix` programs.git|`hms`|
|Change terminal font or colors|`~/dotfiles/wezterm/wezterm.lua`|`SUPER+SHIFT+R`|
|Change tmux prefix or keybindings|`~/dotfiles/tmux/tmux.conf`|`prefix r`|
|Add a tmux plugin|`~/dotfiles/tmux/tmux.conf` TPM `@plugin` list|`prefix r`, then `prefix + I`|
|Update all Nix packages|`nix flake update` in dotfiles repo|`hms`|

---

### 1.6 Direnv: The Glue Between Layers

Direnv solves exactly one problem: it watches for `.envrc` files and loads or unloads the environment they describe, automatically, whenever you `cd` into or out of a directory. It is the mechanism that makes per-project environments invisible — you `cd` into a project and the right tools are available; you `cd` out and they are gone.

#### The Full Activation Chain

When you `cd` into a project directory, this sequence happens:

```
1.  cd ~/projects/my-project

2.  Direnv detects .envrc in the directory

3.  Direnv reads .envrc
    Contents: use devenv

4.  Devenv evaluates devenv.nix via Nix

5.  First time only: Nix downloads packages from cache.nixos.org
    (this takes several minutes; subsequent activations are instant)

6.  Devenv builds the project shell environment:
    - Adds tool binaries to $PATH
    - Sets environment variables from devenv.nix env block
    - Activates Python virtualenv (if configured)
    - Runs enterShell commands (if configured)

7.  Starship prompt updates to reflect the active environment

8.  VS Code (via mkhl.direnv extension) detects the activation
    and updates extensions' $PATH to use devenv's binaries
```

When you `cd` out of the project, Direnv reverses step 6: the additions to `$PATH` are removed and environment variables are unset. Your global shell is restored exactly as it was.

> [!important] First-activation latency The first time you activate a new environment, Nix downloads packages from `cache.nixos.org`. This can take **several minutes** depending on your internet connection and how many packages the project needs. This is normal. Every subsequent activation of the same environment (same `devenv.lock`) is instant from the Nix store cache.
> 
> If the first activation seems frozen: it is not. Open a second terminal and run `watch -n1 ls /nix/store | wc -l` to confirm packages are being downloaded.

#### The One Required Step Per Developer Per Repo

Direnv will not load an `.envrc` file it has not been told to trust. The first time you enter a project, you will see:

```
direnv: error /home/you/projects/my-project/.envrc is blocked.
Run `direnv allow` to approve its content.
```

Run exactly that:

```bash
direnv allow
```

This stores a hash of the `.envrc` file. If the file changes (e.g., a teammate updates it), Direnv blocks it again and you must re-run `direnv allow` after reviewing the change.

> [!warning] `direnv allow` must be run once per developer per repository This is intentional security behavior. An `.envrc` file could execute arbitrary shell code. Direnv requires explicit approval before running it. Always review the `.envrc` contents before approving — `cat .envrc` first.

> [!tip] **Common confusion: "direnv works in the terminal but not in Neovim or VS Code"**
> The editor was launched from a context where the direnv hook did not run, or it was opened before `cd`-ing into the project directory. Direnv only activates when a shell with the `eval "$(direnv hook zsh)"` hook changes directory. Editors need their own integration: Neovim uses the `mkhl/direnv.nvim` plugin; VS Code uses the `mkhl.direnv` extension. Both are configured in this stack. If an LSP cannot find a project tool (pyright, ruff, typescript-language-server), the most likely cause is that the editor's shell did not inherit the Devenv `$PATH`. [4-Projects.md §8.5](4-Projects.md) covers the full `$PATH` propagation chain.

---

### 1.7 Devenv: Per-Project Environments

#### What Devenv Does

Devenv builds on Nix to provide declarative, per-project development environments. You write a `devenv.nix` file that declares everything the project needs:

```nix
# devenv.nix — example:
{ pkgs, ... }: {
  packages = [
    pkgs.pyright      # Python LSP server
    pkgs.ruff         # Python formatter and linter
    pkgs.just         # Task runner
  ];

  # For ERPNext v15 — use languages.python with version = "3.11".
  # For ERPNext v16 — omit this block; uv manages Python 3.14 instead.
  # See [4-Projects.md §8.4](4-Projects.md) for the full v15/v16 split and the BENCH_USE_UV explanation.
  languages.python = {
    enable = true;
    version = "3.11";
    venv.enable = true;
    venv.requirements = ./requirements.txt;
  };

  env = {
    BENCH_USE_UV = "1";   # required for v16; harmless for v15
    DATABASE_URL = "mysql://root:123@localhost:3306/erpnext";
  };
}
```

Commit this file to the repository. Every developer who clones the repo and runs `direnv allow` gets this exact environment — same Python version, same tool versions, same environment variables.

#### Devenv vs. Home Manager: The Critical Distinction

||Home Manager|Devenv|
|---|---|---|
|**Scope**|You, across all projects|This project, regardless of who runs it|
|**Example content**|Your preferred shell aliases, your lazygit|The Python version, pyright, ruff|
|**Who decides**|You|The project (committed to the repo)|
|**Lives in**|`~/dotfiles/home.nix`|`projectroot/devenv.nix`|
|**Activated by**|Login / shell startup|`direnv allow` + `cd` into project|

> [!tip] The rule of thumb If a tool's version matters for the project to work correctly, it belongs in Devenv. If a tool is purely personal workflow preference and any version works, it belongs in Home Manager.
> 
> **Example:** `pyright` version matters — if version 1.1.350 introduces a stricter type check and you use 1.1.340, you'll see different diagnostics than your CI pipeline. Pyright goes in `devenv.nix`.
> 
> **Example:** `lazygit` version doesn't affect the project at all. Any recent version works. Lazygit goes in `home.nix`.

#### What Belongs in `devenv.nix`

- Language runtimes: Python version, Node version
- LSP server binaries: `pyright`, `typescript-language-server`
- Formatter and linter binaries: `ruff`, `prettier`, `eslint`
- Project-specific environment variables: database URLs, feature flags
- Git hooks (if using devenv git-hooks — covered in [4-Projects.md §8.8](4-Projects.md))
- `just` (the project's task runner — pinned per project so `justfile` commands use a consistent version; a global fallback copy in `home.nix` is acceptable for use outside any devenv project)

#### What Does Not Belong in `devenv.nix`

- Personal shell aliases (those go in `home.nix`)
- Global tools you use across all projects (those go in `home.nix`)
- Stateful services like MariaDB or Redis (those go in `docker-compose.yml` — §1.8)
- `debugpy` — this is a critical exception covered in detail in [5-Editors.md §10.13](5-Editors.md)

> [!warning] The `debugpy` exception `debugpy` cannot go in `devenv.nix packages`. It requires special installation into the project's Python virtualenv. Full explanation and setup in [5-Editors.md §10.13](5-Editors.md).

---

### 1.8 Docker Compose: Stateful Services

#### The Governing Principle

> **Devenv owns tools. Docker Compose owns state.**

This is not a preference. It is a consequence of what these systems are.

Devenv environments are Nix derivations: they are built, they produce a shell with specific tools on `$PATH`, and they can be rebuilt at any time. Rebuilding is safe because the environment contains _no data_. It is like reinstalling a program — the program's files change, but the data files it works with are unaffected.

MariaDB stores your development database in files. Redis stores cache state. These are not programs — they are services with persistent data. If you ran MariaDB inside Devenv, every `devenv update` could wipe your development database.

Docker Compose gives stateful services their own isolated filesystem and preserves data in named volumes that survive container restarts, rebuilds, and even Docker upgrades.

#### Why Application Code Cannot Live in Docker During Development

The other half of the boundary: your application code runs on your workstation, not inside a container.

Running your Python application server inside a Docker container during development creates several problems:

- **Hot-reload breaks.** File watchers inside a container watch container filesystems, not host filesystems. Volume mounts introduce latency and inotify edge cases.
- **Debuggers cannot attach cleanly.** DAP debuggers ([5-Editors.md §10.13](5-Editors.md)) attach to a running Python process. Attaching through a container boundary requires extra configuration that almost never works perfectly.
- **LSPs cannot resolve imports.** Pyright runs on your workstation and needs to read your project's Python files. If those files are inside a container, Pyright cannot see them without workarounds that add more complexity.

The correct model:

```
Your workstation:                    Docker:
  Python app (Devenv venv)      ←→    MariaDB (named volume)
  Neovim + pyright                    Redis cache (named volume)
  Debugger (debugpy in venv)          Redis queue (named volume)
  Hot-reload (watches real files)     Redis socketio (named volume)
```

The app talks to the Docker services over `localhost`. To the app, MariaDB at `localhost:3306` is indistinguishable from a locally-installed MariaDB. You get the persistence and isolation of Docker without any of the development friction.

#### What Docker Compose Provides

- **Isolation**: services run in containers with their own filesystems; they cannot interfere with your development tools
- **Persistence**: named volumes survive `docker compose down` and `docker compose up`; your development database survives a container restart
- **Consistent versions**: `image: mariadb:11.8` is pinned; every developer uses the same MariaDB version
- **Simple lifecycle**: `docker compose up -d` to start all services; `docker compose down` to stop them; `docker compose logs -f mariadb` to debug

Common daily commands:

```bash
# Start all services in the background
docker compose up -d

# Check service status
docker compose ps

# Tail logs from a specific service
docker compose logs -f mariadb

# Stop all services (data is preserved in named volumes)
docker compose down

# Stop all services AND delete all data (destructive — use with caution)
docker compose down -v
```

---

### 1.9 How to Evolve Each Layer — [Reference]

> [!note] **This is a reference section.** Read it once now to build the mental model of where changes belong. Then bookmark it — after initial setup, this table answers the majority of day-to-day "where do I make this change?" questions without needing to re-read any other section.

This is the reference you will reach for after initial setup. Every question a developer asks after the bootstrap is complete maps to exactly one answer here.

|What you want to do|Where|Command|
|---|---|---|
|Add a new global CLI tool|`home.nix` packages list|`hms`|
|Add a new project runtime or tool|`devenv.nix` packages|Save the file; Direnv re-activates|
|Change Python version for a project (v15)|`devenv.nix` `languages.python.version`|`devenv update`|
|Change Python version for a project (v16)|`uv python install <version>` — no `languages.python` block exists|See [4-Projects.md §8.4](4-Projects.md)|
|Change shell prompt appearance|`home.nix` `programs.starship`|`hms`|
|Change terminal font, colors, or padding|`~/dotfiles/wezterm/wezterm.lua`|`SUPER+SHIFT+R`|
|Change tmux prefix key or keybindings|`~/dotfiles/tmux/tmux.conf`|`prefix r`|
|Add a tmux plugin|`~/dotfiles/tmux/tmux.conf` TPM `@plugin` list|`prefix r`, then `prefix + I`|
|Add a new stateful service (database, queue)|`docker-compose.yml`|`docker compose up -d`|
|Update all Nix packages globally|`nix flake update` in dotfiles repo|`hms`|
|Update all Nix packages for a project|`devenv update` in project root|Direnv re-activates|
|Roll back a Home Manager change|`home-manager generations`; copy the store path|`/nix/store/<hash>-home-manager-generation/activate`|
|Roll back a Devenv change|`git checkout devenv.nix devenv.lock`|`devenv update`|
|Add a new shell function or alias|`home.nix` `programs.zsh.initContent`|`hms`|
|Add a project environment variable|`devenv.nix` `env` block|Save the file; Direnv re-activates|

> [!tip] The decision rule If the change is personal (affects you across all projects), it belongs in `home.nix`. If the change is project-specific (affects everyone who works on this project), it belongs in `devenv.nix` or `docker-compose.yml`. If it is a personal tool with instant-reload needs, it is a user-managed dotfile.

---

### 1.10 Secrets: What the Stack Does Not Handle

Every layer in this stack has a hard rule about secrets: none of them store secrets. The rule exists at every level for the same reason.

**Why Nix expressions must never contain secrets.** Anything declared in a Nix expression — `home.nix`, `devenv.nix`, `flake.nix` — is evaluated, built, and stored as a path in `/nix/store`. The Nix store is world-readable by any process on the machine. A secret placed in a Nix expression is not encrypted, not protected by file permissions, and may appear in build logs. Treat Nix files as public documents.

**Why `.envrc` must never contain secrets.** `.envrc` is committed to the project repository. Any secret written directly into `.envrc` is in your git history permanently — including after deletion, because git retains the full commit history.

#### The Pattern the Doc Uses: `.env` Loaded in `enterShell`

The `devenv.nix` examples in this guide use a `.env` file loaded via `enterShell`. This is the correct baseline pattern for local development secrets:

```bash
# In enterShell block of devenv.nix:
if [ -f .env ]; then
  set -a; source .env; set +a
fi
```

The `.env` file is in `.gitignore`. Each developer creates their own with local credentials. It is never committed, never in the store, and never in `.envrc`. This handles the common case: database passwords, local API keys, per-developer config.

**What this pattern does not cover:**

- Shared team secrets (each developer has their own copy, creating drift)
- Secrets needed at build time by Nix itself
- CI/CD pipelines that need the same secrets without a local `.env` file

#### The Next Step: SOPS + Age

When the `.env` file pattern is insufficient — typically when you need shared, auditable, encrypted secrets in the repository — the standard path in the Nix ecosystem is `sops-nix` with Age encryption.

The flow:

```
secrets.yaml (encrypted, committed to Git)
   ↓
sops-nix (decrypts at activation time using your Age key)
   ↓
plaintext values available at runtime (never stored in /nix/store or repo)
```

SOPS + Age is not configured in this guide's bootstrap. Setting it up requires generating an Age key, configuring which keys can decrypt which files, and adding `sops-nix` as a Home Manager module. The official documentation is at [github.com/Mic92/sops-nix](https://github.com/Mic92/sops-nix).

> [!warning] Back up your Age and SSH keys before you need to Your dotfiles repository makes the environment reproducible, but it does not make your secrets recoverable. If you adopt SOPS + Age and lose your Age private key, every secret encrypted to that key is permanently unrecoverable. Back up the key — `~/.config/sops/age/keys.txt` by default — to an offline location (encrypted USB, password manager secure note) immediately after generating it. The same applies to your SSH private key at `~/.ssh/id_ed25519`. These are the two assets not captured by the dotfiles repository that cannot be regenerated from it.

---

### 1.11 Part 1 Summary: The Stack at a Glance

You have now read the conceptual foundation. These two references summarise everything in Part 1. Return to them whenever you are debugging or deciding where a change belongs.

#### The Layer Map

```
User Shell
   ↓
Direnv (auto-activation on cd)
   ↓
Devenv (per-project tools, runtimes, LSPs)
   ↓
Home Manager (your global tools, shell, git, dotfiles)
   ↓
Nix (reproducible build + /nix/store)
   ↓
/nix/store (immutable, content-addressed artifacts)

Side layer:
Docker Compose (stateful services: databases, caches, queues)
```

**Layer ownership at a glance:**

| Layer | Owns | Does not own |
|---|---|---|
| **Host OS** | Hardware, kernel, display server | Package management |
| **Nix** | Reproducible packages in `/nix/store` | User config, project tools |
| **Home Manager** | Shell, global CLIs, stable dotfiles | Project-specific tools, secrets |
| **Devenv** | Per-project runtimes, LSPs, formatters | Stateful services, personal aliases |
| **Docker Compose** | Databases, caches, queues | Application code, dev tools |
| **Direnv** | Automatic environment activation | Project tools, shell config, secrets |

#### The Four-Step Loop

Every change to this environment — adding a tool, changing a setting, fixing a broken config — follows the same cycle:

```
1. Edit    → modify the relevant file in ~/dotfiles/
2. Apply   → run the activation command (hms, SUPER+SHIFT+R, prefix r…)
3. Verify  → confirm the change works
4. Commit  → git add, commit, push — make it part of the record
```

Step 4 is never optional. A change that is not committed exists only on this machine.

> [!tip] **The one debugging question** When anything breaks or is missing, ask: *which layer owns this?* Find the layer in the table above, then go to that layer's section. Ninety percent of environment problems resolve in under a minute with this question.

---

### Glossary

Key terms used throughout this guide. Each entry links to the section where it is explained in depth.

**Activation** — The process of switching to a new Home Manager generation (`hms`) or entering a Devenv environment (via Direnv on `cd`). Activation updates symlinks, modifies `$PATH`, and runs shell hooks. See §1.4, §1.6.

**Derivation** — A Nix build instruction: a description of inputs (source, dependencies, build flags) that produces a deterministic output in `/nix/store`. Every Nix-managed package is the result of evaluating a derivation.

**Devenv** — A tool that builds per-project development environments on top of Nix. Declared in `devenv.nix`; activated automatically by Direnv when you `cd` into the project. See §1.7, Part 8.

**Direnv** — A shell extension that loads and unloads environment variables automatically when you `cd` into or out of a directory containing an `.envrc` file. The trigger mechanism that makes per-project environments invisible. See §1.6.

**Flake** — A Nix project structure that declares its inputs and outputs in `flake.nix`. Used here for Home Manager (`~/dotfiles/flake.nix`) and Devenv projects. Flakes make builds reproducible via `flake.lock`.

**`flake.lock`** — The lock file that records the exact Git commit hash of every flake input (e.g., which commit of nixpkgs is in use). Always commit this file. Same lock = same package versions on every machine.

**GC root** — A pointer registered with Nix that marks a store path as still in use. Nix garbage collection will not delete store paths reachable from a GC root. Each Home Manager generation is a GC root; `nix-collect-garbage` (without `-d`) respects them. See §1.3.

**Generation** — A complete, immutable snapshot of a Home Manager environment state stored in `/nix/store`. Every `hms` creates a new generation. Activating an old generation's script rolls back instantly without re-downloading anything. See §1.4.

**`hms`** — Shell alias for `home-manager switch --flake ~/dotfiles#yourusername`. The command that applies `home.nix` changes. Defined in `home.nix` `programs.zsh.shellAliases`.

**Home Manager** — A Nix-based tool that manages your user environment declaratively: shell, global CLI tools, git config, and stable dotfiles. Configured in `home.nix`. See §1.4.

**`home.nix`** — The file where your global user environment is declared. Lives in your private `dotfiles` repository.

**Store path** — A path under `/nix/store/` of the form `/nix/store/<hash>-<name>/`. Nix-managed packages, generated config files, and Home Manager generations all live here. Store paths are immutable once created.

**User-managed dotfile** — A config file (`wezterm.lua`, `tmux.conf`, `sessionizer`) stored in `~/dotfiles/` and symlinked directly into place, bypassing the Nix build step entirely. Changes reload in under a second. Contrasted with Home Manager-managed files. See §1.5.

---
**Next:** [2-Installation.md — From Zero to Working Workstation](2-Installation.md)
