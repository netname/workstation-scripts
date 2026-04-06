## Before You Start — What This Guide Does and How to Use It

This guide builds a complete, reproducible development environment on Ubuntu using Nix, Home Manager, tmux, Neovim, and Docker. By the end, your workstation is a version-controlled artifact: setting up a new machine is one command, changing a setting is editing one file, and rolling back a mistake is one command.

**What gets installed:**

| Tool | Role |
|---|---|
| Nix + Home Manager | Reproducible global packages and shell config |
| tmux + sessionizer | Persistent workspaces, one keypress per project |
| Neovim + LazyVim | Editor with LSP, formatting, debugging |
| Devenv + Direnv | Per-project isolated tool versions |
| Docker Compose | Databases and services (MariaDB, Redis) |
| VS Code | Parallel editor path |
| WezTerm | Terminal emulator |

**How long it takes:** 20–40 minutes for the automated bootstrap on a fresh machine, plus time reading each part as you configure tools to your preferences.

---

### The Two-Repository Model

Before running anything, you need two GitHub repositories. Understanding why there are two — and why they have different visibility — is the first thing this guide asks you to understand.

**Why two repositories?**

The setup scripts (`bootstrap.sh`, `setup-base.sh`, `setup-desktop.sh`) must be fetchable with a single `curl` command on a brand-new machine that has no SSH key, no git configuration, and possibly no clipboard. `curl` fetches files over HTTPS anonymously — it cannot access a private repository. So the scripts must live in a **public** repository.

Your personal configuration — `home.nix`, `flake.nix`, `wezterm.lua`, `tmux.conf`, your shell aliases, your git identity — is private. It should not be publicly visible on the internet. So your dotfiles must live in a **private** repository.

The two repositories serve different purposes and have different audiences:

| Repository | Visibility | Purpose | Contents |
|---|---|---|---|
| `workstation-scripts` | **Public** | Scripts fetchable by any new machine via `curl` | `bootstrap.sh`, `setup-base.sh`, `setup-desktop.sh` |
| `dotfiles` | **Private** | Your personal environment declaration | `flake.nix`, `home.nix`, `wezterm.lua`, `tmux.conf`, `sessionizer`, and all personal config |

**How they work together:**

```
Step 1 — On a new machine, with nothing installed:
  wget → workstation-scripts/setup-base.sh   (installs curl, git, openssh-client, build-essential)

Step 2 — Still no SSH key:
  ssh-keygen generates a key locally
  you register the public key on GitHub
  ssh -T git@github.com verifies the key works

Step 3 — SSH key registered:
  wget → workstation-scripts/bootstrap.sh    (runs the full bootstrap, fully unattended)
  bootstrap verifies SSH key → exits with instructions if missing
  bootstrap clones your PRIVATE dotfiles repo via SSH
  hms builds your environment
```

`wget` only ever touches the public repository — it never needs credentials. The private dotfiles repository is only reached after the SSH key is registered, so it stays private throughout.

> [!note] **This guide is a reference implementation.** The scripts and configuration files in the appendices are complete, working examples that you copy into your own repositories. You do not fork or clone this guide — you create your own `workstation-scripts` and `dotfiles` repositories and populate them from the reference material here. Appendix M walks through the exact steps to create both repositories from scratch.

---

### Installation

#### All steps at a glance

| # | Step | Where | Time |
|---|---|---|---|
| **0** | Create two GitHub repositories, populate scripts and config, set your git identity | Your machine (once) | 15–30 min |
| **1** | Install apt prerequisites | Target machine | ~2 min |
| **2** | Generate an SSH key and register it on GitHub | Target machine | ~5 min |
| **3** | Run the bootstrap | Target machine | 20–40 min |
| **4** | Complete post-bootstrap steps (re-login, authenticate CLI tools) | Target machine | ~5 min |
| **5** | *(Desktop only)* Install the desktop layer | Target machine | ~10 min |
| **6** | *(Desktop only)* Reboot and connect via RDP | — | ~5 min |
| **7** | Verify the installation | Target machine | ~5 min |

**Step 0 is a one-time setup.** If your repositories already exist and are configured (you are setting up a second or replacement machine), skip Step 0 and start at Step 1.

> [!note] **VMware users:** See Appendix K before Step 1.

---

#### Which setup are you doing?

| | Headless / server | Graphical desktop |
|---|---|---|
| **What you get** | Full dev environment over SSH: tmux, Neovim, Docker, Gemini CLI, GitHub CLI | Everything above, plus XFCE4 desktop, XRDP remote access, WezTerm, VS Code, Chrome, ksnip |
| **Typical use** | Cloud VM, server, VPS, VM you SSH into | VMware/VirtualBox VM or bare metal with a monitor (or RDP access from Windows) |
| **Steps** | 0–4, then 7 | 0–7 |

---

#### Step 0 — Create and configure your repositories (first machine only)

> [!tip] **📋 Full walkthrough in Appendix M.** Appendix M creates both GitHub repositories from scratch and populates them with all reference files. Follow it now if you haven't already, then return here.

Before running anything on a new machine, two repositories must exist, be populated, and be **pushed to GitHub**:

- `workstation-scripts` (public) — `bootstrap.sh`, `setup-base.sh`, `setup-desktop.sh`
- `dotfiles` (private) — `flake.nix`, `home.nix`, and your personal config

**What to personalise in `home.nix` before pushing:**

| Setting | Where in `home.nix` | What to enter |
|---|---|---|
| Linux username | `home.username` and `home.homeDirectory` | Output of `whoami` on the target machine |
| Git name | `programs.git.settings.user.name` | Your full name, e.g. `"Jane Smith"` |
| Git email | `programs.git.settings.user.email` | The email address registered on your GitHub account |

`init.defaultBranch = "main"` is already set in the Appendix B reference — no change needed. Also replace `yourusername` in `flake.nix` with your Linux username.

**What to personalise in `bootstrap.sh` before pushing:**

```bash
GITHUB_USER="yourusername"                              # ← your GitHub username
DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"  # ← your private dotfiles SSH URL
```

> [!important] Push both repositories before continuing. The bootstrap fetches scripts directly from GitHub — local changes that have not been pushed are invisible to it.

---

**Step 1 — Install apt prerequisites** (~2 minutes)

On the machine where you want the environment installed:

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/setup-base.sh | bash
```

Replace `yourusername` with your GitHub username. This installs `curl`, `wget`, `git`, `openssh-client`, `build-essential`, `ca-certificates`, and other apt prerequisites. `wget` is pre-installed on Ubuntu 22.04 and 24.04 — no other tools are required.

---

**Step 2 — Generate your SSH key and register it on GitHub** (~5 minutes)

The bootstrap needs an SSH key to clone your private dotfiles repository. Do this before running the bootstrap.

```bash
ssh-keygen -t ed25519 -C "yourusername@workstation" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

Copy the entire line starting with `ssh-ed25519`. Go to [github.com/settings/keys](https://github.com/settings/keys) → **New SSH key** → paste and save.

> [!note] **Headless machine (server or VM with no browser)?** Copy the public key to your local machine and paste it from there:
>
> ```bash
> # Run this on your LOCAL machine, not the installation machine
> scp YOURUSER@INSTALL_MACHINE_IP:~/.ssh/id_ed25519.pub install_key.pub
> cat install_key.pub
> ```
>
> Replace `YOURUSER` with your username on the installation machine and `INSTALL_MACHINE_IP` with its IP address or hostname (from `ip addr` or `hostname -I`).
> If you get "Host Key Verification Failed" when trying to `scp` this is a security error: your SSH client has a stored host key (usually ~/.ssh/known_hosts) for that IP, and it no longer matches the new machine. To prevent a potential "Man-in-the-Middle" attack, SSH blocks the connection until you clear the old record
> Remove the old entry: `ssh-keygen -R <IP_ADDRESS>`

Verify the key works before continuing:

```bash
ssh -T git@github.com
```

Expected output: `Hi yourusername! You've successfully authenticated, but GitHub does not provide shell access.`

If authentication fails, confirm the key is saved at [github.com/settings/keys](https://github.com/settings/keys) and retry.

---

**Step 3 — Run the bootstrap** (~20–40 minutes, unattended)

Download the bootstrap script:

```bash
wget -O bootstrap.sh https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh
chmod +x bootstrap.sh
```

Verify your personal values were pushed correctly — these must not contain placeholder text:

```bash
grep -E "GITHUB_USER|DOTFILES_REPO" bootstrap.sh
```

Expected output:
```
GITHUB_USER="yourusername"
DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"
```

If you still see `yourusername` literally: the script was not pushed with your edits from Step 0. Fix and push, then re-download.

Run the bootstrap:

```bash
./bootstrap.sh
```

The bootstrap runs fully automatically with no prompts. It installs:

- **Nix + Home Manager** — global packages, shell config, git identity, tmux plugins, JetBrainsMono Nerd Font (all declared in `home.nix`, pinned by `flake.lock`)
- **Docker Engine** — rootless daemon, user added to `docker` group
- **GitHub CLI** (`gh`) — installed by Home Manager; apt fallback on first run
- **Gemini CLI** + Conductor + Context7 MCP — installed via npm into `~/.local`
- **tmux** — plugins managed by Home Manager (`programs.tmux.plugins`); no TPM required
- **Neovim + LazyVim** — staged from the LazyVim starter and synced headlessly
- **sessionizer** — symlinked from `~/dotfiles/scripts/sessionizer` into `~/.local/bin`

Git identity (`user.name`, `user.email`) is declared in `home.nix` and applied by Home Manager — the bootstrap does not prompt for it.

> [!important] **GUI tools (WezTerm, VS Code, Chrome, ksnip) are NOT installed by the bootstrap.** They require a display and are handled by `setup-desktop.sh` in Step 5.

> [!tip] The bootstrap takes 20–40 minutes. Part 1 explains the mental model for everything it sets up — the reading fits neatly in that window.

---

**Step 4 — Complete post-bootstrap steps** (~5 minutes)

Log out and back in to activate Docker group membership, then authenticate the CLI tools:

```bash
gh auth login        # prints a one-time code + URL — open the URL on any device
gemini auth login    # prints a one-time code + URL — open the URL on any device
```

> [!note] **No browser needed on this machine.** Both CLIs use a device flow: they print a short code and a URL (e.g. `github.com/login/device`). Open that URL on any phone, laptop, or other machine, enter the code, and authentication completes on the headless machine. **Tip: SSH from another machine with a GUI so you can copy and paste**

Back up your SSH private key to a secure location — it cannot be recovered from the dotfiles repository:

```bash
# Copy this file somewhere safe (password manager, encrypted drive, etc.)
~/.ssh/id_ed25519
```

> [!tip] **Headless path ends here.** If you are setting up a server or a VM you access only via SSH, jump to Step 7 to verify the installation. Steps 5 and 6 are for graphical desktop setups only.

---

**Step 5 — Install the graphical desktop** (optional, ~10 minutes)

> [!important] **Complete Steps 1–4 before running this.** The bootstrap must succeed first.

```bash
wget -O setup-desktop.sh https://raw.githubusercontent.com/yourusername/workstation-scripts/main/setup-desktop.sh
chmod +x setup-desktop.sh
./setup-desktop.sh
```

This script installs:

| Component | What it is |
|---|---|
| XFCE4 + LightDM | Desktop environment and login screen |
| XRDP | Remote desktop server (RDP from Windows) |
| Google Chrome | Browser (required for `gh auth login` OAuth flow) |
| Noto fonts | Glyph fallback for WezTerm (covers U+23F5 and Miscellaneous Technical Unicode) |
| WezTerm | Terminal emulator (installed via Flatpak for GPU driver access) |
| VS Code | Code editor via apt — NOT snap (snap blocks `/nix/store` access) |
| ksnip | Screenshot annotation tool |
| XFCE defaults | Sets WezTerm as preferred terminal; Ctrl+Alt+T opens WezTerm |

> [!note] **JetBrainsMono Nerd Font** is installed by Home Manager (Step 3), not by this script. It is declared in `home.nix` (`nerd-fonts.jetbrains-mono`) and pinned via `flake.lock`.

After the script finishes:

```bash
sudo reboot
```

---

**Step 6 — Connect via RDP and configure the desktop** (desktop path only)

After rebooting:

1. Open **Remote Desktop Connection** (`mstsc`) on Windows
2. Enter the VM's IP address (from `ip addr show`)
3. Select **Xorg** as the session type when prompted by XRDP
4. Log in with your Ubuntu username and password

> [!warning] **One session at a time.** Do not keep a local XFCE session open at the VM console while an XRDP session is also active. Both sessions fight over the same display resources.

**Verify WezTerm opens:**  Press `Ctrl+Alt+T` — WezTerm should open and launch tmux automatically (tmux `new-session -A -s main` is set in `wezterm.lua`).

**Install VS Code extensions:**  Open WezTerm and run:

```bash
grep -v '^#\|^$' ~/dotfiles/vscode/extensions.txt | xargs -I{} code --install-extension {}
```

This installs every extension listed in your dotfiles. See §11.3 for the full list and what each extension does.

**Multi-monitor setup** — see §L.2 for span mode and dual-monitor options.

**Window tiling shortcuts** — see §L.3 for the xfwm4 keyboard shortcut setup (`Super+Arrow` for halves, `Super+Ctrl+Arrow` for quarters).

---

**Step 7 — Verify the installation** (~5 minutes)

Run through the checklist in §2.6 to confirm every component is working correctly.

---

### What Each Part of This Guide Covers

```
Appendix M  →  create your two GitHub repositories (do this first)
Appendix J  →  get a machine ready if you need one (optional)
Part 1      →  understand the stack before or while installing it
Part 2      →  install everything (the bootstrap + verification)
Parts 3–11  →  configure each tool to your preferences
Appendix L  →  desktop connection details and tiling shortcuts (reference)
```

**The scripts at a glance:**

| Script | Repo | What it does | When |
|---|---|---|---|
| `setup-base.sh` | `workstation-scripts` (public) | Installs apt prerequisites | Before bootstrap, on any new machine |
| `bootstrap.sh` | `workstation-scripts` (public) | Full headless dev environment (Nix, HM, Docker, gh, Gemini, tmux, Neovim) | Once per machine |
| `setup-desktop.sh` | `workstation-scripts` (public) | Display layer + GUI apps (XFCE4, XRDP, WezTerm, VS Code, Chrome, ksnip) | After bootstrap, desktop path only |

> [!note] Sections that provide a script you can run instead of following manual steps are marked with a **📋 Script available** callout at the top. You can always follow the manual steps to understand what the script does, or run the script directly and refer back to the manual steps if something goes wrong.

---

### How to Read This Guide

Different readers need different things. Use this table to calibrate how much of Part 1 to read before starting the bootstrap.

| If you… | Do this |
|---|---|
| Are new to Nix and declarative environments | Read all of Part 1 before or during the bootstrap. The 20–40 minute bootstrap window fits it neatly. |
| Use NixOS or Home Manager already | Skim §1.5 (dotfile boundary) and §1.9 (evolution reference table). The rest of Part 1 is review. |
| Are re-installing a second machine from an existing dotfiles repo | Go straight to the Installation steps. Return to Parts 3–11 only if you want to tune the configuration. |
| Are an experienced Linux dev, new to Nix | Read §1.1–1.5 for the mental model, skim §1.6–1.10, then start the bootstrap. |

> [!tip] **When to read each section during the bootstrap**
> Steps 1–2 take under 5 minutes — use that time to read §1.1–1.3. Bootstrap Step 5 (Home Manager apply) takes most of the 20–40 minutes; that window is the right time to read §1.4–1.9 in depth.

---

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
|Wrong tool version (e.g., `python --version` shows 3.9, expected 3.11)|Devenv|Edit `devenv.nix` packages — §1.7, §3.4|
|Global alias or command missing (e.g., `lazygit` not found)|Home Manager|Edit `home.nix` packages — §1.4|
|Database not starting or connection refused|Docker Compose|Check `docker-compose.yml` and `docker compose ps` — §1.8, §3.6|
|Environment not activating when you `cd` into a project|Direnv|Run `direnv allow`; check hook order — §1.6, §3.4|
|Shell prompt looks wrong or missing icons|Home Manager (starship config) or Nerd Font|Edit `home.nix` programs.starship — §1.4; verify font — §3.2|
|Neovim LSP not attaching|Devenv (binary missing from `$PATH`) or Home Manager (Neovim itself)|Check `which pyright-langserver`; verify `mason = false` — §3.11|

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

```
You edit home.nix
         ↓
hms
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
- **Direnv**: the hook that runs `eval "$(direnv hook zsh)"` — placed manually at position 3 in `initContent` rather than via `enableZshIntegration`, so it loads early enough for tmux pane shells (see §3.4)
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
|Add a tmux plugin|`home.nix` `programs.tmux.plugins` list|`hms`|
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
> The editor was launched from a context where the direnv hook did not run, or it was opened before `cd`-ing into the project directory. Direnv only activates when a shell with the `eval "$(direnv hook zsh)"` hook changes directory. Editors need their own integration: Neovim uses the `mkhl/direnv.nvim` plugin; VS Code uses the `mkhl.direnv` extension. Both are configured in this stack. If an LSP cannot find a project tool (pyright, ruff, typescript-language-server), the most likely cause is that the editor's shell did not inherit the Devenv `$PATH`. §8.5 covers the full `$PATH` propagation chain.

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
  # See §3.4 for the full v15/v16 split and the BENCH_USE_UV explanation.
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
- Git hooks (if using devenv git-hooks — covered in §3.8)
- `just` (the project's task runner — pinned per project so `justfile` commands use a consistent version; a global fallback copy in `home.nix` is acceptable for use outside any devenv project)

#### What Does Not Belong in `devenv.nix`

- Personal shell aliases (those go in `home.nix`)
- Global tools you use across all projects (those go in `home.nix`)
- Stateful services like MariaDB or Redis (those go in `docker-compose.yml` — §1.8)
- `debugpy` — this is a critical exception covered in detail in §3.13

> [!warning] The `debugpy` exception `debugpy` cannot go in `devenv.nix packages`. It requires special installation into the project's Python virtualenv. Full explanation and setup in §3.13.

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
- **Debuggers cannot attach cleanly.** DAP debuggers (§3.13) attach to a running Python process. Attaching through a container boundary requires extra configuration that almost never works perfectly.
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
|Change Python version for a project (v16)|`uv python install <version>` — no `languages.python` block exists|See §3.4|
|Change shell prompt appearance|`home.nix` `programs.starship`|`hms`|
|Change terminal font, colors, or padding|`~/dotfiles/wezterm/wezterm.lua`|`SUPER+SHIFT+R`|
|Change tmux prefix key or keybindings|`~/dotfiles/tmux/tmux.conf`|`prefix r`|
|Add a tmux plugin|`home.nix` `programs.tmux.plugins` list|`hms`|
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

## Part 2: Installation — From Zero to Working Workstation

> [!note] **What you will have by the end of this part**
> - An SSH key registered on GitHub
> - A dotfiles repository on GitHub containing your complete environment declaration
> - A fully bootstrapped workstation: Nix, Home Manager, tmux, Neovim, Docker, and all global CLI tools installed and verified (GUI tools — WezTerm, VS Code — are added by `setup-desktop.sh` for desktop setups)
> - The four-step workflow internalised through your first real use of it

This part is a single, continuous installation sequence. §2.1–§2.3 prepare the dotfiles repository that the bootstrap needs. §2.4 runs the bootstrap. §2.5–§2.6 complete and verify the installation. §2.7 explains the daily workflow you will use from this point forward.

---

### 2.1 What You Need Before Starting

> [!tip] **📋 Scripts available for this section.** `setup-base.sh` (§K.5) prepares any Ubuntu machine. `bootstrap.sh` (Appendix A) installs the full environment. Both are fetched via `curl` — no manual copy-paste needed. If you have not yet created your repositories, see Appendix M first.

**Hardware and OS:**

- A machine running Ubuntu 22.04 or 24.04 (fresh install strongly preferred)
- Internet access
- `sudo` rights

> [!note] **Haven't created your repositories yet?** See Appendix M first — it walks through creating both the public `workstation-scripts` and private `dotfiles` repositories. If you have already done that, continue here.
>
> **Don't have a machine yet?** See Appendix J for a short routing guide covering all starting points: existing Ubuntu, fresh server, VMware VM, or cloud instance.

**Accounts:**

- A GitHub account
- Your GitHub username and the email address associated with it (you will enter these during the bootstrap)
- An SSH key registered on GitHub (required — see below)

> [!important] **GitHub requires SSH authentication for git operations.** GitHub no longer accepts passwords or unauthenticated HTTPS for `git clone`, `git push`, or `git pull` on private repositories. You must generate an SSH key and register it on GitHub before you can clone your dotfiles repository or push to it. Do this now, before §2.3.
>
> ```bash
> # Install git and openssh-client if not already present
> sudo apt install -y git openssh-client
>
> # Generate an Ed25519 key
> ssh-keygen -t ed25519 -C "you@example.com"
> # Accept the default path (~/.ssh/id_ed25519)
> # Set a passphrase when prompted (recommended)
>
> # Print the public key — copy this entire line
> cat ~/.ssh/id_ed25519.pub
> ```
>
> Go to [github.com/settings/keys](https://github.com/settings/keys), click **New SSH key**, paste the public key, and save. Then verify the key works:
>
> ```bash
> ssh -T git@github.com
> ```
>
> Expected output: `Hi yourusername! You've successfully authenticated, but GitHub does not provide shell access.`
>
> If you see `Permission denied (publickey)`, the key was not registered correctly — repeat the GitHub step.

> [!note] **`git` binary vs. git configuration.** The `git` binary must be present before the bootstrap runs, because the bootstrap's first action is `git clone` of your dotfiles repository. On a fresh Ubuntu install, `git` is typically not pre-installed — Appendix J (§J.2) covers installing it alongside the other base prerequisites. All git *configuration* — your identity (`user.name`, `user.email`), `init.defaultBranch`, delta as pager, and aliases — is handled by the bootstrap script in Part 2 (§3.2). Do not configure git manually before the bootstrap; the bootstrap handles it interactively and idempotently.

**Nothing else should be pre-installed.** The most common source of subtle failures is a previous package manager state that conflicts with Nix. If you are working on a fresh Ubuntu installation, proceed directly to §2.2. If you are working on an existing Ubuntu installation with tools already installed, read the note below first.

> [!warning] Existing Ubuntu installation If you have previously installed Python via `apt`, Node via `nvm`, or any other development tools globally, they may conflict with Nix-managed versions. Before running the bootstrap, audit your environment:
> 
> ```bash
> # Check for conflicting package managers
> which pyenv && echo "pyenv found — may conflict"
> which nvm && echo "nvm found — may conflict"
> which conda && echo "conda found — may conflict"
> 
> # Check for globally installed pip packages
> pip list 2>/dev/null | wc -l
> ```
> 
> The bootstrap will not remove existing tools, but Nix and Home Manager will prepend to `$PATH`, which usually shadows conflicting versions. If you encounter issues during or after the bootstrap, Appendix H has per-tool troubleshooting entries.

---

### 2.2 The Dotfiles Repository: Your Environment's Source of Truth

The dotfiles repository is a Git repository, hosted on GitHub, that contains every configuration file for your workstation. It is the source of truth: the machine is a reflection of the repository, not the other way around. The bootstrap script clones this repository to `~/dotfiles` and builds your entire environment from its contents.

This repository is also what makes a new machine setup a single command: you clone the repository and run the bootstrap. The bootstrap reads the repository and produces your workstation.

> [!important] The repository must exist before the bootstrap runs The bootstrap script's first action is `git clone` of your dotfiles repository. If the repository does not exist or does not have the required file structure, the bootstrap will fail at step one. Complete §2.3 fully before attempting the bootstrap.

#### The Required Directory Structures

Each repository has required files. The bootstrap script references these paths by name — a missing file causes a named, diagnosable failure.

**`workstation-scripts/` (public repo):**

```
workstation-scripts/
  bootstrap.sh                 # Main bootstrap — installs the full dev environment
  setup-base.sh                # Apt prerequisites — run on any new Ubuntu machine first
  setup-desktop.sh             # Optional desktop — XFCE4 + XRDP + WezTerm + VS Code + ksnip (Appendix L)
```

These three files have no personal data. Anyone can read them. Their entire purpose is to be fetchable by a new machine with nothing installed.

**`dotfiles/` (private repo):**

```
dotfiles/
  flake.nix                    # Nix flake entry point — declares inputs and outputs
  home.nix                     # Home Manager config — your user environment
  wezterm/
    wezterm.lua                # WezTerm terminal config (user-managed, not Home Manager)
  tmux/
    tmux.conf                  # tmux config (user-managed, not Home Manager)
  nvim/                        # LazyVim config — staged by bootstrap, then mutable
    init.lua
    lua/
      config/
      plugins/
  vscode/
    extensions.txt             # VS Code recommended extensions — install manually after setup (see §11.3)
  scripts/
    sessionizer                # tmux project session manager script
  xfce4/
    xfce4-keyboard-shortcuts.xml  # XFCE tiling shortcuts backup (§L.3.5, optional)
```

This repository contains your identity and preferences. Keep it private.

**What each file is for:**

`flake.nix` is the entry point for the Nix build. It does two things: it declares _inputs_ (which version of nixpkgs and Home Manager to use), and it declares _outputs_ (your Home Manager configuration, identified by your username). When you run `hms --flake ~/dotfiles#yourusername`, Nix reads this file to know which version of Home Manager to use, which version of nixpkgs to resolve packages from, and which configuration to apply (the one identified by `yourusername`). The `flake.lock` file that accompanies it records the exact Git commit hashes for all declared inputs — this is what makes two machines with the same `flake.lock` produce identical environments. Full reference in Appendix B.

`home.nix` is the declaration of your user environment: every global CLI tool, your shell configuration, your git config, your prompt. Think of it as a complete, machine-readable description of what your workstation should look like. When Home Manager evaluates it, it translates every declaration into concrete actions: downloading packages to `/nix/store`, generating `~/.zshrc` from your shell configuration, creating symlinks from generated files into your home directory. The file is structured as a Nix attribute set — keys like `home.packages`, `programs.zsh`, `programs.git`, and `programs.starship` each configure a different aspect of your environment. This is the file you edit most often. Full reference in Appendix B.

`bootstrap.sh` is the script covered in Part 2. It reads `flake.nix` and `home.nix` to build your environment via Home Manager, then handles the tools that cannot be managed by Nix (Docker via apt, Gemini CLI via npm). GUI tools (WezTerm, VS Code, Chrome, ksnip) are installed separately by `setup-desktop.sh` and are not part of the bootstrap.

`wezterm/wezterm.lua` is your WezTerm configuration. It is symlinked to `~/.config/wezterm/wezterm.lua` by `setup-desktop.sh`. You edit this file directly and reload with `SUPER+SHIFT+R`. Covered in Part 3.

`tmux/tmux.conf` is your tmux configuration. Its content is embedded in the Home Manager-generated `~/.config/tmux/tmux.conf` via `programs.tmux.extraConfig`. You edit this source file and apply changes with `hms`; reload the live config with `prefix r`. Covered in Part 3.

`nvim/` starts as a placeholder directory. The bootstrap stages the LazyVim starter into it during step 13 (§2.4.3). After that, it is a mutable directory containing your Neovim/LazyVim configuration. It is symlinked to `~/.config/nvim/` via the `mkOutOfStoreSymlink` pattern in `home.nix`. Covered in Part 3.

`vscode/extensions.txt` is a plain text file, one extension ID per line (comments with `#` are ignored). You install these manually after the desktop setup — see §11.3.

`scripts/sessionizer` is the project session manager script. It is symlinked to `~/.local/bin/sessionizer` by the bootstrap and bound to `Ctrl-f` in tmux. Covered in Part 3.

`scripts/setup-base.sh` installs the apt prerequisites for any Ubuntu machine before the bootstrap runs. It is fetched via `curl` from the raw GitHub URL (same pattern as `bootstrap.sh`) and is the starting point for any new machine setup. Full script in Appendix K (§K.5).

`scripts/setup-desktop.sh` installs the optional desktop layer: XFCE4, LightDM, XRDP, WezTerm, VS Code, Chrome, ksnip, and the polkit shutdown rule. Run it after the bootstrap if you want a graphical environment accessible via RDP (Installation Step 5).

`xfce4/xfce4-keyboard-shortcuts.xml` is an optional backup of the XFCE4 window tiling keyboard shortcuts configured in §L.3. Not used by the bootstrap — restore manually if needed on a new desktop machine (§L.3.5).

> [!tip] `flake.nix` and `home.nix` reference Complete, working implementations of both files — not snippets — are in Appendix B. Read this section to understand the structure; go to Appendix B to copy the files. The appendix versions are annotated and ready to use with only your username substituted.

---

### 2.3 Creating Your Two Repositories

> [!tip] **📋 Appendix M has the full repository setup walkthrough.** If you followed the Quickstart in "Before You Start" and already created both repositories from Appendix M, skip to §2.4. If you are here for the first time, continue below.

This section creates the two GitHub repositories that the bootstrap requires. The distinction between them — and why it matters — is explained in "Before You Start". The short version: scripts must be in a **public** repository so `curl` can fetch them without credentials; personal configuration must be in a **private** repository so it stays off the public internet.

Work through these steps in order. Each step verifies its own result.

#### Step 1: Create the Two GitHub Repositories

**Repository 1 — `workstation-scripts` (public)**

Go to [github.com/new](https://github.com/new) and create:

- **Repository name:** `workstation-scripts`
- **Visibility:** Public — this repository contains only generic scripts with no personal data; it must be public so `curl` can fetch from it
- **Initialize with README:** Yes
- **Add .gitignore:** None
- **Add a license:** MIT (optional, but conventional for public tooling)

Note the HTTPS URL shown in the GitHub UI — you will use this to verify the raw fetch URL:

```
https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh
```

**Repository 2 — `dotfiles` (private)**

Go to [github.com/new](https://github.com/new) again and create:

- **Repository name:** `dotfiles`
- **Visibility:** Private — this repository will contain your git identity, shell configuration, and tool preferences
- **Initialize with README:** Yes
- **Add .gitignore:** None
- **Add a license:** None

Note your SSH clone URL:

```
git@github.com:yourusername/dotfiles.git
```

> [!note] Use the SSH URL for the dotfiles repo, not HTTPS. GitHub's SSH URL format is `git@github.com:username/repo.git` (colon, not slash, after the hostname). The HTTPS URL requires credential configuration that is not yet in place. Use the SSH URL throughout this guide. The scripts repo is fetched via unauthenticated HTTPS in `curl` — that is intentional and correct for a public repo.

#### Step 2: Clone Both Repositories Locally

Use `git clone` with the SSH URL directly — **not** `gh repo clone`. `gh repo clone` defaults to HTTPS, which requires token authentication on every push. The SSH URL ensures your registered key is used instead.

```bash
cd ~
# Clone the private dotfiles repo — this is where your config lives
git clone git@github.com:yourusername/dotfiles.git

# Clone the public scripts repo — this is where bootstrap.sh and setup scripts live
git clone git@github.com:yourusername/workstation-scripts.git

cd dotfiles
```

> [!tip] If you already cloned with `gh repo clone` and are being prompted for a username, switch the remote to SSH:
> ```bash
> git -C ~/dotfiles remote set-url origin git@github.com:yourusername/dotfiles.git
> git -C ~/workstation-scripts remote set-url origin git@github.com:yourusername/workstation-scripts.git
> ```
> To prevent this happening again: `gh config set git_protocol ssh`

Verify both clones succeeded:

```bash
ls ~
```

Expected output includes both `dotfiles/` and `workstation-scripts/`.

> [!note] You are cloning the scripts repo locally so you can edit the scripts in your editor and push them to GitHub. The scripts run on other machines via `curl` from the public repo — but you author and version-control them from your local clone here.

#### Step 3: Create the Directory Structures

**In `workstation-scripts/`:**

```bash
cd ~/workstation-scripts
# No subdirectories needed — all three scripts live at the root
```

The scripts repo is flat. All three files (`bootstrap.sh`, `setup-base.sh`, `setup-desktop.sh`) live at the repository root so their raw URLs are simple and predictable.

**In `dotfiles/`:**

```bash
cd ~/dotfiles
mkdir -p wezterm tmux nvim/lua/config nvim/lua/plugins vscode scripts xfce4
```

Verify:

```bash
find . -type d | sort
```

Expected output:

```
.
./nvim
./nvim/lua
./nvim/lua/config
./nvim/lua/plugins
./scripts
./tmux
./vscode
./wezterm
./xfce4
```

#### Step 4: Create Placeholder Files

The bootstrap script references specific filenames. Create placeholders now so the repository structure is complete. You will replace the contents with working configurations in subsequent parts.

> [!important] The scripts in `workstation-scripts/` are not placeholders — they must contain working content before you push. They are fetched and executed directly via `curl`. An empty file causes a silent no-op.

**In `workstation-scripts/`:**

```bash
cd ~/workstation-scripts

# All three scripts — NOT placeholders; copy from appendices (see Step 5)
touch bootstrap.sh setup-base.sh setup-desktop.sh
chmod +x bootstrap.sh setup-base.sh setup-desktop.sh
```

**In `dotfiles/`:**

```bash
cd ~/dotfiles

# Nix flake entry point — copy working version from Appendix B
touch flake.nix

# Home Manager config — copy working version from Appendix B
touch home.nix

# WezTerm config — covered in Part 3
touch wezterm/wezterm.lua

# tmux config — covered in Part 3
touch tmux/tmux.conf

# LazyVim entry point — staged by bootstrap in Part 2, placeholder only
touch nvim/init.lua

# VS Code extensions list — populate with extension IDs, install manually (see §11.3)
touch vscode/extensions.txt

# Sessionizer script — covered in Part 3
touch scripts/sessionizer
chmod +x scripts/sessionizer

# .gitignore — keeps secrets and generated files out of the repository
cat > .gitignore << 'EOF'
# Local secrets — never commit
.env
.env.*

# macOS metadata
.DS_Store

# Nix build artefacts that appear in the dotfiles directory
result
result-*
EOF
```

#### Step 5: Populate the Scripts and Nix Files

These files must contain working content before you push. Empty files cause silent failures at runtime.

**In `workstation-scripts/` — three scripts to populate:**

Open each appendix and copy the script content. No personal substitutions are needed in any of these — they are generic.

| File | Source | Substitutions needed |
|---|---|---|
| `bootstrap.sh` | Appendix A | `GITHUB_USER` and `DOTFILES_REPO` variables (see below) |
| `setup-base.sh` | Appendix K (§K.5) | None |
| `setup-desktop.sh` | Appendix L (§L.4) | None |

After copying, edit `bootstrap.sh` to set the two variables at the top:

```bash
GITHUB_USER="yourusername"        # ← your GitHub username
DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"  # ← your PRIVATE dotfiles SSH URL
```

These are the only lines in `bootstrap.sh` that are personal. Everything else is generic and will not need changing.

Verify none are empty:

```bash
cd ~/workstation-scripts
wc -l bootstrap.sh setup-base.sh setup-desktop.sh   # all must be non-zero
```

**In `dotfiles/` — two Nix files to populate:**

**`flake.nix` and `home.nix` — from Appendix B:**

Open Appendix B and copy both files into your repository, substituting your username where indicated.

> [!important] Three substitutions required in `home.nix` before proceeding
> 1. **Linux username** — replace every occurrence of `yourusername` with your actual Linux username (`whoami`). A mismatch causes the bootstrap to fail at the Home Manager step.
> 2. **Git name** — set `programs.git.settings.user.name` to your full name (e.g. `"Jane Smith"`).
> 3. **Git email** — set `programs.git.settings.user.email` to the email address registered on your GitHub account. This is the address that will appear on every commit you make.
>
> `flake.nix` also contains `yourusername` — replace it there too.

Verify `flake.nix` is not empty:

```bash
wc -l flake.nix
```

Expected output: a non-zero line count. If the output is `0 flake.nix`, the file was not populated from Appendix B.

Verify `home.nix` is not empty:

```bash
wc -l home.nix
```

Expected output: a non-zero line count. If the output is `0 home.nix`, the file was not populated from Appendix B.

#### Step 6: Populate the Remaining Config Files

At this point, `wezterm.lua`, `tmux.conf`, and `sessionizer` are empty placeholders. The bootstrap script symlinks these files into place — the symlinks will exist, but they will point to empty files until you fill them in.

This is intentional: you can run the bootstrap with empty placeholder configs and then populate each file as you work through Parts 4, 5, and 6. WezTerm will open with its defaults, tmux will load with its defaults, and the sessionizer will not work until its script is populated.

If you want a fully working environment immediately after the bootstrap, populate these files now from the reference configs in the relevant appendices:

- `wezterm/wezterm.lua` → Appendix F
- `tmux/tmux.conf` → Appendix E
- `scripts/sessionizer` → Part 3 §3.5

#### Step 7: Commit and Push Both Repositories

**Commit and push `workstation-scripts/`:**

```bash
cd ~/workstation-scripts
git add .
git commit -m "chore: initial setup scripts"
git push
```

Verify the scripts are visible on GitHub by opening:

`https://github.com/yourusername/workstation-scripts`

Confirm you can see `bootstrap.sh`, `setup-base.sh`, and `setup-desktop.sh` at the root.

**Test that the raw URL works** — this is the URL a new machine will use:

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh | head -5
```

Expected: the first 5 lines of the script. If you get a 404, the repo is not public or the file is not at the root.

**Commit and push `dotfiles/`:**

```bash
cd ~/dotfiles
git add .
git commit -m "chore: initial dotfiles structure"
git push
```

Verify the push succeeded:

```bash
git log --oneline
```

Expected output:

```
a1b2c3d chore: initial dotfiles structure
b4e5f6a Initial commit
```

> [!note] Your dotfiles repo is private — it will not be visible in a browser without logging into your GitHub account. That is correct and expected.

> [!important] Both repositories must be pushed before running anything on a new machine. `bootstrap.sh`, `setup-base.sh`, and `setup-desktop.sh` are fetched from `raw.githubusercontent.com` and executed directly — a locally committed but unpushed change is invisible to `curl`. The dotfiles repo must be pushed so the bootstrap can clone it via SSH. Always `git push` in both repos before bootstrapping a new machine.

---

### 2.4 The Bootstrap — One Command to a Working Workstation

With the dotfiles repository live on GitHub (§2.3), setting up a workstation is a single command. This section explains what the bootstrap script does, why each step is ordered the way it is, what correct completion looks like, and what to do when something goes wrong.

---

#### 2.4.1 What the Bootstrap Script Does

The bootstrap script (`bootstrap.sh`, full implementation in Appendix A) turns a fresh Ubuntu Desktop installation into your complete development workstation. It is designed around two properties that make it safe to run in any situation:

**Idempotent.** Every step checks whether the tool is already installed before doing anything. Running the script a second time — because it failed partway through, because you want to verify a fresh machine, or because you updated it — produces the same result as the first run without breaking what is already working.

**Fail-fast.** The script opens with `set -euo pipefail`. This means:

- `set -e`: stop immediately if any command returns a non-zero exit code
- `set -u`: stop if any variable is referenced before being set
- `set -o pipefail`: stop if any command in a pipeline fails, not just the last one

Without these flags, a failed step would silently continue, leaving the environment in a partially-installed state that produces confusing failures much later. With them, the script stops at the exact step that failed and names it.

**What it installs and configures, in order:**

| | Step | What |
|---|---|---|
| Pre-flight | — | Creates user-owned XDG directories (`~/.config/*`, `~/.local/bin`, `~/.ssh`) before any `sudo` call |
| Step 1 | System dependencies | Installs `git`, `curl`, `openssh-client`, `zsh`, and related apt packages; sets zsh as the login shell |
| Step 2 | Verify SSH key | Confirms `~/.ssh/id_ed25519` exists and is authenticated with GitHub — exits with error if missing |
| Step 3 | Clone dotfiles | Clones your private dotfiles repository to `~/dotfiles` |
| Step 4 | Install Nix | Installs Nix via the Determinate Systems installer |
| Step 5 | Apply Home Manager | Builds your full user environment — installs all global CLI tools, tmux plugins, JetBrainsMono Nerd Font, and owns git identity, delta pager, and aliases |
| Step 6 | Install Docker Engine | Adds the official apt repository, installs Docker Engine, adds user to `docker` group |
| Step 7 | Verify GitHub CLI + configure pager | Confirms `gh` is available (Home Manager installs it; apt is the fallback); sets `gh` pager to delta |
| Step 8 | Install Gemini CLI | Installs `@google/gemini-cli` via npm, plus Conductor extension and Context7 MCP |
| Step 9 | Symlink dotfiles | Creates symlink for sessionizer — **must precede LazyVim** |
| Step 10 | Stage LazyVim | Copies LazyVim starter into `~/dotfiles/nvim/` |
| Step 11 | LazyVim headless sync | Installs all LazyVim plugins without opening Neovim |

> [!note] **GUI tools (WezTerm, VS Code, Chrome, ksnip) are installed by `setup-desktop.sh`**, not by the bootstrap. The bootstrap is headless-safe and runs identically on a server or desktop VM.

**Total duration:** 20–40 minutes on first run, depending on internet speed. The majority of the time is Nix downloading packages during step 5.

> [!important] Run the bootstrap only after completing §2.3 The script clones your dotfiles repository at step 3. If the repository does not exist on GitHub, or if `flake.nix` and `home.nix` are empty placeholders, the bootstrap will fail at steps 3 or 5 respectively. Complete Part 2 — including pushing to GitHub — before proceeding.

---

#### 2.4.2 Running the Bootstrap

> [!tip] **📋 Script available.** The bootstrap is `bootstrap.sh` in your public `workstation-scripts` repository. If you pre-generated and registered your SSH key before running (Quickstart Step 3), the bootstrap runs fully automatically with no pauses. Re-running is safe — it is idempotent.

> [!tip] First time running this? Read §3.3 before executing the command below. §3.3 walks through every step the script performs, explains what correct output looks like, and covers all known failure modes. Knowing what to expect makes it much easier to diagnose a failure if one occurs — and you will know exactly which step to look up rather than searching through shell output.

On your fresh Ubuntu installation, open a terminal and run:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh)
```

Replace `yourusername` with your GitHub username. The bootstrap script is fetched from your **public** `workstation-scripts` repository over unauthenticated HTTPS — no SSH key, no credentials needed at this stage.

> [!note] **Why `workstation-scripts` and not `dotfiles`?** The `workstation-scripts` repo is public so `wget` can fetch it without credentials. Your `dotfiles` repo is private. The bootstrap verifies your SSH key is present and authenticated (step 2), then clones your private dotfiles via SSH (step 3). If the key is missing when the bootstrap runs, it exits immediately with instructions — no generation, no pause. You do not need to make your personal configuration public.

**What you will see:** The script prints a coloured step announcement before each phase. Each step either completes silently (already installed) or prints what it is doing. A typical first-run looks like:

```
🚀 Starting workstation bootstrap...
▶ Pre-creating user-owned directories
▶ Installing system dependencies (git, curl, openssh-client, flatpak, zsh)
▶ Setting zsh as login shell
▶ Verifying SSH key for GitHub
▶ Cloning private dotfiles repository
▶ Installing Nix
  [several minutes of Nix output]
▶ Applying Home Manager configuration
  [several minutes of package downloads]
▶ Installing WezTerm
▶ Installing JetBrainsMono Nerd Font
▶ Installing Docker Engine
▶ Verifying GitHub CLI
▶ Configuring gh pager
▶ Installing Gemini CLI and extensions
▶ Symlinking user-managed dotfiles
▶ Staging LazyVim starter
▶ Running LazyVim headless plugin sync
✔ Bootstrap complete!
```

**If the script stops with an error:** The error message names the step. Find the matching step number in §3.3, read the failure output description, and follow the resolution. Every expected failure mode is covered there.

---

#### 2.4.3 What the Script Does, Step by Step

This section walks through every step of the bootstrap in the order the script executes them. For each step: what is being installed, why it is needed, what the idempotency check looks like, and what correct completion output looks like.

The full script is in Appendix A. This section describes each step in prose so you understand what is happening and can diagnose failures without reading shell code.

> [!important] **The SSH key must exist before running the bootstrap.** The bootstrap verifies that `~/.ssh/id_ed25519` is present and that `ssh -T git@github.com` succeeds. If the key is missing, the script exits immediately (code 1) and prints the `ssh-keygen` command and registration instructions — there is no generation, no pause, and no interactive prompt. Fix the precondition (Quickstart Step 2), then re-run.

---

#### Step 1: Install System Dependencies

**Pre-flight (before Step 1):** Before any `sudo` call, the script creates user-owned XDG directories: `~/.config/git`, `~/.config/tmux`, `~/.local/bin`, and `~/.ssh`. This prevents `apt` or `gpg` from implicitly creating `~/.config` owned by root, which would cause "Permission denied" errors in later user-space writes.

**What:** Installs `git`, `curl`, `openssh-client`, and `zsh` via `apt`. Then sets zsh as your login shell via `usermod`.

**Why first:** Every subsequent step either clones a git repository or fetches a script over HTTPS. Without `git` and `curl`, nothing else can run. `openssh-client` is needed for the GitHub SSH verification. `zsh` must be installed before it can be set as the default shell.

**The zsh login shell change:** `usermod -s /usr/bin/zsh $USER` updates `/etc/passwd` but takes effect only at the next login — not in the current session. The bootstrap runs in whatever shell invoked it. Zsh becomes your default shell after the post-bootstrap re-login (§2.5).

**Idempotency:** `apt install` is idempotent. The `usermod` call is guarded by a check that skips it if the shell is already set to zsh.

**Correct completion:** No error output. The step completes in a few seconds.

---

#### Step 2: Verify SSH Key

**What:** Confirms that `~/.ssh/id_ed25519` exists and that SSH authentication to GitHub succeeds. Also pre-seeds `~/.ssh/known_hosts` with the GitHub host key so that subsequent `git` calls over SSH never prompt interactively.

**Why a hard stop, not a prompt:** The bootstrap is designed to run fully unattended. A pause mid-script would break piped or remote invocations. The precondition check is enforced up front (before any state is changed) so that if it fails, nothing has been installed and re-running after fixing the key is safe.

**What happens if the key is missing:**

```
✗ SSH key not found at ~/.ssh/id_ed25519

Generate and register an SSH key before running bootstrap:
  ssh-keygen -t ed25519 -C "youruser@workstation" -f ~/.ssh/id_ed25519 -N ""
  cat ~/.ssh/id_ed25519.pub
Paste the key at https://github.com/settings/keys, then verify:
  ssh-keyscan github.com >> ~/.ssh/known_hosts
  ssh -T git@github.com
```

The script then exits with code 1. Fix the precondition (Quickstart Step 2) and re-run.

**Idempotency:** Pre-seeding `known_hosts` is idempotent (same entry can appear multiple times safely). The SSH check itself is a read-only operation.

**Correct completion:** `✓ SSH key verified – GitHub authentication successful`

---

#### Step 3: Clone the Dotfiles Repository

**What:** Clones `git@github.com:yourusername/dotfiles.git` to `~/dotfiles`. If `~/dotfiles` already exists (re-run scenario), fetches and hard-resets to `origin/main` instead.

**Why here:** All subsequent steps read files from `~/dotfiles`. The Home Manager step reads `flake.nix` and `home.nix`. The symlink step reads `wezterm/wezterm.lua`, `tmux/tmux.conf`, and `scripts/sessionizer`. Nothing can proceed until the repository is local.

**Idempotency:** Checks for the existence of `~/dotfiles` before cloning. On re-run, uses `git fetch origin main && git reset --hard origin/main` rather than `git pull --rebase`. This is because the Home Manager step (step 5) generates `flake.lock` inside `~/dotfiles`, leaving an uncommitted file that would cause `git pull --rebase` to refuse with "cannot rebase: you have unstaged changes." Hard reset discards any locally generated files and always brings the working tree into sync with the remote.

**Correct completion:** `~/dotfiles` exists and contains the expected structure. Verify:

```bash
ls ~/dotfiles
```

Expected output includes: `flake.nix`, `home.nix`, `wezterm/`, `tmux/`, `nvim/`, `vscode/`, `scripts/`

---

#### Step 4: Install Nix

**What:** Downloads and runs the Determinate Systems Nix installer.

**Why Determinate Systems over the official installer:** The Determinate Systems installer handles multi-user setup, configures `/etc/nix/nix.conf` with `experimental-features = nix-command flakes` automatically, sets up the Nix daemon as a systemd service, and provides a clean uninstall path. The official Nix installer requires manual post-install steps to enable flakes and nix-command. This step eliminates those.

**Why flakes must be enabled:** `flake.nix` is a Nix flake. Home Manager is applied via `--flake`. Both require the `nix-command` and `flakes` experimental features. The Determinate Systems installer enables both automatically.

**Idempotency:** Checks for `nix` on `$PATH` before running the installer. If Nix is already installed, this step is skipped entirely.

**Correct completion:** The installer prints a summary ending with confirmation that the Nix daemon is running. The script then sources the Nix profile so that `nix` is available for the remainder of the script session without requiring a new shell.

**What to do if this step fails:**

- _Symptom:_ `curl: (6) Could not resolve host: install.determinate.systems` — network issue; verify internet connectivity and retry
- _Symptom:_ `error: the user 'nobody' does not exist` — rare on some Ubuntu minimal installs; install with `sudo useradd -r nobody` then retry
- _Symptom:_ Installer completes but `nix --version` fails in the next step — the profile sourcing line did not execute; run `. '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'` manually and retry from step 5

---

#### Step 5: Apply Home Manager

**What:** Runs `nix run github:nix-community/home-manager -- switch --flake ~/dotfiles#yourusername`. This is the most time-consuming step and the most consequential: it downloads every package declared in `home.nix` and rebuilds your user environment.

**Why `nix run github:...` instead of a locally installed `home-manager`:** On a fresh machine, Home Manager is not yet installed. `nix run` fetches and runs it directly from the Nix registry without requiring a prior installation step. This is safe and reproducible — the Home Manager version is pinned in your `flake.lock`.

**Why the fully qualified URI:** Using `github:nix-community/home-manager` explicitly rather than the short form `home-manager` bypasses the local Nix registry, which may not be populated yet on a fresh install. The short form fails with a registry lookup error on some systems; the explicit URI always works.

**What happens during this step:** Nix evaluates `flake.nix`, reads `home.nix`, resolves all declared packages, downloads them from `cache.nixos.org` to `/nix/store`, generates your `~/.zshrc` and other Home Manager-managed config files, creates symlinks, and records a new generation. This is the step that installs lazygit, gh, fzf, bat, eza, ripgrep, fd, uv, tmux, Neovim, delta, starship, direnv, xclip/wl-clipboard, tree-sitter, gcc, and just (global fallback — projects also pin their own version in `devenv.nix`).

**Idempotency:** `hms` is idempotent — re-running it with the same `home.nix` produces the same result.

**Correct completion:** Ends with output similar to:

```
Starting home manager activation
Activating checkFilesChanged
Activating checkLinkTargets
Activating writeBoundary
Activating linkGeneration
Activating reloadSystemd
Activating setupFonts
Activating setupProfiles
Activating checkReload
Activating install
```

No red error lines. The step typically takes 5–20 minutes on first run.

**What to do if this step fails:**

- _Symptom:_ `error: attribute 'yourusername' missing` — the username in `home.nix` or `flake.nix` does not match the string after `#` in the switch command; verify both files use your exact Linux username (output of `whoami`)
- _Symptom:_ `error: undefined variable 'pkgs'` or similar Nix syntax error — a typo in `home.nix`; the error message includes the file and line number; fix and retry
- _Symptom:_ `error: package 'xyz' not found` — a package name in `home.nix` does not exist in nixpkgs; check the correct attribute name at [search.nixos.org](https://search.nixos.org/packages)
- _Symptom:_ Step hangs for more than 30 minutes — likely a slow or stalled download; check internet connectivity; the Nix download is resumable, retry the step

---

#### Step 6: Install Docker Engine

**What:** Adds the official Docker apt repository, installs Docker Engine (not Docker Desktop), and adds your user to the `docker` group.

**Why the apt repository method, not the convenience script:** The Docker apt repository installs the latest stable Docker Engine and keeps it up to date via normal `apt upgrade`. It integrates with Ubuntu's package management cleanly. The convenience script (`get.docker.com`) is appropriate for CI environments but is less predictable on a developer workstation.

**Why not Docker Desktop:** Docker Desktop on Linux runs Docker in a VM, adds resource overhead, and requires accepting a commercial licence for business use above a certain company size. Docker Engine runs natively on Linux with no VM layer.

**The `docker` group:** Adding your user to the `docker` group allows running `docker` commands without `sudo`. This change does not take effect until you start a new login session. The script adds you to the group now; you will complete the activation in §2.5.

**Idempotency:** Checks for `docker` on `$PATH` before installing.

**Correct completion:** `docker --version` returns a version string. `docker ps` will return a permissions error until you re-login (§2.5) — this is expected at this point.

---

> [!note] **Git configuration is owned by Home Manager, not the bootstrap.** `user.name`, `user.email`, delta as git pager, and git aliases are all declared in `home.nix` under `programs.git` and applied entirely by step 5 (Home Manager). The bootstrap script does not write any git config and does not prompt for identity. To update your git identity, edit `home.nix` and run `hms`.

---

#### Step 7: Verify GitHub CLI and Configure gh Pager

**What:** Verifies that `gh` is available on `$PATH`. If it is not (edge case where the Home Manager PATH has not propagated), installs `gh` via the official apt repository as a fallback. Then runs `gh config set pager delta` to configure gh's output pager.

**Why verify rather than install:** `gh` is declared in `home.nix` packages and is installed by Home Manager in step 5. On a clean run, it is already available and this step completes in under a second. The apt install is the fallback for the rare case where `gh` is not yet findable via `$PATH` after the Home Manager switch.

**Why configure gh pager separately from git pager:** Git's pager (`core.pager`) and gh's pager are completely independent settings. Home Manager's `programs.git` manages the git pager via `home.nix`. The gh pager is a runtime config value (`~/.config/gh/config.yml`) that Home Manager does not expose as a declarative option — it must be set imperatively. Both settings are required to get delta-highlighted diffs everywhere.

> [!tip] If `gh` was installed by Home Manager in step 5, this step's idempotency check (`command -v gh`) fires immediately and the step takes less than a second.

---

#### Step 8: Install Gemini CLI, Conductor, and Context7 MCP

**What:** Installs `@google/gemini-cli` globally via npm, then installs the Conductor extension (`gemini extension install conductor`) and the Context7 MCP server (`gemini mcp install context7`).

**Why npm global install, not Home Manager or Nix:** Gemini CLI manages its own extensions in a user-space directory. Installing it via Nix places its files in the read-only `/nix/store`, which causes extension installation to fail with a filesystem error when Gemini tries to write extension data alongside the binary. npm global install places everything in a mutable user directory that Gemini can write to.

**Why `--prefix ~/.local`:** Without an explicit prefix, npm's global install would resolve the prefix from the Nix-managed npm binary and attempt to write into a path under `/nix/store`, which is read-only. Setting `--prefix ~/.local` redirects the install to `~/.local/lib/node_modules/` (packages) and `~/.local/bin/` (binaries). Since `~/.local/bin` is already on `$PATH` via `home.nix`, the `gemini` binary becomes available immediately after install.

**Why `|| true` on the extension installs:** The Context7 MCP package availability in the npm registry may vary. Appending `|| true` prevents a transient package resolution failure from halting the entire bootstrap. If the extension install fails, the bootstrap completes and you can install the extension manually afterward.

**Idempotency:** Checks for `gemini` on `$PATH` before installing.

**Authentication note:** `gemini auth login` requires browser interaction and cannot be automated. It is a post-bootstrap manual step (§2.5).

---

#### Step 9: Symlink User-Managed Dotfiles

> [!important] **This step must run before LazyVim (steps 10–11).** The `nvim/` directory must be in place (symlinked by Home Manager in step 5) before the LazyVim headless sync can run.

**What:** Creates one symlink:

```
~/dotfiles/scripts/sessionizer  →  ~/.local/bin/sessionizer
```

**Why `~/.local/bin/` for the sessionizer:** `~/.local/bin/` is the standard per-user executable directory on Ubuntu. Home Manager adds it to `$PATH` via `home.nix`. Once the symlink exists, `sessionizer` is available as a command from anywhere.

**tmux and WezTerm configs:** `~/.config/tmux/tmux.conf` is generated by Home Manager (`programs.tmux.extraConfig` reads `~/dotfiles/tmux/tmux.conf` and appends plugin run lines) — no manual symlink is needed. `~/.config/wezterm/wezterm.lua` is symlinked by `setup-desktop.sh`, not the bootstrap.

**Idempotency:** Uses `ln -sf` (force), which overwrites an existing symlink with the correct target. Safe to re-run.

---

#### Step 10: Stage LazyVim Starter

**What:** Clones the LazyVim starter repository to `/tmp/lazyvim-starter`, copies its contents into `~/dotfiles/nvim/`, and removes the `.git` directory from the copy.

**Why copy rather than clone into place:** Cloning the starter directly into `~/dotfiles/nvim/` would create a nested git repository, which breaks git operations in the outer `~/dotfiles` repository. Copying the files and removing `.git` gives you the LazyVim starter as plain files that are tracked by your dotfiles repository.

**The `mkOutOfStoreSymlink` connection:** `home.nix` declares `home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/nvim"`. This means Home Manager created `~/.config/nvim` as a symlink pointing to `~/dotfiles/nvim/` during step 5. After step 13 populates that directory, Neovim can find its configuration immediately.

**Idempotency:** Checks whether `~/dotfiles/nvim/init.lua` exists and is non-empty before cloning. If it is already populated (re-run or manual setup), this step is skipped.

---

#### Step 11: Run LazyVim Headless Plugin Sync

**What:** Runs `nvim --headless "+Lazy! sync" +qa` to install all LazyVim plugins without opening an interactive Neovim session.

**Why headless sync during bootstrap:** Without this step, the first time you open Neovim, LazyVim downloads all its plugins interactively while you watch. This takes 1–3 minutes and produces a screen full of progress output before the editor is usable. Running the sync headlessly during bootstrap means the first manual Neovim open is fully ready with all plugins installed and no waiting.

**What correct output looks like:** The command runs silently for 1–3 minutes and returns to the shell prompt. It does not print progress to the terminal (headless mode suppresses UI output). If it returns immediately (under 5 seconds), something went wrong — check that `~/dotfiles/nvim/init.lua` exists and is not empty.

**Idempotency:** Headless sync is safe to re-run; it installs missing plugins and updates any that have changed since the last sync.

---

---

### 2.5 Post-Bootstrap Manual Steps

Three steps cannot be automated and must be completed immediately after the bootstrap. They require browser interaction or a session boundary that a script cannot cross. A fourth step verifies the SSH remote configuration established in §2.1. Complete the mandatory steps in order before doing anything else.

#### Manual Step 1: Re-login for Docker Group

The Docker group membership added in step 8 takes effect at a session boundary — when you start a new login session. Until you re-login, `docker ps` returns:

```
permission denied while trying to connect to the Docker daemon socket
```

**Resolution:** Log out of your Ubuntu desktop session and log back in. Then verify:

```bash
docker ps
```

Expected output (empty list is correct — no containers are running yet):

```
CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES
```

> [!tip] Temporary workaround for the current session If you need Docker to work immediately without re-logging in, run `newgrp docker` in your current terminal. This activates the group membership for that terminal session only. Any new terminal windows still require re-login.

#### Manual Step 2: Authenticate GitHub CLI

```bash
gh auth login
```

This opens an interactive flow that requires browser OAuth. When prompted:

- **Where do you use GitHub?** → `GitHub.com`
- **What is your preferred protocol for Git operations?** → `SSH`
- **Upload your SSH public key to your GitHub account?** → Select `~/.ssh/id_ed25519.pub` (the key registered in §2.1)
- **How would you like to authenticate?** → `Login with a web browser`

Follow the browser prompt. When complete, verify:

```bash
gh auth status
```

Expected output:

```
github.com
  ✓ Logged in to github.com account yourusername (keyring)
  - Active account: true
  - Git operations protocol: ssh
  - Token: gho_****
  - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
```

The `repo` and `workflow` scopes are required. If they are missing, the OAuth flow may have been interrupted — re-run `gh auth login` to complete it.

#### Manual Step 3: Switch Dotfiles Remote to SSH

Your SSH key was registered with GitHub in §2.1, and your dotfiles were cloned via SSH in §2.3. The bootstrap's `git fetch && git reset --hard` in Step 3 also uses the existing SSH remote. No action is needed here unless your dotfiles remote is still set to HTTPS for some reason.

Verify the remote is SSH:

```bash
cd ~/dotfiles
git remote -v
```

Expected output:

```
origin  git@github.com:yourusername/dotfiles.git (fetch)
origin  git@github.com:yourusername/dotfiles.git (push)
```

If the remote shows `https://`, switch it:

```bash
git remote set-url origin git@github.com:yourusername/dotfiles.git
```

Then verify with `git remote -v` again.

#### Manual Step 4: Authenticate Gemini CLI

```bash
gemini auth login
```

This opens a browser OAuth flow for your Google account. Follow the browser prompt. When complete:

```bash
gemini --version
```

If the command returns a version string without an authentication error, the login succeeded.

---

### 2.6 Verifying the Complete Installation

Run these checks in sequence after completing all four manual steps. Each check confirms one layer of the stack is working correctly.

#### Nix

```bash
nix --version
```

Expected output: `nix (Nix) 2.x.x` — any version above 2.18 is correct.

#### Home Manager

```bash
home-manager --version
```

Expected output: a version string of the form `release-YY.MM` (e.g., `release-24.11`) or a commit hash. Any output here confirms Home Manager is installed and on `$PATH`. If this returns `command not found`, the Nix profile is not active in the current shell — open a new terminal and retry.

```bash
echo $SHELL
```

Expected output: `/home/yourusername/.nix-profile/bin/zsh` or `/etc/profiles/per-user/yourusername/bin/zsh`

If this returns `/bin/bash`, Home Manager's shell configuration did not apply. Open a new terminal — the shell change requires a new session.

#### WezTerm

Open WezTerm from your application launcher. Two things to verify visually:

1. **The Nerd Font is rendering.** The tmux status bar should show Powerline separators (angled shapes between sections), not boxes (`□`) or question marks. If you see boxes, the font is installed but WezTerm is not configured to use it yet — this is expected if `wezterm.lua` is still the placeholder from Part 2 §2.3. Part 3 covers the full WezTerm configuration.
    
2. **tmux attaches automatically.** With `default_prog = { "tmux", "new-session", "-A", "-s", "main" }` in `wezterm.lua`, opening WezTerm should land you directly in a tmux session named `main`. If WezTerm opens a plain shell instead, `wezterm.lua` has not been populated yet.

#### Tmux

```bash
tmux -V
```

Expected output: `tmux 3.x` — must be 3.2 or later. If it is below 3.2, the Home Manager-installed tmux is not yet on your `$PATH` — open a new terminal and retry. If the version is still below 3.2 after opening a new shell, verify that `tmux` is declared in `home.nix` packages and run `hms`.

#### Docker

```bash
docker ps
```

Expected output: empty container list (no permission error). If you see a permission error, the Docker group re-login from §2.5 did not complete — log out and back in.

```bash
docker compose version
```

Expected output: `Docker Compose version v2.x.x`. If `docker compose` is not found (only `docker-compose` with a hyphen), the Docker Compose plugin was not installed — re-run step 6 of the bootstrap or install it manually: `sudo apt-get install -y docker-compose-plugin`.

#### GitHub CLI

```bash
gh auth status
```

Expected: authenticated output as shown in §2.5 Manual Step 2. If this shows `not logged in`, run `gh auth login`.

#### Direnv

```bash
direnv --version
```

#### Devenv

```bash
devenv --version
```

If `devenv` is not found, the Nix profile PATH may not be active in this session. Source it:

```bash
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
```

Then retry. If devenv is still not found, verify it is declared in `home.nix` packages and run `hms`.

#### Neovim

```bash
nvim --version
```

Then open Neovim:

```bash
nvim
```

What a healthy first open looks like:

- LazyVim loads immediately with no plugin installation progress (the headless sync in step 13 already handled this)
- No red error messages in the status line
- `:checkhealth` (run with `:checkhealth` inside Neovim) shows no ERROR lines — WARNING lines for optional features are acceptable

> [!warning] If Neovim shows plugin errors on first open The headless sync in step 13 may have failed silently. Run `:Lazy sync` inside Neovim to install missing plugins interactively. This takes 1–3 minutes and only needs to happen once.

#### Global CLI Tools (Spot Check)

```bash
lazygit --version
gh --version
fzf --version
bat --version
eza --version
rg --version
fd --version
delta --version
just --version
```

All of these should return version strings. Any that return `command not found` were not installed by Home Manager — check that they are declared in `home.nix` packages and run `hms`.

#### Commit `flake.lock` to Your Dotfiles Repository

The bootstrap generated `~/dotfiles/flake.lock` during step 5 (the Home Manager apply step). This file did not exist when you created the repository in Part 2, so it was not part of the initial commit. It must be committed now.

`flake.lock` records the exact Git commit hashes of all Nix inputs (nixpkgs, Home Manager). Without it committed, a second machine running the bootstrap will resolve inputs against whatever is current at that moment — potentially different package versions from what you have now.

```bash
cd ~/dotfiles
git add flake.lock
git commit -m "chore: add flake.lock generated by initial bootstrap"
git push
```

Verify it is present:

```bash
cat ~/dotfiles/flake.lock | head -5
```

Expected output: a JSON structure beginning with `{ "nodes": {`. If the file is missing entirely, the Home Manager step did not complete successfully — re-run `hms`.

---

### 2.7 Your Daily Workflow — The Configuration Lifecycle

Your workstation is now running. Every future change to it — adding a tool, tuning a config, updating packages — follows the same four-step cycle. Understanding this cycle is the last piece of setup. Everything from Part 3 onward assumes you are working within it.

```
1. Edit
   Modify the relevant file in ~/dotfiles/
   (home.nix, wezterm.lua, tmux.conf, devenv.nix, etc.)

2. Apply
   Run the command that activates the change locally
   (hms, SUPER+SHIFT+R, prefix r, etc.)

3. Verify
   Confirm the change works as expected

4. Commit and push
   cd ~/dotfiles
   git add <changed files>
   git commit -m "description of what changed and why"
   git push
```

Step 4 is not optional. The dotfiles repository is the source of truth for your environment. A change that is applied locally but not committed exists only on this machine. If you set up a second machine, or need to recover from a failure, the uncommitted change is gone.

**What this looks like in practice:**

Adding a new global CLI tool:

```bash
# 1. Edit
nvim ~/dotfiles/home.nix
# Add the tool to home.packages

# 2. Apply
hms

# 3. Verify
which your-new-tool

# 4. Commit
cd ~/dotfiles
git add home.nix
git commit -m "feat: add your-new-tool to global packages"
git push
```

Changing WezTerm font size:

```bash
# 1. Edit
nvim ~/dotfiles/wezterm/wezterm.lua
# Change font_size value

# 2. Apply
# Press SUPER+SHIFT+R in WezTerm (takes effect immediately)

# 3. Verify
# Visual confirmation in the terminal

# 4. Commit
cd ~/dotfiles
git add wezterm/wezterm.lua
git commit -m "chore: increase font size to 14 for external monitor"
git push
```

**The Apply step in detail.**

"Apply" means different things depending on which file you edited, because the two management paths (§1.5) have different mechanisms for activating changes.

For **Home Manager-managed files** (`home.nix`), the apply command is always `hms`. This is a shell alias defined in `home.nix`:

```bash
alias hms='home-manager switch --flake ~/dotfiles#yourusername'
```

With a flake-based setup, `home-manager switch` alone fails — the binary has no memory of where your flake lives. You must pass `--flake ~/dotfiles#username` on every invocation. The alias bakes that in so you never have to. It is bootstrapped by the first `nix run` in the bootstrap script; after that, every subsequent apply is just `hms`.

`hms` does the following:

1. Evaluates `home.nix` as a Nix expression, resolving all declared packages and configuration options
2. Downloads any packages not already in `/nix/store`
3. Generates managed config files (like `~/.zshrc`) from the templates in `home.nix`
4. Creates or updates symlinks from those generated files into your home directory
5. Records a new generation — a timestamped snapshot of the complete resulting state, reachable for rollback

The switch is atomic: either the entire new generation is activated, or it fails and the previous state remains intact. There is no partial application.

After `hms`, shell configuration changes require a new shell to take effect. The running shell has already loaded the previous `~/.zshrc` into memory; the new generated file on disk is not re-read until a new shell starts. Run `exec zsh` or open a new terminal.

For **user-managed files** (WezTerm, tmux, sessionizer), the apply mechanism is built into the tool's own reload workflow, because the file is symlinked directly — no Nix evaluation is involved:

| File | Apply command | Mechanism |
|---|---|---|
| `wezterm/wezterm.lua` | `SUPER+SHIFT+R` in WezTerm | WezTerm re-reads its config file and applies changes immediately |
| `tmux/tmux.conf` | `prefix r` inside tmux | tmux sources the config file and applies changes to all active sessions |
| `scripts/sessionizer` | (none needed) | The script is re-executed on each invocation; changes take effect on the next call |

The speed difference — under one second versus 30–60 seconds — is why WezTerm and tmux are user-managed rather than Home Manager-managed. For tools you tune frequently during initial setup, this iteration speed matters.

> [!tip] Write useful commit messages Your dotfiles commit history is the audit log of every change you have made to your workstation. "Update config" is not useful six months later. "feat: add ripgrep to packages" or "fix: increase escape-time for remote SSH sessions" tells you exactly what changed and why.

**Syncing to a second machine:**

Once your dotfiles repository is pushed, setting up any additional machine is:

```bash
# Step 1 — install apt prerequisites (wget is pre-installed on Ubuntu)
bash <(wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/setup-base.sh)

# Step 2 — generate and register the SSH key before the bootstrap runs
ssh-keygen -t ed25519 -C "yourusername@workstation" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
# → paste at github.com/settings/keys, then verify:
ssh -T git@github.com

# Step 3 — run the bootstrap (no pauses if the key is already registered)
bash <(wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh)
```

If the new machine is headless (no browser), copy the public key to your local machine first:

```bash
# Run on your LOCAL machine to retrieve the key
scp YOURUSER@NEW_MACHINE_IP:~/.ssh/id_ed25519.pub ~/Downloads/new_machine_key.pub
cat ~/Downloads/new_machine_key.pub
# → paste at github.com/settings/keys
```

After initial setup, keeping a second machine in sync with changes you have made on your primary machine:

```bash
cd ~/dotfiles
git pull
hms
```

---

> [!note] **What you now have**
> A fully operational workstation — SSH key on GitHub, dotfiles repository tracking your environment, Nix and Home Manager managing your global tools, WezTerm installed, Docker running, Neovim staged with LazyVim, VS Code installed, and the four-step workflow active. Every part from here configures a layer you already have installed.

---

## Part 3: WezTerm — The Terminal Emulator

> [!note] **What you will understand by the end of this part**
> - Why WezTerm is the terminal of choice and what role it actually plays (hint: less than you might think — tmux owns the workspace)
> - How the TERM variable propagates from WezTerm through tmux to Neovim, and why getting this wrong breaks colour rendering
> - The user-managed vs. Home Manager boundary as applied to WezTerm config: why a 1-second reload matters
> - How to configure, reload, and iterate on `wezterm.lua` without restarting the terminal

WezTerm is your entry point into the workspace, but its role in this stack is deliberately narrow: it is a rendering surface. It draws text, handles fonts, manages GPU-accelerated output, and launches tmux. Everything else — sessions, windows, panes, running processes — belongs to tmux. This boundary is what makes WezTerm _disposable_: close it mid-work, reopen it, and tmux reconnects to exactly where you were.

Understanding this role prevents a common mistake: using WezTerm tabs and keybindings for workspace management when that work should happen in tmux. This section explains the boundary clearly before covering the configuration.

---

### 3.1 What WezTerm Does in This Stack

WezTerm's responsibilities in this stack, and nothing more:

- **Renders text** with GPU acceleration and true 24-bit colour
- **Applies the Nerd Font** so tmux and Neovim glyphs render correctly
- **Launches tmux automatically** on open, attaching to an existing session or creating one
- **Reloads configuration instantly** with `SUPER+SHIFT+R` — no restart required
- **Provides WezTerm-level tabs** for transient shells that live outside any project session

WezTerm does _not_ manage your workspace. It does not hold sessions. Closing it kills nothing. When you reopen WezTerm, `default_prog = { "tmux", "new-session", "-A", "-s", "main" }` attaches to the running tmux session and your workspace is exactly as you left it.

---

### 3.2 Why WezTerm Config Is User-Managed (Not Home Manager)

As established in §1.5, WezTerm configuration is user-managed: you edit `~/dotfiles/wezterm/wezterm.lua` directly and reload with `SUPER+SHIFT+R` in under a second.

The specific reason this tradeoff is correct for WezTerm: the settings you tune most often — `font_size`, `window_padding`, `color_scheme` — are hardware-dependent. A font size that looks right on a 27-inch 4K external monitor is too small on a 14-inch laptop screen. Padding that feels comfortable in bright light is too sparse in a dark room. These settings change frequently during the first weeks of use, and occasionally thereafter.

A Home Manager rebuild for a single `font_size` change takes 30–60 seconds of Nix evaluation. `SUPER+SHIFT+R` takes under one second. The iteration speed difference makes user-managed the correct choice here, even though it means this file is not rebuilt by Nix.

The file is still version-controlled in `~/dotfiles/wezterm/wezterm.lua`. The lifecycle is:

```
Edit ~/dotfiles/wezterm/wezterm.lua
       ↓
Press SUPER+SHIFT+R in WezTerm
       ↓
Change takes effect immediately
       ↓
Verify visually
       ↓
cd ~/dotfiles && git add wezterm/wezterm.lua && git commit && git push
```

---

### 3.3 The TERM Propagation Chain — How Colour Gets from WezTerm to Neovim

_Without this mental model, colour problems are impossible to diagnose._

Three programs are involved in rendering a Neovim colour scheme: WezTerm, tmux, and Neovim. Each needs to correctly advertise and pass through colour capabilities to the next. When any link in this chain is misconfigured, Neovim themes render with washed-out 256-colour approximations instead of true 24-bit colour.

```
WezTerm
  Advertises: TERM = "wezterm"  (or "xterm-256color")
  Renders true 24-bit colour natively
        ↓ SSH or direct pty connection
tmux intercepts the connection
  Internally uses: TERM = "tmux-256color"
  Passes Tc capability via: terminal-overrides ",<your-TERM>:Tc"
  (must match the TERM value WezTerm advertises — see §3.4)
        ↓
Neovim (or any inner program)
  Sees the Tc flag → sets termguicolors = true
  Renders true 24-bit colour correctly
```

The two tmux lines required (covered in full in Part 3 §3.4):

```bash
set -g default-terminal "tmux-256color"
# Use whichever matches your wezterm.lua term setting:
set -ga terminal-overrides ",wezterm:Tc"        # if term = "wezterm"
# set -ga terminal-overrides ",xterm-256color:Tc" # if term = "xterm-256color"
```

Both lines are required. The first tells tmux what terminal type to advertise to inner programs. The second tells tmux to pass the `Tc` true-colour capability through to the outer terminal. One without the other is insufficient — Neovim themes will look degraded even if the terminal is capable.

#### The `term` Setting: `"wezterm"` vs. `"xterm-256color"`

This is the one WezTerm setting with a meaningful trade-off. Both options are presented here; the choice is yours.

**Option A: `term = "wezterm"`**

Sets `TERM` to `wezterm` inside WezTerm. This value corresponds to a terminfo entry that ships with WezTerm and describes its full capabilities.

_What you gain:_

- **Undercurl support** — wavy underlines for LSP diagnostics and spelling errors in Neovim render correctly. Without this, undercurls fall back to straight underlines or disappear entirely.
- **Richer true-colour declaration** — some programs read the terminfo entry directly rather than relying on the `Tc` capability flag; `wezterm` describes more capabilities than `xterm-256color`.

_What you give up:_

- SSH sessions to remote hosts that do not have the `wezterm` terminfo entry fail with `unknown terminal type`. This affects any server you have not explicitly configured.

_How to handle the SSH problem if you choose `"wezterm"`:_

WezTerm's `wezterm ssh` command installs the terminfo entry automatically on the remote host. For standard `ssh`:

```bash
# Install wezterm terminfo on the remote host (run once per host)
infocmp wezterm | ssh your-remote-host "tic -x -"
```

Or, override `TERM` per SSH session without changing your WezTerm config:

```bash
# In your shell config (home.nix programs.zsh.initContent):
alias ssh='TERM=xterm-256color ssh'
```

---

**Option B: `term = "xterm-256color"`**

Sets `TERM` to `xterm-256color`, a universally supported value present in the terminfo database of every Linux server.

_What you gain:_

- SSH to any remote host works without any extra steps.

_What you give up:_

- **No undercurl** — LSP diagnostics and spelling errors in Neovim use straight underlines instead of wavy ones.
- Slightly less accurate colour capability description, though in practice 24-bit colour still works correctly with the tmux `Tc` override.

---

> [!tip] If you are unsure, start with `"xterm-256color"` You can switch to `"wezterm"` at any point by changing one line and pressing `SUPER+SHIFT+R`. The SSH problem only surfaces when you actually SSH to a remote host. If you rarely SSH to remote servers, `"wezterm"` costs you nothing. If you SSH frequently to un-configured hosts, `"xterm-256color"` removes friction you would otherwise hit repeatedly.

---

### 3.4 Annotated Base Configuration

The following covers every setting in the base configuration with an explanation of what it does and why it is set this way. This is not the complete file — it is an annotated walkthrough of the decisions. The complete copy-paste file is in Appendix F.

Place the config at `~/dotfiles/wezterm/wezterm.lua`. `setup-desktop.sh` symlinks it to `~/.config/wezterm/wezterm.lua`.

#### The Required Preamble

```lua
local wezterm = require 'wezterm'

return {
  -- all settings go inside this table
}
```

Every WezTerm config follows this structure. `wezterm` is the WezTerm Lua API module. All settings are keys in the returned table.

#### Font

```lua
font = wezterm.font("JetBrainsMono Nerd Font"),
font_size = 13,
```

`wezterm.font()` selects the font by family name exactly as registered in the system font database. JetBrainsMono Nerd Font is installed by Home Manager (`nerd-fonts.jetbrains-mono` in `home.packages`). If you see boxes (`□`) instead of icons, the font name here does not match the installed family name — verify with `fc-list | grep JetBrains`.

`font_size = 13` is a reasonable baseline for a 1080p monitor. On a 4K display at 100% scaling, 13 will appear very small — 15–16 is more comfortable. On a HiDPI laptop at 200% scaling, 13 renders at an effective 26px and may feel large — 11–12 is more comfortable. Change this freely; it reloads instantly.

#### Colour Scheme

```lua
color_scheme = "Catppuccin Mocha",
```

Catppuccin Mocha is set here and must be set to the same theme in `tmux.conf` (via the Catppuccin tmux plugin). This is not a preference — it is a requirement for colour consistency at pane borders. WezTerm renders the background behind everything; tmux renders its status bar and pane borders on top. If their background colours differ, visible seams appear at every pane border. When both use Catppuccin Mocha, the pane borders are invisible against the background.

To use a different colour scheme: change it in both `wezterm.lua` _and_ `tmux.conf` together, or accept visible seams. The Catppuccin tmux plugin (managed by Home Manager via `programs.tmux.plugins`) supports multiple flavours: Mocha, Macchiato, Frappe, Latte. See §3.7 for the colour consistency mechanism in detail.

#### TERM Setting

```lua
term = "wezterm",   -- or "xterm-256color" — see §3.3 for the trade-off
```

Choose one of the two options described in §3.3.

#### Default Program

```lua
default_prog = { "tmux", "new-session", "-A", "-s", "main" },
```

This is what makes WezTerm disposable. Every time WezTerm opens a new window, it runs this command. The `-A` flag means "attach if a session named `main` already exists; create it if not." The practical effect: closing WezTerm does not kill tmux or any running processes. Reopening WezTerm drops you back into your existing session.

The session name `main` is the catch-all entry point. Project-specific sessions are created by the sessionizer (Part 3) and are separate from `main`. `main` is where you land before switching to a project.

#### Tab Bar

```lua
enable_tab_bar = true,
hide_tab_bar_if_only_one_tab = true,
```

WezTerm tabs are for transient shells that exist outside any tmux session — an SSH connection to a remote server, a one-off script you want isolated, a quick file lookup before returning to your project. With `hide_tab_bar_if_only_one_tab = true`, the tab bar disappears when there is only one tab (which is most of the time), removing visual clutter. It reappears automatically when you open a second tab with `SUPER+T`.

Do not use WezTerm tabs as a substitute for tmux sessions. Tmux sessions survive WezTerm closing; WezTerm tabs do not.

#### Window Padding

```lua
window_padding = { left = 6, right = 6, top = 6, bottom = 6 },
```

6px on all sides provides visual breathing room without wasting screen space on a large monitor. On a small laptop screen (13–14 inches), reduce to 2–4px.

---

### 3.5 Recommended Additions

These settings are not in the minimal base config but are recommended for this stack. Each has a specific reason.

```lua
-- Removes the title bar, keeps resize handles.
-- The tmux status bar provides all the information the title bar would show.
-- Cleaner look with no functional loss.
window_decorations = "RESIZE",

-- WezTerm catches output that occurs before tmux attaches (rare, but useful).
-- tmux manages its own separate scrollback buffer.
scrollback_lines = 5000,

-- Audible bell is almost always the wrong choice in a terminal workflow.
audible_bell = "Disabled",

-- Block cursor is easier to track when moving between panes quickly.
default_cursor_style = "BlinkingBlock",

-- Required for Neovim themes to render correctly.
-- Without this, some colour operations produce inverted results.
force_reverse_video_cursor = false,

-- Do not copy to clipboard on mouse selection.
-- Reason: enabling this conflicts with tmux copy mode.
-- When both are active, they write to different clipboard targets
-- and the behaviour becomes unpredictable.
-- Use Shift-click for quick WezTerm-level selections;
-- use tmux copy mode (prefix [) for structured multi-line copies.
copy_on_select = false,
```

---

### 3.6 Keybindings

These are WezTerm-level bindings. They operate _around_ tmux — they work before tmux loads and affect the WezTerm window itself, not the tmux session inside it.

```lua
keys = {
  -- Open a new WezTerm tab with a plain shell (outside tmux).
  -- Useful for: SSH sessions, one-off commands, anything that
  -- should not pollute your project session.
  { key = "t", mods = "SUPER", action = wezterm.action.SpawnTab "CurrentPaneDomain" },

  -- Reload wezterm.lua without restarting WezTerm.
  -- Use this after every config change.
  { key = "r", mods = "SUPER|SHIFT", action = wezterm.action.ReloadConfiguration },

  -- Font size adjustment without restarting.
  { key = "=", mods = "SUPER", action = wezterm.action.IncreaseFontSize },
  { key = "-", mods = "SUPER", action = wezterm.action.DecreaseFontSize },
  { key = "0", mods = "SUPER", action = wezterm.action.ResetFontSize },
},
```

**When to use WezTerm tabs vs. tmux sessions:**

|Use case|Use|
|---|---|
|SSH to a remote server|WezTerm tab (`SUPER+T`)|
|Quick one-off command outside a project|WezTerm tab|
|Project workspace (editor + services + git)|tmux session via sessionizer|
|Long-running process you want to survive terminal close|tmux session|
|Switching between two active projects|tmux sessions (switch with `Ctrl-f`)|

---

### 3.7 Colour Consistency with Tmux

The colour-bleed problem deserves a concrete explanation because it is easy to encounter and the cause is non-obvious.

WezTerm renders the terminal background. tmux renders its status bar and pane borders as text drawn _on top of_ that background. They are separate rendering layers with no direct coordination. If WezTerm's background colour is `#1e1e2e` (Catppuccin Mocha base) and tmux's status bar background is `#1e1e2e` (also Catppuccin Mocha), they match perfectly and the border is invisible. If they differ by a single hex digit, a visible seam runs along every pane border.

The solution used by this stack: both WezTerm and tmux use the Catppuccin Mocha theme from the same source. WezTerm uses the built-in `"Catppuccin Mocha"` colour scheme. tmux uses the Catppuccin plugin (managed by Home Manager via `programs.tmux.plugins`). Both reference the same colour values, so the seams disappear.

**To verify:** Inside a tmux session, the pane borders should be effectively invisible — only distinguishable from the background because the terminal content stops at the border. If you can clearly see a bright line between panes, the themes are mismatched.

**To change the theme:** Update `color_scheme` in `wezterm.lua` and update the Catppuccin flavour in `tmux.conf` simultaneously. Both must change together.

---

### 3.8 How to Change or Add Settings

The complete workflow for any WezTerm configuration change:

```bash
# 1. Edit the config
nvim ~/dotfiles/wezterm/wezterm.lua

# 2. Reload (no restart required)
# Press SUPER+SHIFT+R inside WezTerm

# 3. Verify the change visually

# 4. Commit
cd ~/dotfiles
git add wezterm/wezterm.lua
git commit -m "chore: describe what changed and why"
git push
```

To find available settings not covered here: the WezTerm documentation at `wezfurlong.org/wezterm/config/lua/config/` lists every configuration key with its type, default value, and description.

---

### 3.9 Gotchas

Each gotcha: symptom, cause, resolution.

---

**Boxes instead of icons (`□` or `?` characters in tmux or Neovim)**

_Symptom:_ Powerline separators in the tmux status bar appear as boxes. File icons in Neovim's file explorer appear as boxes or question marks.

_Cause:_ Either the Nerd Font is not installed, or WezTerm is not configured to use it. The two failure modes have different diagnostics.

_Resolution:_

```bash
# Check if the font is installed:
fc-list | grep JetBrains
```

If this returns nothing, the font installation by Home Manager failed. Re-run `hms` to retry, or manually download JetBrainsMono Nerd Font from `nerdfonts.com`, unzip to `~/.local/share/fonts/`, and run `fc-cache -fv`.

If the font is installed but boxes still appear, the `font` setting in `wezterm.lua` does not match the installed family name. Use the exact family name from `fc-list` output.

---

**`term = "wezterm"` breaks SSH sessions**

_Symptom:_ SSH to a remote host prints `unknown terminal type` or produces garbled output.

_Cause:_ The remote host does not have the `wezterm` terminfo entry in its database.

_Resolution (choose one):_

Option 1 — Install the terminfo entry on the remote host (permanent fix):

```bash
infocmp wezterm | ssh your-remote-host "tic -x -"
```

Option 2 — Override TERM for all SSH sessions (no remote changes needed):

```bash
# Add to home.nix programs.zsh.initContent:
alias ssh='TERM=xterm-256color ssh'
```

Option 3 — Switch `wezterm.lua` to `term = "xterm-256color"` (simplest, but loses undercurl).

---

**`default_prog` prevents opening a plain shell**

_Symptom:_ Every WezTerm window immediately attaches to tmux. You cannot get a plain shell without going through tmux.

_Cause:_ This is by design — `default_prog` always launches tmux. It is not a bug.

_Resolution:_ Press `SUPER+T` to open a new WezTerm tab. The tab spawns a plain shell session before tmux loads. Alternatively, inside tmux, open a new window with `prefix c` for a shell inside the session.

---

**`copy_on_select = true` and tmux copy mode produce unpredictable clipboard behaviour**

_Symptom:_ Selecting text with the mouse sometimes copies to clipboard, sometimes does not. Pasting after a tmux copy-mode selection sometimes pastes the wrong content.

_Cause:_ WezTerm's `copy_on_select` and tmux copy mode write to different clipboard mechanisms. When both are active, whichever one ran most recently owns the clipboard, but the interaction is not deterministic.

_Resolution:_ Keep `copy_on_select = false` (the recommended setting from §3.5). Use the two tools for their intended purposes:

- **`Shift`-click drag in WezTerm**: quick single-line selection, copies to OS clipboard via WezTerm
- **`prefix [` in tmux**: enter copy mode for multi-line structured selection, copies via tmux-yank to OS clipboard

---

### Part 3 Summary

WezTerm is a thin rendering surface, not a workspace manager. Its one job is to draw text, apply the Nerd Font, and hand off to tmux. Everything you tune frequently — font size, padding, colour scheme — lives in `~/dotfiles/wezterm/wezterm.lua` and reloads with `SUPER+SHIFT+R` in under a second, bypassing Nix entirely.

The TERM propagation chain (`wezterm` → `screen-256color` inside tmux → Neovim) is the single most common source of colour-rendering bugs. The two settings `term = "wezterm"` and the corresponding tmux lines are load-bearing — do not remove them.

The `copy_on_select` / tmux copy mode interaction is the most common clipboard confusion source. Keep `copy_on_select = false` and use each tool for its intended purpose.

**What carries forward:** Part 4 covers tmux — the persistent layer that WezTerm wraps and the reason WezTerm is disposable.

---

## Part 4: Tmux — The Workspace Manager

> [!note] **What you now know**
> WezTerm is configured and reloads in under a second. You understand how TERM propagates through the stack, why WezTerm is deliberately thin, and how to iterate on `wezterm.lua` without friction. Part 4 covers the centerpiece that WezTerm wraps: tmux.

---

> [!note] **What you will understand by the end of this part**
> - Why tmux is the *centerpiece* of the workspace and WezTerm is disposable around it
> - The session → window → pane hierarchy and how to map it to your actual projects
> - How the two required TERM/colour lines work and what breaks without them
> - How to configure, reload, and evolve `tmux.conf` at 1-second iteration speed

tmux is the centerpiece of the workspace. While WezTerm is disposable — close it and reopen it freely — tmux is persistent. Sessions outlive any terminal window, survive WezTerm restarts, and continue running through the night. The sessionizer (Part 3) builds on this persistence to give you a declarative, one-keypress workspace for every project.

Understanding why tmux occupies this role, before touching the configuration, prevents the most common mistake: trying to replicate what tmux does at the WezTerm level.

---

### 4.1 What Tmux Does and Why It Is the Centerpiece

tmux maintains a server process that runs independently of any terminal emulator. When you open WezTerm, you are not creating a workspace — you are attaching to a tmux server that is already running (or starting one). When you close WezTerm, the tmux server keeps running. Every session, window, pane, and process inside tmux continues exactly as it was.

This property is what makes the rest of the stack possible:

- **WezTerm can be disposable** (§4.1) because tmux holds all workspace state
- **The sessionizer** (Part 3) can recreate a workspace in two seconds because it creates a tmux session, not a WezTerm window
- **Long-running processes** (Docker log tailing, `bench serve`, test runners) survive terminal close because they run inside tmux panes, not inside the terminal emulator

**The three-level hierarchy:**

```
Session  ─── one per project (e.g., "mipapelera", "achemex", "main")
  │
  └── Window ─── one per role within the project
        │          e.g., "editor", "services", "git"
        │
        └── Pane ─── subdivisions of a window
                       e.g., Neovim | Gemini CLI | shell
```

Sessions are projects. You switch between projects by switching between sessions. Windows are roles — the "editor" window has Neovim and Gemini; the "services" window tails Docker logs. Panes are subdivisions of a window for closely related simultaneous work.

---

### 4.2 Why Tmux Config Is User-Managed (Not Home Manager)

For the same reason as WezTerm (§4.2): prefix key choice, status bar layout, and keybindings are personal settings that change frequently during initial setup. `prefix r` reloads `tmux.conf` in under a second. A Home Manager rebuild for the same change takes 30–60 seconds.

The lifecycle is identical to WezTerm:

```
Edit ~/dotfiles/tmux/tmux.conf
       ↓
Press prefix r inside tmux
       ↓
Change takes effect immediately
       ↓
Verify behaviour
       ↓
cd ~/dotfiles && git add tmux/tmux.conf && git commit && git push
```

The bootstrap symlinked `~/dotfiles/tmux/tmux.conf` to `~/.config/tmux/tmux.conf`. Editing either path edits the same file.

---

### 4.3 Installation Verification

tmux is installed by Home Manager (declared in `home.nix` packages). Verify the version:

```bash
tmux -V
```

Expected output: `tmux 3.x` where x is 2 or higher. All features used in this guide require tmux 3.2 or later.

If `tmux -V` returns a version below 3.2, the Home Manager-installed tmux may not be on your `$PATH` yet — open a new shell and retry. If the version is still below 3.2, verify that `tmux` is in your `home.nix` packages list and run `hms`. The system tmux from Ubuntu apt is typically older; the Home Manager version in nixpkgs is always recent.

---

### 4.4 The TERM and True Colour Settings — The Two Required Lines

Before the annotated configuration, these two settings deserve their own section because they are the most commonly misconfigured and the consequences are not obvious.

```bash
set -g default-terminal "tmux-256color"
# Use whichever matches your wezterm.lua term setting (§4.3):
set -ga terminal-overrides ",wezterm:Tc"        # if term = "wezterm"
# set -ga terminal-overrides ",xterm-256color:Tc" # if term = "xterm-256color"
```

**Why both lines are required — not just one:**

The first line sets what terminal type tmux _advertises_ to programs running inside it (Neovim, shell, etc.). Setting it to `tmux-256color` tells inner programs they are running inside a capable terminal.

The second line tells tmux to pass the `Tc` (true-colour) capability _through_ to the outer terminal (WezTerm). Without this second line, tmux blocks the true-colour capability from reaching Neovim even when WezTerm supports it fully.

**Why the override value must match your WezTerm `term` setting:** The override pattern `,<TERM>:Tc` adds the `Tc` flag to the terminfo entry that WezTerm is advertising. If WezTerm advertises `wezterm` but the override targets `xterm-256color`, the flag is never applied and true colour silently breaks. Match them: `wezterm` with `wezterm`, or `xterm-256color` with `xterm-256color`.

The failure mode when only one line is present, or when the TERM values are mismatched: Neovim's colour scheme renders with 256-colour approximations — muddy greens, inaccurate reds, washed-out blues. The symptom looks like a theme problem, but it is a tmux configuration problem. Running `:checkhealth` inside Neovim and looking for a `termguicolors` warning is the fastest diagnostic.

These two lines connect to the TERM propagation chain described in §4.3. The full chain only works when all three links are correct: WezTerm's `term` setting, the first tmux line, and the second tmux line — with the second line's target matching the first link.

---

### 4.5 Full Annotated Configuration

The following covers every setting group in `tmux.conf` with an explanation of what each does and why it is configured this way. Settings that interact with other parts of the stack are flagged explicitly. The complete copy-paste file is in Appendix E.

#### Prefix Key

```bash
set -g prefix C-Space
unbind C-b
bind C-Space send-prefix
```

`C-Space` (Control + Space) is the recommended prefix for this stack. The reasoning against the two common alternatives:

- `C-b` (tmux default): awkward to reach; requires moving the left hand off the home row
- `C-a` (screen tradition): conflicts with readline's "move to beginning of line" and with Neovim's increment-number operator

`C-Space` is reachable with one thumb without moving either hand from the home row. It has no conflicts with readline, Neovim, or any shell binding.

`bind C-Space send-prefix` means pressing `C-Space C-Space` sends a literal `C-Space` through to the inner program — useful in the rare case a program needs that keystroke.

#### Terminal and Colour

```bash
set -g default-terminal "tmux-256color"
# Must match your wezterm.lua term setting — see §4.4:
set -ga terminal-overrides ",wezterm:Tc"        # if term = "wezterm"
# set -ga terminal-overrides ",xterm-256color:Tc" # if term = "xterm-256color"
```

Covered in full in §4.4. The override value must match the `term` setting in `wezterm.lua` — mismatching these silently breaks true colour.

#### Window and Pane Numbering

```bash
set -g base-index 1
set -g pane-base-index 1
set-window-option -g pane-base-index 1
set -g renumber-windows on
```

Windows and panes start numbering at 1, not 0. The reason is ergonomic: the `1` key is on the left side of the keyboard; `0` is on the right. `Alt-1` to jump to the first window is a natural left-hand motion. `Alt-0` would be awkward.

`renumber-windows on` prevents gaps in the window list when a window is closed. Closing window 2 of [1, 2, 3] produces [1, 2], not [1, 3]. Without this, window numbers drift and the `Alt-1`, `Alt-2`, `Alt-3` bindings stop being predictable.

#### Behaviour Settings

```bash
set -g history-limit 50000
set -sg escape-time 0
set -g focus-events on
set -g mouse on
set -g automatic-rename off
set -g allow-rename off
```

`history-limit 50000`: tmux manages its own scrollback buffer separately from WezTerm's. 50,000 lines is generous enough to scroll through long build logs without impacting memory meaningfully.

`escape-time 0`: **Critical for Neovim.** This setting eliminates tmux's default 500ms delay after receiving an escape character. tmux uses this delay to distinguish a bare Escape keypress from the start of an escape sequence (which begins with `\x1b`). The default 500ms means every time you press Escape in Neovim to exit insert mode, there is a half-second pause before the mode changes. At 0ms, Escape is immediate.

> [!warning] `escape-time 0` is non-negotiable Do not set this to anything other than 0. Even 10ms is perceptible during rapid Neovim use. The symptom without this setting: Escape in Neovim feels "sticky" or laggy, and sometimes registers as the wrong character before the mode change. If Neovim ever feels slow to respond to Escape, check this setting first.

`focus-events on`: **Required for Neovim's `autoread`.** Without this, tmux does not forward `FocusGained`/`FocusLost` events to inner programs. Neovim uses these events to trigger `autoread` — automatic reload of files changed by another process. Without focus events, switching from a shell pane (where you edited a file with a different tool) to the Neovim pane does not refresh the buffer. You see stale content until you manually run `:e`. Plugins that react to focus — auto-save, gitsigns refresh, lualine updates — also stop working silently.

`mouse on`: Enables mouse click-to-focus and scroll wheel support. You will still use the keyboard for almost everything, but mouse click to switch pane focus is useful when you have three or more panes open.

`automatic-rename off` and `allow-rename off`: Prevent tmux from overwriting your intentional window names with the currently running command. The sessionizer names windows explicitly ("editor", "services", "git"). Without these settings, as soon as you run a command in a window, tmux renames it to that command name and the layout becomes unreadable.

#### Status Bar

```bash
set -g status-position bottom
set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
set -g status-left "#[fg=#89b4fa,bold] #S  "
set -g status-left-length 30
set -g status-right "#[fg=#6c7086] %H:%M "
set -g window-status-format "#[fg=#6c7086] #I:#W "
set -g window-status-current-format "#[fg=#cba6f7,bold] #I:#W "
```

The Catppuccin Mocha hex values here (`#1e1e2e`, `#cdd6f4`, `#89b4fa`, etc.) must match WezTerm's colour scheme to prevent colour seams at pane borders (§4.7). These values are from the Catppuccin Mocha palette. If you switch to a different colour scheme, update both this block and WezTerm's `color_scheme` setting together.

The status bar shows: session name on the left, window list in the centre, time on the right. This is the minimum useful information. The Catppuccin tmux plugin (§4.7) overrides this with a more polished version while keeping the same colour values.

#### Pane Navigation

```bash
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"

bind -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
bind -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
bind -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
bind -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'
```

This is the tmux side of the vim-tmux-navigator integration (the Neovim side is covered in §4.14). The `is_vim` shell command checks whether the active process in the current pane is Neovim or fzf. If it is, `Ctrl-h/j/k/l` is passed through to that process. If it is not, tmux handles the keystroke as a pane navigation command.

The result: `Ctrl-h` always means "move left" regardless of whether you are in a shell pane or inside Neovim. The same four keys navigate everywhere.

> [!warning] `Ctrl-l` conflict `Ctrl-l` is the standard terminal shortcut to clear the shell screen. With vim-tmux-navigator, it becomes "move right" in shell panes. To clear the terminal screen, use `prefix Ctrl-l` — this passes `Ctrl-l` through tmux to the shell.

#### Window Navigation

```bash
bind -n M-1 select-window -t :1
bind -n M-2 select-window -t :2
bind -n M-3 select-window -t :3
bind -n M-4 select-window -t :4
```

`Alt-1` through `Alt-4` jump to windows by number without requiring the prefix key. In the standard sessionizer layout, `Alt-1` is always the editor window and `Alt-2` is always the services window. This makes window switching a single-chord motion.

#### Pane Splitting

```bash
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %
```

`|` for a vertical split and `-` for a horizontal split are more intuitive than the defaults (`%` and `"`). The `-c "#{pane_current_path}"` flag opens the new pane in the same directory as the current pane — not the session root directory. This is the expected behaviour when you split a pane inside a project subdirectory.

#### Config Reload

```bash
bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"
```

`prefix r` reloads `tmux.conf` and displays a confirmation message in the status bar. Use this after every `tmux.conf` change instead of restarting tmux.

---

### 4.6 Mouse Mode: Who Owns Mouse Events

With `mouse on`, three programs can receive mouse events inside a tmux session. Understanding who owns what prevents unexpected behaviour.

|Action|Owner|Effect|
|---|---|---|
|Click inside a Neovim pane|Neovim|Moves cursor to click position; tmux does not interfere|
|Click on a non-Neovim pane|tmux|Switches pane focus; the shell or program in that pane is unaffected|
|Click and drag a pane border|tmux|Resizes the pane|
|Scroll wheel inside Neovim|Neovim|Scrolls the buffer|
|Scroll wheel outside Neovim|tmux|Enters tmux scroll mode for that pane|
|`Shift`-click anywhere|WezTerm|Bypasses tmux entirely; selects text at the WezTerm level; copies to OS clipboard via WezTerm|

The practical guidance: use mouse clicks for pane focus switching and pane resizing. Use `Shift`-click for quick single-line text copies that you want in the OS clipboard immediately. Use the keyboard for all navigation inside Neovim.

---

### 4.7 Plugin Management

Tmux plugins are managed declaratively by Home Manager (`programs.tmux.plugins` in `home.nix`). They are pinned via `flake.lock` and installed when you run `hms`. No TPM (tmux Plugin Manager) is used. Three plugins are configured. This section explains each plugin's role. The full rationale for each plugin is deferred to where it is exercised in the guide.

#### The Three Installed Plugins

**Catppuccin** (`catppuccin/tmux`) provides a polished status bar that matches WezTerm's colour scheme, eliminating the colour seams described in §4.7. It replaces the manual hex colour settings in §4.5 with a theme-aware implementation. Full colour consistency mechanism: §4.7.

**vim-tmux-navigator** (`christoomey/vim-tmux-navigator`) enables the seamless `Ctrl-h/j/k/l` navigation between tmux panes and Neovim windows described in §4.5. The tmux side is configured in `tmux.conf`; the Neovim side requires a matching plugin declaration. Full Neovim integration: §4.14.

**tmux-yank** (`tmux-plugins/tmux-yank`) copies tmux copy-mode selections to the OS clipboard. Without it, text copied in tmux copy mode (`prefix [`) is only available in tmux's internal buffer — invisible to the browser, other applications, or Neovim's system clipboard register. Full clipboard integration: §4.8.

> [!important] Why tmux-resurrect and tmux-continuum are not installed These plugins save and restore tmux session state across reboots. They are excluded from this stack because they conflict with the declarative recreation model: you recreate workspaces from the sessionizer script (Part 3), not from saved state. Saved state goes stale after crashes, produces conflicts after reboots, and introduces exactly the kind of unpredictable environment the stack is designed to prevent. If a session is broken, the correct response is to kill it and recreate it — a two-second operation — not to restore a saved state that may be partially corrupted.

#### Managing Plugins After Setup

Plugins are declared in `home.nix`:

```nix
programs.tmux = {
  enable = true;
  plugins = with pkgs.tmuxPlugins; [
    catppuccin
    vim-tmux-navigator
    yank
  ];
  extraConfig = builtins.readFile ../tmux/tmux.conf;
};
```

To add a plugin: add it to the `plugins` list in `home.nix` and run `hms`. The plugin is pinned at the nixpkgs version in `flake.lock`.

To remove a plugin: delete it from the `plugins` list and run `hms`.

To update plugins: run `nix flake update` in `~/dotfiles`, then `hms`. This updates all pinned versions in `flake.lock`.

---

### 4.8 Clipboard Integration — The Three-Way Problem

By default, Neovim, tmux, and the OS clipboard are three separate systems that do not communicate. A developer who does not configure this will be confused when `yy` in Neovim cannot be pasted into the browser, and when text copied in tmux copy mode cannot be pasted into Neovim.

The complete solution connects all three.

#### Step 1: Identify Your Display Server

```bash
echo $XDG_SESSION_TYPE
```

Output will be `x11` or `wayland`. This determines which clipboard provider to use.

#### Step 2: Confirm the Clipboard Provider Is Installed

Home Manager installs the correct provider based on your `home.nix` configuration. Verify:

```bash
# For X11:
which xclip

# For Wayland:
which wl-copy
```

If either command returns `not found`, add the missing package to `home.nix` packages (`pkgs.xclip` for X11, `pkgs.wl-clipboard` for Wayland) and run `hms`.

#### Step 3: Tmux Clipboard Setting

Add to `tmux.conf`:

```bash
set -g set-clipboard on
```

This tells tmux to interact with the OS clipboard via OSC 52 (a terminal escape sequence that WezTerm supports natively). With this setting, tmux copy mode selections are accessible to the OS clipboard.

tmux-yank (§4.7) handles the copy-mode → OS clipboard direction more reliably than `set-clipboard` alone. Both settings are recommended together.

#### Step 4: Neovim Clipboard Setting

Add to `~/dotfiles/nvim/lua/config/options.lua`:

```lua
vim.opt.clipboard = "unnamedplus"
```

This makes Neovim's `y` (yank) and `p` (paste) operations use the OS clipboard register (`+`) by default. Without this, Neovim yanks go to Neovim's internal registers, which are invisible to tmux and the browser.

#### End-to-End Verification

After all four steps:

```bash
# Test 1: Neovim → browser
# In Neovim: yy (yank a line)
# In browser: Ctrl+V — should paste the line

# Test 2: tmux copy mode → Neovim
# In tmux: prefix [ to enter copy mode
# Select text with v, copy with y
# In Neovim: p — should paste the text

# Test 3: Browser → Neovim
# In browser: Ctrl+C to copy text
# In Neovim (insert mode): Ctrl+Shift+V or p — should paste
```

If Test 1 fails: confirm `vim.opt.clipboard = "unnamedplus"` is set and that `xclip` or `wl-copy` is installed.

If Test 2 fails: confirm tmux-yank is installed (`ls ~/.tmux/plugins/tmux-yank/`) and that `set -g set-clipboard on` is in `tmux.conf`.

---

### 4.9 Keybinding Reference

The complete daily-use keybinding table. `prefix` means `C-Space` followed by the next key.

|Keys|Action|
|---|---|
|`Ctrl-h` / `Ctrl-j` / `Ctrl-k` / `Ctrl-l`|Move between panes (and Neovim windows)|
|`prefix \|`|New vertical split in current directory|
|`prefix -`|New horizontal split in current directory|
|`prefix [`|Enter copy mode (scroll, search, select, copy)|
|`prefix r`|Reload `tmux.conf`|
|`Alt-1` / `Alt-2` / `Alt-3` / `Alt-4`|Jump to window by number|
|`Ctrl-f`|Open sessionizer project picker|
|`prefix d`|Detach from session (session keeps running)|
|`prefix $`|Rename current session|
|`prefix ,`|Rename current window|
|`prefix c`|New window|
|`prefix &`|Kill current window|
|`prefix x`|Kill current pane|
|`prefix r`|Reload tmux config (after `hms`)|

**Copy mode keys** (after `prefix [`):

|Keys|Action|
|---|---|
|`v`|Begin selection|
|`y`|Copy selection to OS clipboard (via tmux-yank)|
|`Ctrl-v`|Toggle rectangle selection|
|`q` or `Escape`|Exit copy mode|
|`/`|Search forward|
|`?`|Search backward|

---

### 4.10 How to Change or Add Settings

The workflow for any `tmux.conf` change:

```bash
# 1. Edit
nvim ~/dotfiles/tmux/tmux.conf

# 2. Apply (no restart required — active sessions update immediately)
# Press prefix r inside any tmux pane

# 3. Verify — the status bar briefly shows "Config reloaded"

# 4. Commit
cd ~/dotfiles
git add tmux/tmux.conf
git commit -m "chore: describe what changed and why"
git push
```

To add a new keybinding, follow the `bind` syntax used in the existing config. Example — binding `prefix e` to open a new window named "scratch":

```bash
bind e new-window -n "scratch"
```

To add a new plugin, follow the pattern in §4.7.

---

### 4.11 Gotchas

Each gotcha: symptom, cause, resolution.

---

**Escape in Neovim feels laggy or registers incorrectly**

_Symptom:_ Pressing Escape to exit insert mode has a noticeable delay of around half a second. Occasionally the mode change registers with a stray character.

_Cause:_ `escape-time` is not set to 0, or is set to a non-zero value.

_Resolution:_ Verify `set -sg escape-time 0` is in `tmux.conf`. Reload with `prefix r`. If the setting is present but the lag persists, run `tmux show-options -g escape-time` — the output must show `0`, not `500`.

---

**Neovim colour scheme looks washed out or wrong**

_Symptom:_ Neovim themes use muted, approximated colours instead of the expected vibrant ones. Specific colours — reds, greens, certain blues — look wrong.

_Cause:_ True colour is not passing through from WezTerm to Neovim. Either the two required tmux lines are missing, or one of them is incorrect.

_Diagnosis:_

```bash
# Inside Neovim:
:checkhealth
# Look for a warning about termguicolors
```

_Resolution:_ Verify both lines are present exactly as shown in §4.4. Reload with `prefix r`. If the issue persists, check WezTerm's `term` setting (§4.3) — if it is set to a value other than `"wezterm"` or `"xterm-256color"`, the capability chain may be broken.

---

**direnv does not activate in new tmux panes**

_Symptom:_ Opening a new tmux pane or creating a new window in a project directory does not activate the devenv environment. `which python` shows a system path instead of a `/nix/store/...` path.

_Cause:_ The `eval "$(direnv hook zsh)"` line in `home.nix` programs.zsh.initContent is positioned too late in the shell initialisation sequence. tmux fires the initial window command before the shell finishes loading, and if the direnv hook is not loaded yet, it never fires for that pane.

_Resolution:_ In `home.nix`, move `eval "$(direnv hook zsh)"` to position 3 in `programs.zsh.initContent` — after PATH additions and Nix profile sourcing, before zoxide and fzf. The correct shell config load order is covered in §4.4.

---

**`Ctrl-l` no longer clears the terminal**

_Symptom:_ Pressing `Ctrl-l` in a shell pane does nothing or switches to the right pane instead of clearing the screen.

_Cause:_ vim-tmux-navigator binds `Ctrl-l` to "move right." This binding is active in shell panes as well as Neovim panes.

_Resolution:_ Use `prefix Ctrl-l` to send `Ctrl-l` through tmux to the shell. This is a one-time adjustment — after a few days it becomes automatic.

---

**Colour seams visible at pane borders**

_Symptom:_ A thin visible line appears between panes, or the tmux status bar background does not match the terminal background.

_Cause:_ The Catppuccin colour values in `tmux.conf` do not match WezTerm's `color_scheme`. This can happen if you manually edited the hex colours without updating WezTerm, or if you switched WezTerm themes without updating tmux.

_Resolution:_ Ensure `color_scheme = "Catppuccin Mocha"` in `wezterm.lua` and that the Catppuccin tmux plugin is active (declared in `home.nix` `programs.tmux.plugins`). If you are using a custom colour scheme, update both files simultaneously with matching hex values. Full mechanism: §4.7.

---

### Part 4 Summary

tmux is the persistent workspace layer. Sessions outlive terminal windows, survive WezTerm restarts, and keep long-running processes alive. This is what makes WezTerm disposable — closing it never kills anything.

The two TERM/colour lines in `tmux.conf` (`set -g default-terminal` and `set -ga terminal-overrides`) are the bridge between WezTerm's colour capabilities and what Neovim sees. Getting them wrong produces the most common rendering complaints.

The direnv-in-new-panes problem (§4.11) is the most common post-install surprise. If new tmux panes don't activate your project environment, the fix is the `initContent` load order in `home.nix` — direnv hook must be position 3, not position 7.

**What carries forward:** Part 5 adds the sessionizer — the script that turns tmux sessions into declarative, one-keypress workspaces. It builds directly on the session model you now understand.

---

## Part 5: The Sessionizer — Declarative Workspace Management

> [!note] **What you now know**
> tmux is configured, plugins are installed, colour is consistent with WezTerm, and you understand the session → window → pane model. Part 5 builds on this: the sessionizer turns tmux sessions into declarative, one-keypress project workspaces.

---

> [!note] **What you will understand by the end of this part**
> - The declarative principle: why recreating a workspace from a script is better than saving and restoring state
> - How the sessionizer combines fzf + zoxide + tmux into a one-keypress project switcher
> - The three standard layouts (code, ops, notes) and how to extend them for your own projects
> - How to install, test, and customise the sessionizer script

The sessionizer is a shell script that turns project switching into a single keypress. Press `Ctrl-f` from anywhere in tmux, fuzzy-type a partial project name, press Enter, and you are in a fully configured workspace — Neovim open, Gemini CLI running, Docker logs tailing — in under three seconds. If the session already exists, you switch to it instantly.

This part covers the philosophy behind the sessionizer, the three standard layouts it creates, how to install and extend it, and the one known fragility to be aware of.

---

### 5.1 The Declarative Principle: Recreate, Never Save

The sessionizer operates on one principle: **you never save tmux state. You recreate workspaces from a script.**

This is a deliberate rejection of session-persistence plugins like tmux-resurrect. Those plugins save the current tmux state to disk and restore it on reboot. The approach sounds convenient until you encounter its failure modes: saved state goes stale after a crash, produces conflicts after a hard reboot, and accumulates windows and panes from sessions you no longer use. The restored environment is not the environment you intended — it is a snapshot of whatever state happened to exist at the moment of the last save.

The sessionizer avoids all of this by making recreation cheaper than restoration. A session is always created from scratch by a deterministic script. Every session named `mipapelera` is identical: same windows, same pane layout, same startup commands. If a session is broken, you kill it and recreate it. The recreation takes two seconds and produces a known-good state.

> [!important] The practical consequence When something goes wrong in a session — a pane is accidentally closed, a window name is corrupted, the Gemini pane is in the wrong position — the correct response is never to try to repair the session manually. Kill the session with `tmux kill-session -t session-name` and press `Ctrl-f` to let the sessionizer recreate it. Two seconds, clean state.

---

### 5.2 What the Sessionizer Does

The sessionizer is a bash script bound to `Ctrl-f` in `tmux.conf`. When invoked:

```
Ctrl-f pressed (from anywhere in tmux)
        ↓
fzf opens with a list of candidate project directories
(combines zoxide frecency history + find scan of ~/projects)
        ↓
You fuzzy-type a partial name and press Enter
        ↓
Does a tmux session with this name already exist?
  YES → switch-client to the existing session (under 1 second)
  NO  → detect project type from directory contents
      → create a new session with the matching layout
      → open Neovim, start Gemini CLI, tail logs as appropriate
      → switch-client to the new session (2–3 seconds)
```

The session name is derived from the directory's basename: lowercase, spaces and dots replaced with underscores. `~/projects/mi-papelera` becomes `mi-papelera`. `~/projects/achemex.mx` becomes `achemex_mx`.

---

### 5.3 The Three Standard Layouts

The sessionizer detects project type from the contents of the selected directory and applies the matching layout. Every layout creates named windows so `Alt-1`, `Alt-2`, `Alt-3` always jump to the same roles.

#### The `code` Layout

Used for: Python projects, JavaScript/TypeScript projects, ERPNext/Frappe, FastAPI, any general software development.

Detected by: presence of `devenv.nix`, `pyproject.toml`, `package.json`, or `Cargo.toml`.

```
Window 1 "editor":
┌──────────────────────────┬─────────────────────┐
│                          │                     │
│   Neovim (60%)           │   Gemini CLI (40%)  │
│   nvim .                 │                     │
│                          ├─────────────────────┤
│                          │   shell (40% of     │
│                          │   right column)     │
└──────────────────────────┴─────────────────────┘

Window 2 "services":
┌──────────────────────────────────────────────────┐
│   docker compose logs -f                         │
│   (or "[no compose file]" if none exists)        │
└──────────────────────────────────────────────────┘
```

**Window 1 "editor"** is where you spend most of your time. Neovim occupies 60% of the width on the left. The right column splits into Gemini CLI on top (60% of the right column height) and a plain shell below (40%). The shell pane is for quick commands — `just fmt`, `git status`, running a single test — that you want visible alongside the editor without switching windows.

**Window 2 "services"** tails `docker compose logs -f` immediately on creation. If no `docker-compose.yml` exists in the project root, it prints `[no compose file]` and leaves a shell ready. You switch to this window with `Alt-2` when you need to watch service output.

#### The `ops` Layout

Used for: Ansible playbooks, infrastructure repositories, Terraform, anything where you are primarily running commands and inspecting output rather than editing code in a tight loop.

Detected by: presence of `docker-compose.yml` or `docker-compose.yaml` (without the code-layout markers listed above).

```
Window 1 "config":
┌──────────────────────────────────────────────────┐
│   Neovim (full width)                            │
│   nvim .                                         │
└──────────────────────────────────────────────────┘

Window 2 "shells":
┌────────────────┬────────────────┬────────────────┐
│   shell 1      │   shell 2      │   shell 3      │
│                │                │                │
└────────────────┴────────────────┴────────────────┘
```

**Window 1 "config"** opens Neovim full-width. Infrastructure files — YAML, TOML, HCL — benefit from the extra horizontal space for long lines and nested structures.

**Window 2 "shells"** provides three equal-width shell panes. Typical use: one for running the playbook or command, one for watching logs or output, one for auxiliary commands. Switch with `Alt-2`.

#### The `writing` Layout

Used for: documentation projects, Markdown files, notes, any directory without code markers.

Detected by: fallback when no code or ops markers are found. Can also be forced with a `.workspace-writing` marker file (§5.4).

```
Window 1 "main":
┌──────────────────────────┬─────────────────────┐
│                          │                     │
│   Neovim (55%)           │   Gemini CLI (45%)  │
│   markdown files         │                     │
│                          │                     │
└──────────────────────────┴─────────────────────┘
```

A single window with Neovim on the left and Gemini CLI on the right. No services window — writing projects rarely need background service monitoring. The Gemini pane is slightly wider than in the code layout (45% vs 40%) because writing benefits from more AI assistant visibility.

---

### 5.4 Project Type Detection

The sessionizer detects project type by checking for specific files in the selected directory. The checks run in priority order — the first match wins.

|Check|Project type assigned|
|---|---|
|`devenv.nix`, `pyproject.toml`, `package.json`, `Cargo.toml` present|`code`|
|`docker-compose.yml` or `docker-compose.yaml` present|`ops`|
|`.workspace-code` marker file present|`code` (forced)|
|`.workspace-writing` marker file present|`writing` (forced)|
|None of the above|`writing` (fallback)|

**The marker file approach.** For projects that do not match the standard heuristics, create a marker file in the project root:

```bash
# Force the code layout for a project without standard code markers:
touch .workspace-code

# Force the writing layout for a code project you want a quieter layout for:
touch .workspace-writing
```

Marker files take the guesswork out of detection for unusual project structures. They are safe to commit — they have no effect on tools other than the sessionizer.

**Extending detection for new project types.** The sessionizer script uses a simple `if/elif` chain. Adding a new condition follows the same pattern as the existing ones. For example, adding ERPNext/Frappe detection:

```bash
# In the detection block, before the fallback:
elif [ -f "$selected/apps.json" ] || [ -d "$selected/apps/frappe" ]; then
  project_type="code"
```

Full instructions for adding a new layout type are in §5.7.

---

### 5.5 Full Annotated Script Walkthrough

The complete sessionizer script lives at `~/dotfiles/scripts/sessionizer` in your dotfiles repository. The bootstrap symlinked it to `~/.local/bin/sessionizer`, which is on your `$PATH`. This section walks through each functional block so you can understand what to modify and why.

#### Block 1: Directory Discovery

```bash
candidates=$(
  {
    zoxide query --list 2>/dev/null
    find "$HOME/projects" "$HOME/work" \
      -mindepth 1 -maxdepth 2 -type d 2>/dev/null
  } | sort -u
)
```

The candidate list is built from two sources combined and deduplicated:

**zoxide history** (`zoxide query --list`): directories you have visited recently, ranked by frecency. These appear at the top of the fzf list. After a few days of use, your most-visited project directories are always at the top — the fuzzy search is often just `Ctrl-f` + `Enter` for the most recently used project.

**`find` scan**: a depth-limited scan of `~/projects` and `~/work`. `-mindepth 1` excludes the root directories themselves. `-maxdepth 2` includes direct children and one level of subdirectories — enough to find `~/projects/my-project` and `~/projects/org/repo` without scanning deeply into node_modules or virtualenvs.

`sort -u` deduplicates entries that appear in both sources. The `2>/dev/null` on both commands suppresses errors for directories that do not exist — if you have no `~/work` directory, the script continues without error.

**To add more search locations:** append additional `find` paths inside the subshell. For example, to also scan `~/homelab`:

```bash
find "$HOME/projects" "$HOME/work" "$HOME/homelab" \
  -mindepth 1 -maxdepth 2 -type d 2>/dev/null
```

#### Block 2: Fuzzy Selection

```bash
selected=$(echo "$candidates" | fzf \
  --prompt="  project: " \
  --pointer="▶" \
  --preview="ls -la --color=always {}" \
  --preview-window=right:40%:border-left \
  --border=rounded \
  --height=60%)

[ -z "$selected" ] && exit 0
```

fzf presents the candidate list as an interactive filter. `--preview` shows an `ls -la` of the highlighted directory in a right-hand panel — useful for confirming you have the right project before pressing Enter.

The `[ -z "$selected" ] && exit 0` line handles the Escape key: if the user presses Escape or `Ctrl-c` without selecting anything, `$selected` is empty and the script exits cleanly without creating a session.

#### Block 3: Session Naming

```bash
session_name=$(basename "$selected" \
  | tr '[:upper:]' '[:lower:]' \
  | tr ' .' '_')
```

The session name is the directory basename, lowercased, with spaces and dots replaced by underscores. This produces stable, predictable names: `~/projects/Mi-Papelera` becomes `mi-papelera`, `~/projects/achemex.mx` becomes `achemex_mx`.

The name is used for both `tmux has-session` (checking if the session exists) and `tmux new-session -s` (creating it). Consistent naming is what makes the "switch to existing session" path work — pressing `Ctrl-f` and selecting the same project twice always lands you in the same session.

#### Block 4: Attach to Existing Session

```bash
if tmux has-session -t "$session_name" 2>/dev/null; then
  tmux switch-client -t "$session_name"
  exit 0
fi
```

If the session already exists, switch to it immediately and exit. This path takes under one second. No layout creation, no `send-keys`, no window setup. The existing session is untouched.

This is the path taken on every subsequent press of `Ctrl-f` for a project you are already working on — it is the normal steady-state operation.

#### Block 5: Layout Creation

After the `has-session` check, the script creates the new session in the background (`-d` flag, do not attach yet) and applies the detected layout:

```bash
tmux new-session -ds "$session_name" -c "$selected"
```

The `-c "$selected"` flag sets the session's starting directory to the project root. This is what triggers direnv when the first shell in the session starts — direnv detects `.envrc` in the starting directory and activates the devenv environment automatically.

Each layout block then:

1. Renames the default window
2. Creates additional panes with `split-window`
3. Sends startup commands to specific panes with `send-keys`
4. Creates additional windows with `new-window`
5. Sets the final focus with `select-window` and `select-pane`

The `send-keys ... Enter` pattern sends keystrokes to a pane as if typed. `send-keys -t "$session_name:editor.1" "nvim ." Enter` opens Neovim in pane 1 of the "editor" window. The pane index notation `session:window.pane` is tmux's standard addressing format.

#### Block 6: Switch to the New Session

```bash
tmux switch-client -t "$session_name"
```

The final line switches the client to the newly created session. This is what puts you in the workspace. Because the session was created with `-d` (detached), this line is the moment you actually enter it.

---

### 5.6 Installation

The bootstrap handled the installation: it copied the sessionizer script to `~/dotfiles/scripts/sessionizer`, made it executable, and symlinked it to `~/.local/bin/sessionizer`. The tmux binding (`bind -n C-f run-shell "sessionizer"`) is in `tmux.conf`.

Verify the full installation chain before first use:

```bash
# 1. Script is executable and on PATH
which sessionizer
```

Expected output: `/home/yourusername/.local/bin/sessionizer`

```bash
# 2. Script is the symlink to your dotfiles
readlink ~/.local/bin/sessionizer
```

Expected output: `/home/yourusername/dotfiles/scripts/sessionizer`

```bash
# 3. Test the script manually before relying on the tmux binding
sessionizer
```

fzf should open with your project directories. Select one and press Enter. A new tmux session should be created with the correct layout. If this works, the `Ctrl-f` binding will work automatically.

**If `sessionizer` is not found:**

```bash
echo $PATH | tr ':' '\n' | grep local
```

If `~/.local/bin` is not in the output, it is not on your `$PATH`. Add it to `home.nix` `programs.zsh.initContent`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Then run `hms` and open a new shell.

---

### 5.7 How to Add a New Project Type

Adding a new project type requires three changes to the sessionizer script, all in `~/dotfiles/scripts/sessionizer`:

**Step 1: Add a detection condition** to the `if/elif` chain in the detection block. Add it before the final `else` (writing fallback):

```bash
elif [ -f "$selected/your-marker-file" ]; then
  project_type="your-type"
```

**Step 2: Add a layout block** to the `case` statement, following the pattern of the existing layouts:

```bash
your-type)
  tmux rename-window -t "$session_name:1" "your-window-name"
  # Add panes, send startup commands, create additional windows
  # as needed. Follow the pattern from the code or ops blocks.
  ;;
```

**Step 3: Test** by running `sessionizer` from the command line (not via `Ctrl-f`), selecting the new project type, and verifying the layout is created correctly. Debug with `tmux list-panes -t "$session_name"` to inspect the pane structure.

**Step 4: Commit:**

```bash
cd ~/dotfiles
git add scripts/sessionizer
git commit -m "feat: add your-type layout to sessionizer"
git push
```

**Example: Adding an ERPNext/Frappe layout** that opens bench commands alongside Neovim:

```bash
# Detection — add before the final else:
elif [ -f "$selected/apps.json" ] || [ -d "$selected/apps/frappe" ]; then
  project_type="erpnext"

# Layout block — add to the case statement:
erpnext)
  tmux rename-window -t "$session_name:1" "editor"
  tmux split-window -t "$session_name:editor" -h -p 40 -c "$selected"
  tmux send-keys -t "$session_name:editor.2" "gemini" Enter
  tmux split-window -t "$session_name:editor.2" -v -p 40 -c "$selected"

  tmux new-window -t "$session_name" -n "bench" -c "$selected"
  tmux send-keys -t "$session_name:bench" \
    "cd frappe-bench && bench start 2>/dev/null || echo '[no frappe-bench]'" Enter

  tmux select-window -t "$session_name:editor"
  tmux select-pane -t "$session_name:editor.1"
  tmux send-keys -t "$session_name:editor.1" "nvim ." Enter
  ;;
```

---

### 5.8 The Gemini Pane Robustness Problem

The sessionizer's one known fragility is worth understanding so you know how to respond when you encounter it.

In the `code` layout, pane `.2` in the "editor" window runs Gemini CLI. The Neovim keybinding `<leader>g` (Part 3 §5.14) sends selected text to this pane by targeting it with `tmux send-keys -t {right}` or by pane index. This targeting assumes a stable pane structure.

**The failure mode:** If the Gemini pane (`.2`) is accidentally closed — `Ctrl-d` in the Gemini shell, an accidental `prefix x` — tmux renumbers the remaining panes. What was pane `.3` (the shell below Gemini) becomes pane `.2`. The Neovim keybinding now sends text to the wrong pane.

**The correct response:** Do not try to manually repair the pane numbering. Kill the entire session and let the sessionizer recreate it:

```bash
tmux kill-session -t session-name
```

Then press `Ctrl-f`, select the same project, and the sessionizer creates a clean session with the correct pane structure in two seconds. This is faster and more reliable than any manual repair.

**Why this is not fixed by tmux-resurrect:** A session-persistence plugin would save the broken pane numbering alongside the rest of the session state and restore it on the next session attach. The problem persists. The sessionizer approach does not save state, so there is nothing to restore — only a clean recreation.

> [!tip] Prevention The most common cause of the Gemini pane being closed accidentally is typing `exit` in the Gemini CLI instead of pressing `q` or `Ctrl-c`. Gemini CLI exits cleanly on `q` but leaves the pane open. `exit` closes the shell and the pane with it. If you are used to typing `exit` to leave interactive shells, be aware of this difference.

---

### Part 5 Summary

The sessionizer embodies a single principle: recreate, never restore. A workspace is defined by a script that can rebuild it in two seconds from scratch. This means there is no state to corrupt, no persistence plugin to maintain, and no session database to lose.

The three layouts (code, ops, notes) cover the three modes of work. Each layout is a set of tmux `send-keys` calls — readable, editable, and extensible without learning any new API. Adding a new project type means adding a new `elif` branch and committing it.

The one fragility (Gemini pane renumbering) has exactly one correct response: kill the session and let the sessionizer recreate it. Attempting manual repair is always slower.

**What carries forward:** Part 6 covers Nerd Fonts — the prerequisite for all the icons and Powerline separators that the WezTerm, tmux, and Neovim layers use.

---

## Part 6: Nerd Fonts — Making the Terminal Render Correctly

> [!note] **What you now know**
> The sessionizer is installed and bound to `Ctrl-f`. You can switch between any project in two seconds and recreate a broken workspace cleanly. Part 6 covers the font layer that makes icons and Powerline separators render correctly.

---

> [!note] **What you will understand by the end of this part**
> - Why Nerd Fonts exist and what breaks without them (icons, Powerline separators, language glyphs)
> - How font installation works on Ubuntu and how the bootstrap automated it
> - How to verify correct rendering and how to switch fonts if you prefer a different one

Nerd Fonts are a prerequisite for the visual layer of this stack — tmux status bar, Neovim file explorer, git branch indicators — to render correctly. This part explains what they are, why installation is automated, and how to switch to a different font if you prefer one.

---

### 6.1 What Nerd Fonts Are and Why They Are Required

A Nerd Font is a standard programming font that has been patched with thousands of additional glyphs from several icon sets. The additions that matter for this stack:

|Glyph category|Where you see them|
|---|---|
|Powerline symbols|Angled separators between sections in the tmux status bar|
|File-type icons|Folder and language icons in Neovim's file explorer (neo-tree)|
|Box-drawing characters|Pane borders, window chrome throughout tmux and Neovim UI|
|Git branch indicators|Branch name symbols in the tmux status bar and Starship prompt|
|Devicon glyphs|Language-specific icons in Neovim's statusline and bufferline|

Without a Nerd Font installed _and_ selected in WezTerm, every one of these renders as a box (`□`), a question mark, or a missing-character placeholder. The tools still function — LSP, formatting, git operations all work regardless — but the visual layer is broken in a way that is immediately obvious and distracting.

The font must satisfy two conditions simultaneously:

1. **Installed at the OS level** — in `~/.local/share/fonts/` and registered with `fc-cache`
2. **Selected in WezTerm** — `font = wezterm.font("JetBrainsMono Nerd Font")` in `wezterm.lua`

If either condition is missing, glyphs do not render. A common failure mode is having the font installed but using the wrong family name in `wezterm.lua` — the font renders as a fallback and icons appear as boxes.

---

### 6.2 Why the Bootstrap Handles This

Font installation is a fully automatable sequence of file operations: download a zip, unzip into the correct directory, run `fc-cache`. There is no interactive step, no decision to make, and no variation between machines. Making it a manual step would guarantee it gets skipped at least once — typically on a new machine setup where there are many steps to complete and this one seems minor until the terminal opens and everything looks broken.

Home Manager handles this (§6.3), with two specific properties:

**Pinned version.** `nerd-fonts.jetbrains-mono` in `home.packages` is resolved against the nixpkgs version pinned by `flake.lock`. This means two machines running `hms` from the same flake revision install the same font files, regardless of when the switch is run.

**Idempotency.** `hms` only rebuilds the font symlink if the derivation output changed. On a re-run with no `flake.lock` changes, this step is a no-op.

If you ever need to verify the font installation manually:

```bash
fc-list | grep JetBrains
```

Expected output — one or more lines such as:

```
/home/yourusername/.local/share/fonts/NerdFonts/JetBrainsMonoNerdFont-Regular.ttf: JetBrainsMono Nerd Font:style=Regular
```

If this returns nothing, the font is not registered. Re-run the font installation steps:

```bash
# Re-run font cache refresh
fc-cache -fv

# If still not found, verify the files exist
ls ~/.local/share/fonts/NerdFonts/ | grep JetBrains
```

If the directory is empty, Home Manager did not install the font. Run `hms` and check for errors, or download JetBrainsMono Nerd Font manually from `nerdfonts.com`, unzip to `~/.local/share/fonts/`, and run `fc-cache -fv`.

---

### 6.3 Switching to a Different Nerd Font

JetBrainsMono is the default because it has excellent legibility at small sizes, comprehensive glyph coverage, and clear distinction between similar characters (`0`, `O`, `o`; `1`, `l`, `I`). If you prefer a different font, any font from `nerdfonts.com` works — the stack has no dependency on JetBrainsMono specifically, only on any Nerd Font being present.

**Step 1: Download the new font**

Go to `nerdfonts.com`, find your preferred font, and download the zip. Example for FiraCode:

```bash
cd /tmp
curl -fLo FiraCode.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
```

**Step 2: Install the font files**

```bash
mkdir -p ~/.local/share/fonts/NerdFonts
unzip /tmp/FiraCode.zip -d ~/.local/share/fonts/NerdFonts/
fc-cache -fv
```

**Step 3: Find the exact family name**

The name you use in `wezterm.lua` must match the font's registered family name exactly — including capitalisation and spacing.

```bash
fc-list | grep -i fira
```

Look for the family name in the output. It will appear as the second field after the file path:

```
/home/you/.local/share/fonts/NerdFonts/FiraCodeNerdFont-Regular.ttf: FiraCode Nerd Font:style=Regular
```

The family name here is `FiraCode Nerd Font`.

**Step 4: Update `wezterm.lua`**

```lua
-- In ~/dotfiles/wezterm/wezterm.lua:
font = wezterm.font("FiraCode Nerd Font"),
```

**Step 5: Reload and verify**

Press `SUPER+SHIFT+R` in WezTerm. The font changes immediately. Verify that Powerline symbols in the tmux status bar and file icons in Neovim render correctly as glyphs rather than boxes.

**Step 6: Commit**

```bash
cd ~/dotfiles
git add wezterm/wezterm.lua
git commit -m "chore: switch to FiraCode Nerd Font"
git push
```

> [!tip] Keeping the old font installed There is no reason to remove the previous font. Both fonts coexist in `~/.local/share/fonts/NerdFonts/` without conflict. WezTerm uses whichever family name is specified in `wezterm.lua`. You can switch back by changing one line and pressing `SUPER+SHIFT+R`.

---

### Part 6 Summary

Nerd Fonts are a rendering prerequisite, not a cosmetic feature. The Home Manager declaration (`nerd-fonts.jetbrains-mono` in `home.nix`) handles download, installation, and `fc-cache` refresh automatically — no manual font management required. The Noto font package in `setup-desktop.sh` is the fallback that covers Unicode codepoints the Nerd Font omits.

Switching fonts is a one-line change in `wezterm.lua` plus a `SUPER+SHIFT+R` reload. The only constraint: the family name in `wezterm.lua` must exactly match the family name in `fc-list` output.

**What carries forward:** Part 7 covers fzf, zoxide, and the shell config load order — the support tools the sessionizer and interactive shell rely on.

---

## Part 7: Support Tools — Fzf, Zoxide, and the Shell Config

> [!note] **What you now know**
> JetBrainsMono Nerd Font is installed and verified. Icons render correctly in tmux, WezTerm, and Neovim. Part 7 covers fzf and zoxide — the tools the sessionizer depends on — and the shell init order that makes everything work together.

---

> [!note] **What you will understand by the end of this part**
> - Why fzf and zoxide are hard dependencies of the stack, not optional additions
> - The exact shell initialisation order that must be preserved — and what silently breaks when it isn't
> - How to configure fzf appearance, zoxide behaviour, and shell aliases inside `home.nix` safely

fzf and zoxide are not optional additions. fzf is a hard dependency of the sessionizer (Part 3) and powers `Ctrl-R` shell history search. zoxide replaces `cd` with a learned directory jumper that dramatically reduces typing once it has observed a few days of navigation patterns. Both are installed by Home Manager and both require shell integration lines in the correct position in `home.nix`.

This part covers what each tool does, how to configure it, and — most importantly — the exact order in which shell initialization lines must appear. Getting that order wrong is the most common source of subtle, hard-to-diagnose breakage in this stack.

---

### 7.1 Why These Tools Are Not Optional

**fzf** is used in three places in this stack:

1. **The sessionizer** (Part 3) — the project picker is an fzf interface. Without fzf, `Ctrl-f` produces nothing.
2. **`Ctrl-R` shell history search** — replaces the default reverse history search with an interactive fuzzy picker over the full shell history.
3. **lazygit** — uses fzf for several interactive file and branch selection interfaces.

**zoxide** is not a hard dependency of any specific feature, but after a few days of use it becomes functionally irreplaceable. Instead of typing `cd ~/projects/mi-papelera`, you type `z pap` and arrive at the same place in three keystrokes. The sessionizer itself uses zoxide's frecency history to populate the top of the project picker — the most recently visited directories appear first.

Both are installed by Home Manager. Neither requires any configuration beyond the shell integration lines covered in §7.4.

---

### 7.2 Fzf: Fuzzy Finder

#### What Fzf Does

fzf takes any list on stdin and presents it as an interactive, real-time fuzzy filter. You type characters and the list narrows. You press Enter and the selected item goes to stdout. Every interactive picker in this stack — sessionizer, lazygit branch selection, `Ctrl-R` history — is fzf consuming a list from some source and returning the selection.

#### Installation

fzf is in `home.nix` packages (`pkgs.fzf`) and is installed by Home Manager. Verify:

```bash
fzf --version
```

#### Shell Key Bindings

Home Manager's `programs.fzf` module enables shell key bindings automatically when configured in `home.nix`. The bindings this enables:

|Key|Action|
|---|---|
|`Ctrl-R`|Fuzzy search over shell history|
|`Ctrl-T`|Fuzzy file picker, inserts selected path at cursor|
|`Alt-C`|Fuzzy `cd` into a subdirectory|

`Ctrl-R` is the one you will use constantly. It replaces the default reverse-incremental history search with a full-height fuzzy picker over your entire history. Type any fragment of a command you remember and it appears immediately.

#### Recommended `FZF_DEFAULT_OPTS`

These options configure fzf's appearance for every interface that uses it, including the sessionizer:

```bash
export FZF_DEFAULT_OPTS="
  --height 40%
  --layout=reverse
  --border
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"
```

The colour values are Catppuccin Mocha, matching WezTerm and tmux. `--layout=reverse` puts the input prompt at the bottom and the list above it — the standard orientation for terminal pickers. `--height 40%` keeps the picker compact without covering the full terminal.

This goes in `home.nix` `programs.zsh.initContent`. The exact position in the init block is covered in §7.4.

#### Verification

```bash
# Basic picker test — should open an interactive list
echo -e "one\ntwo\nthree" | fzf

# History search — press Ctrl-R in your shell
# Should open a full fuzzy history picker, not the default reverse search
```

---

### 7.3 Zoxide: Smart Directory Jumper

#### What Zoxide Does

zoxide tracks every directory you visit and builds a frecency database — a score that combines frequency (how often) and recency (how recently). The `z` command jumps to the highest-scoring directory that matches your query. After a few days of use, `z pap` reliably jumps to `~/projects/mi-papelera` and `z ach` jumps to `~/work/achemex`.

`zi` opens an interactive fzf picker over all known directories — useful when the non-interactive `z` produces the wrong match.

#### Installation

zoxide is in `home.nix` packages (`pkgs.zoxide`) and is installed by Home Manager. Verify:

```bash
zoxide --version
```

#### Daily Usage

```bash
# Jump to the best match for a partial name
z pap         # → ~/projects/mi-papelera
z ach         # → ~/work/achemex
z dot         # → ~/dotfiles

# Interactive picker over all known directories
zi

# Add a directory to the database immediately (without cd-ing there)
zoxide add ~/projects/my-project

# Show the top matches for a query without jumping
zoxide query --list pap
```

#### Populating Zoxide on a New Machine

zoxide starts empty — it only knows directories you have visited since it was installed. On a fresh machine after the bootstrap, run `zoxide add` for your main project directories before the database builds up naturally:

```bash
zoxide add ~/projects
zoxide add ~/dotfiles
# Add any other directories you navigate to frequently
```

After a week of normal use, the database is populated and `z` becomes consistently useful.

> [!tip] zoxide and the sessionizer work together The sessionizer's directory discovery block calls `zoxide query --list` to populate the top of the fzf picker with your most-visited directories. The more you use `z` and `cd` normally, the better the sessionizer's default ordering becomes. The two tools reinforce each other.

#### The `cd` Alias Ordering Warning

Some developers alias `cd` to `z` so that normal `cd` usage populates the zoxide database automatically:

```bash
alias cd='z'
```

If you use this alias, it must be defined _before_ `eval "$(zoxide init zsh)"` in your shell config. zoxide's init script checks whether `cd` is already aliased and adjusts its behaviour accordingly. If zoxide initialises first and finds no `cd` alias, then the alias is added afterward, the zoxide integration may not intercept `cd` correctly.

The correct shell load order, which handles this, is in §7.4.

---

### 7.4 Shell Config Load Order — The Most Common Source of Subtle Breakage

> [!important] Read this section even if the tools are already working Subtle ordering failures are often latent — everything seems fine until you add one more tool or change one line, at which point the interaction between two incorrectly ordered initializers produces a failure that looks like the new tool's fault but is actually an ordering problem that was always there.

Home Manager generates `~/.zshrc` from your `home.nix` configuration. You never edit `~/.zshrc` directly. All shell initialization — PATH additions, tool hooks, aliases — goes in `home.nix` `programs.zsh.initContent`. Home Manager places this block near the end of the generated `~/.zshrc`, after the Nix profile is sourced.

Within `initContent`, order matters. Here is the complete block in the correct order, with a one-sentence explanation of why each line must precede the next:

```bash
# In home.nix → programs.zsh.initContent:

# ── 1. PATH additions ─────────────────────────────────────────────────────────
# Must be first. Every tool initialized below needs its binary findable.
# ~/.local/bin holds the sessionizer symlink and any user-installed scripts.
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.nix-profile/bin:$PATH"

# ── 2. Nix environment ────────────────────────────────────────────────────────
# Sources the Nix profile, making nix-installed binaries available.
# Must come before any tool whose binary lives in the Nix store.
. "$HOME/.nix-profile/etc/profile.d/nix.sh"

# ── 3. direnv hook — must be early ───────────────────────────────────────────
# tmux fires its initial window command as soon as a pane shell starts,
# before .zshrc finishes loading. If direnv is initialized too late,
# the first pane in every new tmux session will not have direnv active,
# and devenv environments will not activate automatically on cd.
eval "$(direnv hook zsh)"

# ── 4. cd alias — must come before zoxide init ───────────────────────────────
# If you want `cd` to route through zoxide, define the alias HERE — before
# `eval "$(zoxide init zsh)"`. zoxide's init script checks whether `cd` is
# already aliased and adjusts its integration accordingly. Defining the alias
# after zoxide init means zoxide never intercepts it correctly.
alias cd='z'   # optional: remove this line if you prefer to use `z` explicitly

# ── 5. zoxide — must come after the cd alias ─────────────────────────────────
# zoxide init checks for an existing cd alias; if you alias cd=z,
# that alias must be defined before this line.
eval "$(zoxide init zsh)"

# ── 6. fzf options ───────────────────────────────────────────────────────────
# Shell key bindings (Ctrl-R, Ctrl-T, Alt-C) are injected automatically by
# Home Manager when programs.fzf.enableZshIntegration = true is set.
# Do NOT add `source ~/.fzf.zsh` manually — Home Manager generates and sources
# the integration file itself; the path may not exist for Nix-installed fzf.
export FZF_DEFAULT_OPTS="
  --height 40%
  --layout=reverse
  --border
  --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
  --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
  --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

# ── 7. Starship prompt — must be last ────────────────────────────────────────
# Starship wraps the shell prompt by modifying PS1/PROMPT.
# Any initializer that runs after starship and also modifies the prompt
# will silently overwrite Starship's output, breaking the prompt display.
eval "$(starship init zsh)"

# ── 8. Remaining aliases — after all tool inits ───────────────────────────────
# These aliases have no ordering sensitivity relative to each other,
# but must come after the tool inits they reference.
alias ls='eza --color=auto --icons'
alias cat='bat'
```

**The three ordering rules that cause the most problems when violated:**

**Direnv must be early (rule 3).** When tmux creates a new session with `tmux new-session -c ~/projects/my-project`, the shell that opens in that pane runs `.zshrc` from the beginning. If direnv is initialized near the end of `.zshrc` and tmux's initial window command fires before that point, direnv is not active for that pane. The environment never activates. `which python` shows a system path. The symptom is identical to not having run `direnv allow` — confusing if you have definitely run it.

**The `cd` alias must come before zoxide init (rule 4).** zoxide's init script detects whether `cd` is already aliased and configures its hook accordingly. If you define `alias cd='z'` after `eval "$(zoxide init zsh)"`, zoxide has already finished its setup and the alias is never intercepted. The `cd` command appears to work but does not populate the zoxide database, breaking the sessionizer's frecency ordering over time.

**Starship must be last (rule 7).** Starship modifies `PS1` (the prompt variable). Any subsequent initializer that also touches `PS1` — a version manager, another prompt tool, a shell framework — silently overwrites Starship's configuration. The symptom: the Starship prompt renders for a moment and then reverts to a plain prompt, or shows a garbled mix of Starship and another prompt format.

---

### 7.5 How to Add a New Shell Tool

Every shell tool that needs initialization follows the same pattern. No exceptions — editing `~/.zshrc` directly will be overwritten by the next `hms`.

**Step 1: Add the binary to `home.nix` packages**

```nix
home.packages = with pkgs; [
  # ... existing packages ...
  your-new-tool
];
```

**Step 2: Add the initialization line to `home.nix` programs.zsh.initContent**

Place it in the correct position per the load order in §7.4. If the tool modifies the prompt, it must go before Starship (rule 7). If it depends on PATH, it must go after PATH additions (rule 1). If it is a simple alias or export with no ordering sensitivity, place it in the aliases block at the end.

```nix
programs.zsh = {
  enable = true;
  initContent = ''
    # ... existing init lines in correct order ...
    eval "$(your-new-tool init zsh)"   # place at the correct position
  '';
};
```

**Step 3: Apply and verify**

```bash
hms
# Open a new shell (the current shell has the old .zshrc)
your-new-tool --version
```

**Step 4: Commit**

```bash
cd ~/dotfiles
git add home.nix
git commit -m "feat: add your-new-tool to shell config"
git push
```

> [!warning] Never edit `~/.zshrc` directly Home Manager overwrites `~/.zshrc` on every `hms`. Any change made directly to `~/.zshrc` will be silently lost. If you find yourself wanting to edit `~/.zshrc`, the correct action is to identify which `home.nix` block the change belongs in and make it there. The mapping is: packages → `home.packages`; initialization hooks and shell functions → `programs.zsh.initContent`; simple aliases (like `alias ls='eza'`) → either `programs.zsh.shellAliases` (cleaner, declarative) or the aliases block in `initContent` (consistent with functions already there). The Appendix B template places all aliases and functions in `initContent` for simplicity.

---

### Part 7 Summary

fzf and zoxide are multipliers: fzf makes `Ctrl-R` history search fast enough to replace muscle-memory retyping; zoxide makes `z project` faster than any alias. Both are declared in `home.nix` and require no manual PATH management.

The shell init load order (§7.4) is the most consequential thing in this Part. The seven rules are not arbitrary — each has a specific dependency on what ran before it. Getting the order wrong produces silent breakage: tools that appear installed but behave incorrectly, completions that don't fire, or direnv that activates too late for tmux panes.

**What carries forward:** Part 8 covers Devenv — the per-project environment layer that Direnv activates when you `cd` into a project directory.

---

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

> [!tip] Just want to copy and paste? Skip to **Appendix C**, which has the same file without the pedagogical annotations — ready to drop into a project root.

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
> **Copy-paste version:** The full `devenv.nix` without pedagogical annotations is in Appendix C.

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

Create `docker-compose.yml` in your project root. The complete annotated file is in Appendix D. Key points:

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

### 8.7 VS Code Integration

Two settings are required for VS Code to use the devenv environment correctly. Both are covered in full in Part 3; this section covers only the devenv-specific parts.

**`mkhl.direnv` extension** reads `.envrc` and activates the devenv environment inside VS Code's process. Without it, VS Code extensions find only the system `$PATH` and either fail to find tools or find the wrong global versions. This extension is in `vscode/extensions.txt`; install it with the rest of your extensions as described in §11.3.

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

```bash
cd ~/projects/my-project
git add devenv.nix devenv.lock
git commit -m "chore: describe what changed"
git push
```

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
> - The three shell utility functions (`repo-status`, `gpr`, `git-cleanup`) and how to add them to `home.nix`

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

The bootstrap handles four git-specific configuration steps that do not require user interaction.

#### Git Identity

The bootstrap prompts for `user.name` and `user.email` if they are not already set:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

These are stored in `~/.gitconfig`. Verify after the bootstrap:

```bash
git config --global user.name
git config --global user.email
```

#### Delta as Pager for Both `git` and `gh`

```bash
git config --global core.pager delta
git config --global delta.side-by-side true
git config --global delta.line-numbers true
git config --global delta.navigate true
gh config set pager delta
```

> [!important] Two separate settings are required `git` and `gh` have completely independent output pipelines. Setting `core.pager delta` configures git's output. `gh config set pager delta` configures gh's output. One does not affect the other. The bootstrap sets both. If you ever find that `gh pr diff` does not show delta highlighting but `git diff` does, run `gh config get pager` — it should print `delta`. If it does not, run `gh config set pager delta`.

#### Git Aliases

These aliases are configured globally and used throughout Dev Workflows's workflows:

|Alias|Expands to|Purpose|
|---|---|---|
|`git sw`|`git switch`|Switch to an existing branch|
|`git co`|`git checkout -b`|Create and switch to a new branch|
|`git st`|`git status --short`|Compact status — changed files only, no prose|
|`git pushf`|`git push --force-with-lease`|Force push safely — fails if remote has moved|
|`git lg`|`git log --oneline --graph --decorate --all`|Visual commit graph across all branches|

`git pushf` deserves specific attention: `--force-with-lease` checks that the remote branch has not moved since your last fetch before overwriting it. Plain `--force` overwrites regardless of what is there, including a teammate's commits. `git pushf` makes the safe option the default.

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

Add all three to the aliases block at the end of `programs.zsh.initContent` (after Starship, per the load order in §9.4):

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

### Part 9 Summary

All git configuration — identity, delta pager, aliases — is declared in `home.nix` `programs.git`. This means git config is reproducible across machines and never set manually. The bootstrap does not write a single line of `git config` directly.

The `gh`/`delta`/`lazygit` trio covers the three modes of git work: repository operations from the shell (`gh`), diff review (`delta`), and interactive branching and staging (`lazygit`). `gh poi` (or the local `poi()` shell function) solves the branch accumulation problem that builds up silently over weeks of feature work.

`gh` extensions are not managed by Home Manager. After a fresh bootstrap, they must be reinstalled manually. Leave a comment in `home.nix` as a reminder for new machine setup.

**What carries forward:** Part 10 covers Neovim with LazyVim — the most complex section of the guide, and the one that introduces the "project owns its config" philosophy that applies equally to VS Code.

---

## Part 10: Neovim with LazyVim — The "Project Owns Its Configuration" Philosophy

> [!note] **What you now know**
> Git is configured with delta, `gh` is authenticated, lazygit is available, and the three utility functions are in `home.nix`. Part 10 covers Neovim with LazyVim — the most complex part of the stack.

---

> [!note] **What you will understand by the end of this part**
> - The "project owns its config" principle: why LSP servers, formatters, and linters come from Devenv, not Mason
> - The four configuration vectors (LazyVim defaults, `plugins/`, `config/`, `.lazy.lua`) and when to use each
> - How to set up language support for Python, TypeScript, Lua, and YAML/TOML
> - How DAP debugging works and why `debugpy` cannot go in `devenv.nix packages`
> - How Neovim integrates with tmux (navigator) and Gemini CLI (send-to-AI keymap)

This is the largest section in the guide. It covers both the Neovim installation and the philosophy that governs how formatting, linting, LSP, and debugging work across the entire stack — including VS Code. The concepts introduced here apply equally to both editors.

---

### 10.1 What This Setup Achieves

A Neovim installation that:

- **Auto-formats on save** using the formatter the project has declared, at the version the project has pinned
- **Reports LSP diagnostics inline** from a language server running in the background
- **Runs linters on save** showing problems as underlines, without modifying the file
- **Supports step-through debugging** with breakpoints set in the editor, adapters discovered from `$PATH`
- **Requires zero per-project Neovim configuration** — a new developer clones a repository, runs `direnv allow` and `just setup`, and everything works

The zero-configuration property is not magic — it is the result of a deliberate architecture described in §10.5 and §10.6.

---

### 10.2 Why the Neovim Config Lives Outside Home Manager

Home Manager stores managed config files in the read-only `/nix/store`. LazyVim needs to write its plugin lock file (`lazy-lock.json`) and plugin data to `~/.config/nvim/` at runtime. If Home Manager symlinked `~/.config/nvim` into the Nix store, Neovim would crash immediately with a read-only filesystem error.

The solution is `config.lib.file.mkOutOfStoreSymlink` in `home.nix`:

```nix
# home.nix
home.file.".config/nvim".source =
  config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/dotfiles/nvim";
```

This tells Home Manager to create `~/.config/nvim` as a direct symlink to `~/dotfiles/nvim` — a mutable path outside the Nix store. LazyVim can write to it freely. The underlying config files are still version-controlled in your dotfiles repository.

> [!warning] The dotfiles path is hardcoded `mkOutOfStoreSymlink` requires an absolute path. Your Neovim config depends on `~/dotfiles/nvim` existing at exactly that location. Moving the dotfiles repository breaks the symlink until you run `hms` again with the updated path.

This is the documented pattern for mutable config files with Home Manager. It is not a workaround.

---

### 10.3 File Structure and Path Clarity

Every file in `~/dotfiles/nvim/` with its purpose, who writes it, and whether it should be committed:

```
~/dotfiles/nvim/
  init.lua                   # LazyVim entry point — do not edit directly
  lazyvim.json               # Enabled LazyExtras — commit this
  lazy-lock.json             # Plugin version lockfile — commit this
  lua/
    config/
      options.lua            # Global vim options (clipboard, etc.) — edit freely
      keymaps.lua            # Global keymaps — edit freely
      autocmds.lua           # Global autocommands — edit freely
    plugins/
      lsp.lua                # mason=false, server declarations — created in §10.11
      formatting.lua         # conform.nvim: filetype→binary + condition gates
      linting.lua            # nvim-lint: filetype→linter + condition guards
      dap.lua                # nvim-dap: adapter setup, load_launchjs()
      neoconf.lua            # neoconf.nvim plugin declaration
```

**`lazy-lock.json` and `lazyvim.json` must be committed.** `lazy-lock.json` records the exact commit hash of every installed plugin — committing it means every machine running `hms` and then `nvim --headless "+Lazy! sync" +qa` gets bit-for-bit identical plugin versions. `lazyvim.json` records which LazyExtras are enabled.

---

### 10.4 Installation

The bootstrap staged the LazyVim starter into `~/dotfiles/nvim/` (step 10) and ran the headless plugin sync (step 11). Opening Neovim for the first time should show a fully loaded LazyVim interface with no plugin installation in progress.

Run `:checkhealth` inside Neovim after first open. Look for:

- No `ERROR` lines — any error indicates a missing dependency
- `WARNING` lines for optional features are acceptable — read them but do not act on every one immediately
- Confirm `clipboard` is working (should show `xclip` or `wl-copy` as the provider)

If `:checkhealth` shows plugin errors, the headless sync may have failed silently. Run `:Lazy sync` to install missing plugins interactively.

---

### 10.5 The "Project Owns Its Configuration" Philosophy

_The conceptual foundation for everything that follows. Read this before touching any plugin config._

Two places where formatting, linting, and LSP rules can live:

1. **Inside your editor** (`~/dotfiles/nvim/lua/plugins/`)
2. **Inside the project** (`.editorconfig`, `pyproject.toml`, `devenv.nix`, `pyrightconfig.json`, `.prettierrc`, etc.)

This guide advocates strongly for option 2. Four reasons:

**Editor independence.** Your teammates may use VS Code, JetBrains, or Emacs. Rules encoded in your Neovim config apply only when _you_ open a file. A teammate using VS Code will format differently, producing constant noise in diffs that has nothing to do with actual logic changes.

**The project owns its standards.** Formatting rules, linter configuration, and type-checking strictness are part of a project's definition of "correct code." They belong in the repository, versioned alongside the code, visible to every contributor from day one.

**Onboarding.** A new contributor clones the repository and their editor — whatever it is — picks up the rules automatically. No "ask Alberto which settings to use."

**CI/CD alignment.** When CI runs `ruff check .` or `prettier --check`, it reads the same config files your editor reads. Rules cannot silently diverge between local development and the pipeline.

**The guiding principle:**

> If a tool has a project-local config file, use it. Only put something in the Neovim config when it has no other home.

---

### 10.6 The Three Enforcement Layers

Formatting and linting are enforced at three distinct points, each with different trigger conditions and bypass characteristics:

```
┌──────────────────────────────────────────────────────┐
│  LAYER 1: Editor (Neovim conform.nvim / VS Code)     │
│  Trigger:  you save a file (:w)                      │
│  Bypass:   always possible — it's your editor        │
│  Purpose:  fast feedback while you write             │
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│  LAYER 2: pre-commit hook                            │
│  Trigger:  git commit                                │
│  Bypass:   git commit --no-verify                    │
│  Purpose:  safety net — catches what the editor missed│
└──────────────────────────────────────────────────────┘
                        ↓
┌──────────────────────────────────────────────────────┐
│  LAYER 3: CI pipeline (GitHub Actions)               │
│  Trigger:  git push / pull request                   │
│  Bypass:   not possible to merge without passing     │
│  Purpose:  true enforcer                             │
└──────────────────────────────────────────────────────┘
```

**Critical insight:** all three layers invoke the **same binary** and read the **same config files**. The editor never reads `pyproject.toml` — it invokes `ruff`, which finds and reads `pyproject.toml`. This is why the same Neovim configuration works correctly across projects with completely different rules, and why both Neovim and VS Code produce identical output on the same project.

---

### 10.7 The Toolchain Architecture

What each Neovim plugin does and where its configuration comes from:

```
conform.nvim      → runs formatters on :w
                    reads filetype→binary from lua/plugins/formatting.lua
                    binary reads rules from pyproject.toml / .prettierrc / etc.

nvim-lint         → runs linters on BufWritePost / InsertLeave
                    reads filetype→linter from lua/plugins/linting.lua
                    linter reads rules from pyproject.toml / .eslintrc / etc.

nvim-lspconfig    → starts language servers on file open
                    server binary found on $PATH (mason=false) — devenv provides it
                    server reads rules from pyrightconfig.json / tsconfig.json

nvim-dap          → manages debugger sessions
                    adapter binary found via vim.fn.exepath() on $PATH
                    launch configurations from .vscode/launch.json
```

The Neovim plugins are thin wiring layers. They map filetypes to binary names and handle the editor-side protocol. The binaries, their versions, and their rules all live outside the editor.

---

### 10.8 `.editorconfig`: The Universal Baseline

EditorConfig controls the most fundamental mechanical editor properties: indentation style and size, line endings, character encoding, trailing whitespace, final newline. Neovim 0.9+ reads `.editorconfig` natively — no plugin required.

Create `.editorconfig` at the project root:

```ini
# .editorconfig
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.py]
indent_size = 4

[*.{js,ts,jsx,tsx}]
indent_size = 2

[*.{yaml,yml}]
indent_size = 2

[*.json]
indent_size = 2

[*.lua]
indent_size = 2

# Markdown: do NOT trim trailing whitespace
# Two trailing spaces = intentional line break in Markdown
[*.md]
trim_trailing_whitespace = false
indent_size = 2

# Makefiles MUST use real tabs — spaces break them
[Makefile]
indent_style = tab

# Justfiles also use tabs
[justfile]
indent_style = tab
```

**What EditorConfig does NOT control:** which formatter runs, which linter rules apply, LSP behaviour, or anything beyond the mechanical properties above.

**Verification:**

```vim
:verbose set tabstop?
```

The output should include `Last set from editorconfig`. If it shows a different source, `.editorconfig` is not being read — confirm the file is at the project root and that Neovim is version 0.9 or later.

---

### 10.9 Formatters

#### How Formatting Works End-to-End

```
You press :w
        ↓
conform.nvim looks up current filetype in formatters_by_ft
  python → run "ruff" (fix mode), then "ruff_format"
        ↓
ruff binary invoked — finds pyproject.toml by walking up the directory tree
  applies [tool.ruff.lint] fixes (import sorting, unused imports)
  applies [tool.ruff.format] style rules
        ↓
Formatted output replaces buffer contents
```

The editor never reads `pyproject.toml`. It invokes the binary. The binary finds its own config.

#### What LazyVim Already Does

When you enable `lang.python` via `:LazyExtras`, LazyVim automatically wires `python → ruff_format`. Check what is already active:

```vim
:LazyFormatInfo
```

If the output shows the formatters you want and `condition: true` for all of them, you may not need `formatting.lua` at all for those filetypes.

#### When You Need `lua/plugins/formatting.lua`

Create this file in exactly one of these situations:

1. You want a formatter for a filetype no LazyVim extra covers
2. You want to change the default formatter choice (e.g. use `black` instead of `ruff_format`)
3. You want to add condition gates for formatters LazyVim does not gate by default

#### The Condition Gate

A condition gate prevents a formatter from running in projects that have not opted in. Without it, `ruff_format` would run on every `.py` file you open anywhere on your system — including scripts in your home directory with no `pyproject.toml`. The gate checks whether a config file exists in the project tree:

```lua
condition = function(_, ctx)
  return vim.fs.find(
    { "ruff.toml", ".ruff.toml", "pyproject.toml" },
    { path = ctx.filename, upward = true }
  )[1] ~= nil
end
```

`vim.fs.find` walks up the directory tree from the current file's location. If it finds any of the listed files, the formatter runs. If not, it is silently skipped — no error, no message.

#### The Complete `formatting.lua`

```lua
-- ~/dotfiles/nvim/lua/plugins/formatting.lua
-- Purpose: declare which formatter runs per filetype, gate each one
--          so it only runs in projects that have opted in via a config file.
--
-- ACTION: create this file if it does not exist.
--         If it already exists, merge the opts table below into it.

return {
  "stevearc/conform.nvim",
  opts = {

    -- ── Part 1: filetype → formatter mapping ──────────────────────────
    --
    -- Maps filetypes to the binary name(s) to run on save.
    -- Multiple entries run in order. "ruff" runs in fix mode first
    -- (import sorting, auto-fixable lint violations), then "ruff_format"
    -- applies style formatting.
    --
    -- LazyVim extras pre-populate some of these. Declaring them here
    -- overrides those defaults and makes your setup explicitly visible.
    formatters_by_ft = {
      python          = { "ruff", "ruff_format" },
      javascript      = { "prettier" },
      typescript      = { "prettier" },
      javascriptreact = { "prettier" },
      typescriptreact = { "prettier" },
      html            = { "prettier" },
      css             = { "prettier" },
      scss            = { "prettier" },
      json            = { "prettier" },
      yaml            = { "prettier" },
      markdown        = { "prettier" },
      lua             = { "stylua" },
      sh              = { "shfmt" },
      bash            = { "shfmt" },
    },

    -- ── Part 2: condition gates ────────────────────────────────────────
    --
    -- Each formatter only runs when the project has a config file.
    -- The condition function returns true (run) or false (skip silently).
    formatters = {

      ruff_format = {
        condition = function(_, ctx)
          return vim.fs.find(
            { "ruff.toml", ".ruff.toml", "pyproject.toml" },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },

      ruff = {
        condition = function(_, ctx)
          return vim.fs.find(
            { "ruff.toml", ".ruff.toml", "pyproject.toml" },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },

      -- Note: LazyVim already ships a prettier condition gate.
      -- This entry is shown for reference — you do not need to add it.
      -- Do NOT include "package.json" in this list — every JS project
      -- has one, which would make the gate useless.
      prettier = {
        condition = function(_, ctx)
          return vim.fs.find(
            { ".prettierrc", ".prettierrc.json", ".prettierrc.js",
              ".prettierrc.toml", ".prettierrc.yaml", ".prettierrc.yml",
              "prettier.config.js", "prettier.config.ts" },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },

      stylua = {
        condition = function(_, ctx)
          return vim.fs.find(
            { "stylua.toml", ".stylua.toml" },
            { path = ctx.filename, upward = true }
          )[1] ~= nil
        end,
      },
    },
  },
}
```

#### Project Config Files for Formatters

**Python — `pyproject.toml`:**

```toml
[tool.ruff]
# target-version: set to match your Python version.
# ERPNext v15 → "py311"
# ERPNext v16 → "py314"
target-version = "py311"
line-length = 88
exclude = [".git", ".venv", "__pycache__", "migrations"]

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
magic-trailing-comma = true
docstring-code-format = true
```

**JavaScript/TypeScript — `.prettierrc`:**

```json
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 80,
  "endOfLine": "lf"
}
```

**Lua — `stylua.toml`:**

```toml
column_width = 120
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

#### Verification

```vim
:LazyFormatInfo
```

Expected output for a Python file inside a project with `pyproject.toml`:

```
Active formatters for python:
  ruff        ✓ (condition: true)
  ruff_format ✓ (condition: true)
```

If a formatter shows `condition: false`: the project has no matching config file in the directory tree. If a formatter is missing entirely: either the binary is not on `$PATH` (`which ruff` in the terminal) or the `formatters_by_ft` entry is absent.

```vim
:ConformInfo
```

Shows binary paths for all registered formatters — use this to confirm devenv's binary is being used, not Mason's.

---

### 10.10 Linters

#### How Linting Works

Unlike formatters, linters report problems without modifying files. `nvim-lint` runs the configured linter binary on `BufWritePost` (after save), `BufReadPost` (on open), and `InsertLeave` (when you stop typing). The output feeds into Neovim's diagnostic system — the red and yellow underlines with messages in the status line.

#### What LazyVim Already Does

Check active linters:

```vim
:lua vim.notify(vim.inspect(require("lint").linters_by_ft))
```

If the output already shows what you want for each filetype, you may not need `linting.lua`.

#### The Condition Guard for Nvim-lint

`nvim-lint` does not have a built-in `condition` key like `conform.nvim`. The guard is implemented by patching each linter object's `condition` field in a `config` function. This is the pattern LazyVim supports:

```lua
local shellcheck = require("lint").linters.shellcheck
if shellcheck then
  shellcheck.condition = function(ctx)
    return vim.fs.find(
      { ".shellcheckrc" },
      { path = ctx.filename, upward = true }
    )[1] ~= nil
  end
end
```

Without condition guards, linters produce false diagnostics on files outside proper projects — a flood of errors on scripts in your home directory that have no config, obscuring real problems in actual projects.

#### The Complete `linting.lua`

```lua
-- ~/dotfiles/nvim/lua/plugins/linting.lua
-- Purpose: declare which linter runs per filetype, add condition guards
--          so linters only run in projects that have opted in.
--
-- ACTION: create this file if it does not exist.

return {
  "mfussenegger/nvim-lint",
  opts = {
    linters_by_ft = {
      python = { "ruff" },      -- ruff in lint mode (fast; same binary as formatter)
      sh     = { "shellcheck" },
      yaml   = { "yamllint" },
    },
  },
  config = function(_, opts)
    local lint = require("lint")

    -- Apply the linters_by_ft table
    lint.linters_by_ft = opts.linters_by_ft or {}

    -- ── Condition guards ──────────────────────────────────────────────
    -- Patch each linter's condition field. Returns true = run, false = skip.

    local ruff = require("lint").linters.ruff
    if ruff then
      ruff.condition = function(ctx)
        return vim.fs.find(
          { "ruff.toml", ".ruff.toml", "pyproject.toml" },
          { path = ctx.filename, upward = true }
        )[1] ~= nil
      end
    end

    local shellcheck = require("lint").linters.shellcheck
    if shellcheck then
      shellcheck.condition = function(ctx)
        return vim.fs.find(
          { ".shellcheckrc" },
          { path = ctx.filename, upward = true }
        )[1] ~= nil
      end
    end

    local yamllint = require("lint").linters.yamllint
    if yamllint then
      yamllint.condition = function(ctx)
        return vim.fs.find(
          { ".yamllint", ".yamllint.yaml", ".yamllint.yml" },
          { path = ctx.filename, upward = true }
        )[1] ~= nil
      end
    end

    -- ── Trigger linting on save and on file open ──────────────────────
    vim.api.nvim_create_autocmd(
      { "BufWritePost", "BufReadPost", "InsertLeave" },
      {
        callback = function()
          lint.try_lint()
        end,
      }
    )
  end,
}
```

#### The mypy-in-CI-only Pattern

mypy can take 30–60 seconds on a large codebase. Running it on every save degrades the editor experience; running it on every commit makes commits feel sluggish. The recommended pattern:

- **Editor (Neovim):** ruff only — fast, instant feedback
- **pre-commit hook:** ruff only — catches what the editor missed, still fast
- **CI:** mypy as a separate job — thorough, slow, does not block local workflow

To implement this: omit mypy from `linters_by_ft` in `linting.lua`, omit it from `.pre-commit-config.yaml`, and add it as a separate GitHub Actions job:

```yaml
# .github/workflows/quality.yml
jobs:
  mypy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install -e ".[dev]"
      - run: mypy app/ --ignore-missing-imports
```

#### Project Config Files for Linters

**Python — `pyproject.toml`:**

```toml
[tool.ruff.lint]
select = ["E", "W", "F", "I", "B", "C4", "UP"]
ignore = ["E501"]  # line length handled by formatter
fixable = ["I", "UP", "C4"]

[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["S101", "ANN"]
"**/migrations/*.py" = ["E501", "F401"]
```

**Shell — `.shellcheckrc`:**

```
disable=SC2034
disable=SC1091
shell=bash
```

**YAML — `.yamllint`:**

```yaml
extends: default
rules:
  line-length:
    max: 120
    level: warning
  document-start: disable
```

---

### 10.11 LSP: Language Servers

#### What an LSP Server Is

A language server is a background process that deeply understands a programming language. It provides autocompletion, go-to-definition, find-references, inline error reporting, and rename refactoring. Unlike formatters (invoked once per save and exit), LSP servers start when you open a file and run continuously while you edit.

#### The Four LSP Components

```
┌───────────────────────────────────────────────────────────┐
│ 1. Neovim built-in LSP client                             │
│    Handles the protocol communication with the server     │
│    API: vim.lsp.*, vim.lsp.config(), vim.lsp.enable()     │
│    You do not call these directly — other layers do it    │
└───────────────────────────────────────────────────────────┘
              ↓ configured by
┌───────────────────────────────────────────────────────────┐
│ 2. nvim-lspconfig                                         │
│    Pre-written launch configs for 200+ servers            │
│    Knows each server's command, filetypes, root detection │
│    You override its defaults per-server in lsp.lua        │
└───────────────────────────────────────────────────────────┘
              ↓ server binaries installed by (default)
┌───────────────────────────────────────────────────────────┐
│ 3. Mason                                                  │
│    Downloads LSP server binaries globally                 │
│    Installs to ~/.local/share/nvim/mason/bin/             │
│    Managed with :Mason inside Neovim                      │
└───────────────────────────────────────────────────────────┘
              ↓ connected to nvim-lspconfig by
┌───────────────────────────────────────────────────────────┐
│ 4. mason-lspconfig                                        │
│    Bridge: Mason-installed servers → nvim-lspconfig       │
│    Translates package names to server names               │
│    LazyVim wires this up automatically                    │
└───────────────────────────────────────────────────────────┘
```

> [!tip] Neovim 0.11 introduces `vim.lsp.config()` and `vim.lsp.enable()` These are a new built-in layer that partially overlaps with nvim-lspconfig. You do not call these functions directly in this stack — LazyVim and nvim-lspconfig handle everything. The diagram above shows the architecture for understanding, not for direct use.

#### The Two Kinds of LSP Settings

This distinction is the most important conceptual point in this section:

**Language rules** — what the server enforces: type strictness, Python version, import paths, virtualenv path. These live in **project config files** (`pyrightconfig.json`, `pyproject.toml [tool.pyright]`, `tsconfig.json`). Every editor reads these automatically — no Neovim config needed.

**Editor-interaction settings** — how Neovim communicates with the server: virtual text display, inlay hints, specific capabilities. These live in `.neoconf.json` (Neovim-specific) or `.vscode/settings.json` (VS Code).

#### The `mason = false` Mechanism

Setting `mason = false` per server in `lsp.lua` tells LazyVim to find the binary on `$PATH` rather than downloading it via Mason:

```
For each server in the servers table:

  mason == true (default):
    → Mason downloads binary to ~/.local/share/nvim/mason/bin/
    → devenv's binary is ignored

  mason == false:
    → Neovim searches $PATH directly
    → devenv's pinned binary is found ✓
```

You still enable language support via `:LazyExtras`. The extra configures keymaps, capabilities, filetype triggers, and diagnostic display. `mason = false` only changes where the binary comes from — everything else the extra provides still applies.

#### The Mason vs. Devenv Decision Rule

|Server|Where|Reason|
|---|---|---|
|`pyright`, `ts_ls`, `eslint`|devenv + `mason = false`|Version matters per project|
|`lua_ls`|Mason|Used to edit Neovim config, which is not inside any devenv project|
|`jsonls`, `yamlls`, `bashls`|Mason|Generic, version-insensitive, always useful|
|Any new language server|devenv + `mason = false`|Consistent with the philosophy|

#### The Complete `lsp.lua`

```lua
-- ~/dotfiles/nvim/lua/plugins/lsp.lua
-- Purpose: declare which servers get their binary from devenv ($PATH)
--          vs which are managed by Mason.
--
-- This is your global Home Manager config — it applies to all projects.
-- Per-project server rules go in pyrightconfig.json / tsconfig.json / etc.
--
-- ACTION: create this file if it does not exist.

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {

      -- ── Project-specific servers: binary from devenv ───────────────
      -- mason = false tells LazyVim to find the binary on $PATH.
      -- devenv.nix must include the corresponding package for each project
      -- that uses these servers. (§10.18 has the per-language packages.)

      -- Python: pyright
      -- devenv.nix package: pkgs.pyright
      -- Project config: pyrightconfig.json or pyproject.toml [tool.pyright]
      pyright = {
        mason = false,
        settings = {
          python = {
            -- These settings are overridden by .neoconf.json per project
            analysis = {
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
            },
          },
        },
      },

      -- TypeScript: ts_ls (renamed from tsserver in nvim-lspconfig)
      -- devenv.nix package: pkgs.nodePackages.typescript-language-server
      -- Project config: tsconfig.json
      ts_ls = { mason = false },

      -- ESLint LSP: provided by vscode-langservers-extracted
      -- devenv.nix package: pkgs.nodePackages.vscode-langservers-extracted
      -- Project config: .eslintrc.json or eslint.config.js
      eslint = { mason = false },

      -- ── Global servers: binary from Mason ─────────────────────────
      -- These are version-insensitive and useful everywhere, so
      -- keeping them Mason-managed is correct. LazyVim manages them
      -- with no additional config needed here.

      -- Lua: Mason-managed because it serves the Neovim config itself
      -- (which is not inside any devenv project)
      lua_ls = {},

      -- JSON: Mason-managed, schema-aware completion for all projects
      jsonls = {},

      -- YAML: Mason-managed, schema validation for all projects
      yamlls = {},

      -- Bash: Mason-managed, useful for shell scripts everywhere
      bashls = {},
    },
  },
}
```

#### Python LSP Setup: Step by Step

**Step 1 — Enable the LazyVim extra (once per machine):**

```vim
:LazyExtras
```

Navigate to `lang.python` and press `x` to enable. Commit the updated `lazyvim.json` and `lazy-lock.json`.

**Step 2 — Add pyright to `devenv.nix` (per project):**

```nix
packages = [
  pkgs.pyright
  pkgs.ruff
  # debugpy goes in requirements.txt — not here (§10.13)
];
```

**Step 3 — Create `pyrightconfig.json` in the project root (per project):**

```json
{
  "pythonVersion": "3.11",
  "pythonPlatform": "Linux",
  "venvPath": ".",
  "venv": ".venv",
  "typeCheckingMode": "basic",
  "reportMissingImports": true,
  "reportMissingModuleSource": false,
  "exclude": ["**/__pycache__", "**/migrations", ".venv", "dist"]
}
```

Or via `pyproject.toml`:

```toml
[tool.pyright]
pythonVersion = "3.11"
venvPath = "."
venv = ".venv"
typeCheckingMode = "basic"
reportMissingImports = true
exclude = ["**/migrations", ".venv"]
```

**Step 4 — Verify:**

```bash
cd ~/projects/my-project
direnv allow

which pyright-langserver
# Expected: /nix/store/abc.../bin/pyright-langserver
# Not:      ~/.local/share/nvim/mason/bin/pyright-langserver
```

Inside Neovim on a `.py` file:

```vim
:LspInfo
" Expected:
" pyright: attached
" cmd: /nix/store/abc.../bin/pyright-langserver --stdio
" root_dir: /home/you/projects/my-project
```

#### TypeScript LSP Setup: Step by Step

**Step 1 — Enable the LazyVim extra:**

```vim
:LazyExtras → lang.typescript → x
```

**Step 2 — Add to `devenv.nix` (per project):**

```nix
packages = [
  pkgs.nodePackages.typescript-language-server
  pkgs.nodePackages.vscode-langservers-extracted  # provides eslint LSP
  pkgs.nodePackages.prettier
];
```

**Step 3 — Create `tsconfig.json` in the project root:**

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "moduleResolution": "node",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["src/**/*", "tests/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

**Step 4 — Verify:**

```bash
which typescript-language-server
# Expected: /nix/store/xyz.../bin/typescript-language-server
```

#### neoconf.nvim — For Editor-Interaction Settings

Some LSP settings are Neovim-specific and have no home in `pyrightconfig.json` or `tsconfig.json`. `neoconf.nvim` provides a `.neoconf.json` project file for these.

**Install once in your Home Manager Neovim config:**

```lua
-- ~/dotfiles/nvim/lua/plugins/neoconf.lua
return {
  "folke/neoconf.nvim",
  cmd = "Neoconf",
  -- Must load before nvim-lspconfig initializes servers
  priority = 1000,
  opts = {},
}
```

**Use `.neoconf.json` in the project root for per-project Neovim LSP overrides:**

```json
{
  "pyright": {
    "python.analysis.autoSearchPaths": true,
    "python.analysis.useLibraryCodeForTypes": true
  }
}
```

Merge order: global Neovim config → `~/.config/neoconf.json` → project `.neoconf.json`. The project always wins.

---

### 10.12 Clipboard in Neovim

Add to `~/dotfiles/nvim/lua/config/options.lua`:

```lua
vim.opt.clipboard = "unnamedplus"
```

This makes `y` (yank) and `p` (paste) use the OS clipboard register (`+`) by default. Without this, yanks go to Neovim's internal registers, which are invisible to the browser or other applications.

Requires `xclip` (X11) or `wl-clipboard` (Wayland) — both already in `home.nix` packages. Determine which you need:

```bash
echo $XDG_SESSION_TYPE   # outputs "x11" or "wayland"
```

**Verification:** yank a line in Neovim with `yy`, then paste in the browser with `Ctrl+V`. If nothing pastes, confirm the clipboard provider is installed:

```bash
which xclip      # X11
which wl-copy    # Wayland
```

---

### 10.13 DAP: Debugger

#### What DAP Is

The Debug Adapter Protocol (DAP) is a standardized protocol between editors and debugger backends — the same concept as LSP but for debugging. `nvim-dap` is the client. Adapter processes (`debugpy` for Python, `js-debug` for Node.js) speak the protocol. Launch configurations in `.vscode/launch.json` tell the adapter what to run.

#### The Three DAP Components

```
┌──────────────────────────────────────────────────────────┐
│ 1. nvim-dap                                              │
│    DAP protocol client                                   │
│    Breakpoints, step-through, variable inspection        │
│    Keymaps: <leader>db, <leader>dc, <leader>dn, etc.     │
└──────────────────────────────────────────────────────────┘
              ↓ adapters managed by (default)
┌──────────────────────────────────────────────────────────┐
│ 2. Mason                                                 │
│    Downloads debugger adapter binaries                   │
│    Installs to ~/.local/share/nvim/mason/bin/            │
└──────────────────────────────────────────────────────────┘
              ↓ bridged by
┌──────────────────────────────────────────────────────────┐
│ 3. mason-nvim-dap                                        │
│    Bridge: Mason adapters → nvim-dap configs             │
│    LazyVim wires this up automatically                   │
└──────────────────────────────────────────────────────────┘
```

#### The `debugpy` Exception

> [!warning] debugpy does NOT go in `devenv.nix` packages This is the most important exception in the entire guide. `debugpy` must be installed into the project's Python virtualenv via `requirements.txt` (or `requirements-dev.txt`), not as a Nix package in `devenv.nix`.
> 
> **Why:** The DAP adapter command is `python3 -m debugpy.adapter`. Python must be able to **import** `debugpy` — not just find it on `$PATH`. This means `debugpy` must be in the virtualenv's `site-packages`, installed by pip into `.venv/`. A Nix package places the binary on `$PATH` but does not make it importable by the project's Python interpreter.
> 
> **The fix:** add `debugpy>=1.8` to `requirements.txt`. devenv installs it into `.venv/` when the environment activates.

#### The Complete `dap.lua`

```lua
-- ~/dotfiles/nvim/lua/plugins/dap.lua
-- Purpose: configure DAP adapters to use devenv's binaries ($PATH),
--          load launch configurations from .vscode/launch.json,
--          and disable Mason auto-installation for devenv-managed adapters.

return {

  -- ── Python and Node.js DAP adapter configuration ─────────────────────
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")

      -- ── Python adapter ──────────────────────────────────────────────
      -- Uses debugpy from the project's virtualenv.
      -- vim.fn.exepath() finds the first python3 on $PATH — devenv's
      -- Python when inside a project, system Python otherwise.
      -- debugpy must be installed into .venv via requirements.txt.
      dap.adapters.python = {
        type = "executable",
        command = vim.fn.exepath("python3"),
        args = { "-m", "debugpy.adapter" },
      }

      -- ── Node.js adapter ─────────────────────────────────────────────
      -- js-debug-adapter is not reliably available in nixpkgs.
      -- Install it once with :MasonInstall js-debug-adapter
      -- The config falls back to the Mason path if not on $PATH.
      dap.adapters.node = {
        type = "executable",
        command = vim.fn.exepath("node"),
        args = {
          -- Use devenv's js-debug-adapter if available, else Mason's
          vim.fn.exepath("js-debug-adapter") ~= ""
            and vim.fn.exepath("js-debug-adapter")
            or vim.fn.stdpath("data") .. "/mason/bin/js-debug-adapter",
        },
      }

      -- Also register under pwa-node (used by some launch.json configs)
      dap.adapters["pwa-node"] = dap.adapters.node

      -- ── Load launch configurations from .vscode/launch.json ────────
      -- Runs every time nvim-dap initialises, picking up the project file.
      -- The type mapping connects launch.json "type" values to the
      -- adapter names configured above.
      require("dap.ext.vscode").load_launchjs(nil, {
        python = { "python" },
        node   = { "node", "pwa-node" },
      })
    end,
  },

  -- ── Disable Mason auto-installation for devenv-managed adapters ──────
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = {
      -- Empty list: do not auto-install any adapters
      -- devenv manages Python's debugpy; Mason handles js-debug-adapter
      ensure_installed = {},
      automatic_installation = false,
    },
  },
}
```

#### Python Debugging: Step by Step

**Step 1 — Enable the LazyVim extra:**

The `lang.python` extra already includes `nvim-dap-python` support. If you enabled it in §10.11, this step is complete.

**Step 2 — Add `debugpy` to `requirements.txt` (per project):**

```
# requirements.txt (or requirements-dev.txt)
debugpy>=1.8
```

devenv installs this into `.venv/` when the environment activates.

**Step 3 — Verify `debugpy` is importable:**

```bash
cd ~/projects/my-project
direnv allow

python3 -c "import debugpy; print(debugpy.__file__)"
# Expected:
# /home/you/projects/my-project/.venv/lib/python3.11/site-packages/debugpy/__init__.py
#
# NOT: /nix/store/.../debugpy (that means it's a Nix package, not virtualenv)
```

**Step 4 — Create `.vscode/launch.json` in the project root:**

```jsonc
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "FastAPI dev server",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": ["app.main:app", "--reload", "--host", "0.0.0.0", "--port", "8000"],
      "env": { "DATABASE_URL": "mysql://root:123@localhost:3306/erpnext" },
      "cwd": "${workspaceFolder}",
      "justMyCode": false
    },
    {
      "name": "Pytest: all tests",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": ["tests/", "-v", "--tb=short"],
      "cwd": "${workspaceFolder}"
    },
    {
      "name": "Pytest: current file",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": ["${file}", "-v"],
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

**Step 5 — Verify in Neovim:**

Open a Python file, set a breakpoint with `<leader>db`, press `<leader>dc` to start debugging. A picker shows the available launch configurations from `launch.json`. Select "FastAPI dev server" — the DAP UI should open and execution should pause at the breakpoint.

#### JavaScript/TypeScript Debugging: Step by Step

**Step 1 — The `dap.lua` above already handles Node.js.** No additional Lua config is needed.

**Step 2 — Install `js-debug-adapter` via Mason (once per machine):**

```vim
:MasonInstall js-debug-adapter
```

This installs to `~/.local/share/nvim/mason/bin/js-debug-adapter`. The `dap.lua` fallback path handles this case.

**Step 3 — Confirm Node.js is available from devenv:**

```bash
which node
# Expected: /nix/store/xyz.../bin/node (devenv's Node)
```

**Step 4 — Add JS/TS launch configurations to `.vscode/launch.json`:**

```jsonc
// Add to "configurations" array in the same .vscode/launch.json
{
  "name": "Next.js: dev server",
  "type": "node",
  "request": "launch",
  "runtimeExecutable": "npm",
  "runtimeArgs": ["run", "dev"],
  "cwd": "${workspaceFolder}",
  "env": { "NODE_ENV": "development" },
  "port": 9229
},
{
  "name": "Node.js: current file",
  "type": "node",
  "request": "launch",
  "program": "${file}",
  "cwd": "${workspaceFolder}"
}
```

#### `.vscode/launch.json` Variable Substitutions

These tokens are replaced at debug time by both VS Code and nvim-dap:

|Token|Replaced with|
|---|---|
|`${workspaceFolder}`|Project root (git root directory)|
|`${file}`|Absolute path of the currently open file|
|`${fileBasename}`|Filename only, without directory|
|`${fileDirname}`|Directory of the currently open file|
|`${env:NAME}`|Value of shell environment variable `NAME`|

#### The `.lazy.lua` Escape Hatch for DAP

When `launch.json` cannot express the logic you need — for example, dynamically locating a virtualenv at runtime — use `.lazy.lua` in the project root:

```lua
-- .lazy.lua in project root
-- Use this ONLY when launch.json cannot express the logic.
local dap = require("dap")

dap.configurations.python = {
  {
    type = "python",
    request = "launch",
    name = "FastAPI (dynamic venv)",
    module = "uvicorn",
    args = { "app.main:app", "--reload" },
    pythonPath = function()
      local venv = vim.fn.getcwd() .. "/.venv/bin/python"
      if vim.fn.executable(venv) == 1 then return venv end
      return vim.fn.exepath("python3")
    end,
  },
}

return {}
```

Prefer `.vscode/launch.json` for everything that does not need runtime logic. `.lazy.lua` requires an explicit trust approval from every developer who clones the repo (§10.15).

#### DAP Keymaps Reference (LazyVim defaults)

|Keymap|Action|
|---|---|
|`<leader>db`|Toggle breakpoint on current line|
|`<leader>dB`|Set conditional breakpoint|
|`<leader>dc`|Continue (or start — opens config picker)|
|`<leader>dn`|Step over (next line)|
|`<leader>di`|Step into function|
|`<leader>do`|Step out of function|
|`<leader>dr`|Open REPL|
|`<leader>de`|Evaluate expression under cursor|
|`<leader>dq`|Quit debugger|

---

### 10.14 Neovim ↔ Tmux Integration

#### Vim-tmux-navigator

The tmux side was configured in §10.5. The Neovim side needs a matching plugin declaration:

```lua
-- ~/dotfiles/nvim/lua/plugins/tmux-navigator.lua
return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft", "TmuxNavigateDown",
    "TmuxNavigateUp",   "TmuxNavigateRight",
  },
  keys = {
    { "<c-h>", "<cmd>TmuxNavigateLeft<cr>" },
    { "<c-j>", "<cmd>TmuxNavigateDown<cr>" },
    { "<c-k>", "<cmd>TmuxNavigateUp<cr>" },
    { "<c-l>", "<cmd>TmuxNavigateRight<cr>" },
  },
}
```

Without this, `Ctrl-h/j/k/l` stops working when focus is inside Neovim. You would need `prefix + arrow` to leave a Neovim pane — a completely different motion pattern that interrupts flow.

**Verification:** open a project with the code layout (Neovim left, Gemini right). Press `Ctrl-l` from inside Neovim — focus should move to the Gemini pane. Press `Ctrl-h` — focus should return to Neovim.

#### The `<leader>g` Send-to-Gemini Keymap

This keymap sends the current visual selection to the Gemini CLI pane:

```lua
-- ~/dotfiles/nvim/lua/config/keymaps.lua
vim.keymap.set('v', '<leader>g', function()
  vim.cmd('normal! "vy')
  local text = vim.fn.getreg('v')
  local escaped = vim.fn.shellescape(text)
  vim.fn.system('tmux send-keys -t {right} ' .. escaped .. ' Enter')
end, { desc = "Send selection to Gemini" })
```

`{right}` targets the next pane to the right — reliable in the code layout where Gemini is always pane `.2`. If Gemini is in a different position in your layout, replace `{right}` with the explicit pane index (e.g., `.2`).

**The fragility caveat:** if the Gemini pane is accidentally closed, pane numbering shifts and `{right}` may target the wrong pane. The resolution is to kill and recreate the session (§10.8).

#### persistence.nvim For Buffer Restore

persistence.nvim restores the buffer list from the last session in a directory:

```lua
-- ~/dotfiles/nvim/lua/plugins/persistence.lua
return {
  "folke/persistence.nvim",
  event = "BufReadPre",
  opts = {},
}
```

This is compatible with the declarative tmux model: the tmux session is recreated by the sessionizer, Neovim opens with `nvim .`, and persistence.nvim restores the buffer list from the last session. You get the best of both: declarative workspace creation and restored editor state.

---

### 10.15 The `.lazy.lua` Escape Hatch

`.lazy.lua` is a Lua file placed in the project root that LazyVim evaluates when you open any file in that project. It allows per-project Neovim overrides without modifying the global Home Manager config.

#### When to Use It

Four specific situations only:

1. **Override a vim option for this project** — e.g., `vim.g.autoformat = false` for a legacy codebase where running the formatter would produce thousands of changed lines
2. **Change which formatter or linter runs** when no `$PATH` solution is practical
3. **DAP Lua-level logic** — dynamic `pythonPath` function that `launch.json` cannot express (§10.13)
4. **A formatter not in conform.nvim's built-in list** that cannot be added globally

#### The Security Model

When you open a project that contains `.lazy.lua` for the first time, Neovim shows a trust prompt:

```
.lazy.lua found. Trust this file? [a]llow, [v]iew, [d]eny
```

Always press `v` first to view the file before pressing `a` to allow. Never press `a` blindly on a cloned repository.

Trust is stored in `~/.local/share/nvim/trust` and is per-machine. Every developer who clones a project with `.lazy.lua` must approve it on their machine. This cannot be pre-approved in the repository. Include a note in the project README explaining that `.lazy.lua` is present and what it does.

#### `vim.g.autoformat = false` For Legacy Codebases

```lua
-- .lazy.lua in project root
-- This project has not adopted automated formatting yet.
-- Disable format-on-save to prevent noise in diffs.
vim.g.autoformat = false

return {}
```

This is a project-level decision — commit it so all Neovim users of the project get consistent behaviour.

#### What You Cannot Do in `.lazy.lua`

- Add new plugins not already declared in your Home Manager Neovim config — the dependency graph is fixed at startup
- Call `vim.lsp.enable()` for a server not declared in `lsp.lua`

#### Whether to Commit `.lazy.lua`

Commit it if the overrides are project-level decisions all Neovim users should get (e.g., `autoformat = false`). Add to `.gitignore` if they are personal preferences.

---

### 10.16 What Actually Belongs in the Neovim Config

A precise summary of what belongs in `~/dotfiles/nvim/lua/plugins/` and what must stay in project files:

|Setting|Belongs in|
|---|---|
|Line length (88 vs 120)|`pyproject.toml [tool.ruff]`|
|Quote style|`pyproject.toml [tool.ruff.format]` or `.prettierrc`|
|Which lint rules to enable|`pyproject.toml [tool.ruff.lint]`|
|Type checking strictness|`pyrightconfig.json` or `[tool.pyright]`|
|Python virtualenv path|`pyrightconfig.json` `venv` field|
|TypeScript compiler options|`tsconfig.json`|
|Debug launch commands|`.vscode/launch.json`|
|Formatter binary version|`devenv.nix` packages|
|Filetype → formatter binary|`lua/plugins/formatting.lua`|
|Filetype → linter binary|`lua/plugins/linting.lua`|
|Which servers use `$PATH` vs Mason|`lua/plugins/lsp.lua`|
|DAP adapter configuration|`lua/plugins/dap.lua`|

---

### 10.17 Managing LazyVim: The Four Configuration Vectors

When you want to change something about Neovim, reach for these in priority order:

1. **`:LazyExtras`** — first stop; enables language support bundles (keymaps, capabilities, filetype triggers, diagnostic display); check here before writing any Lua
2. **`:Lazy`** — install, update, clean plugins; check plugin status and error messages
3. **`lua/plugins/`** — override or extend plugin configuration; create files here only for things `:LazyExtras` does not cover
4. **`home.nix` packages** — add system-level Neovim dependencies (`gcc`, `tree-sitter`, clipboard provider, Nerd Font)

The order matters: `:LazyExtras` covers most needs without any Lua; `lua/plugins/` files override and extend specific things; `home.nix` handles the binaries that Neovim needs to function.

When you change anything in `:LazyExtras` or `lua/plugins/`, commit the relevant files:

```bash
cd ~/dotfiles
git add nvim/lazyvim.json nvim/lazy-lock.json nvim/lua/plugins/
git commit -m "feat: enable lang.python, add formatting.lua"
git push
```

---

### 10.18 Practical Setup by Language

#### Python

**LazyExtra to enable:** `lang.python`

**`devenv.nix` packages:**

```nix
packages = [
  pkgs.pyright   # LSP
  pkgs.ruff      # formatter + linter
  pkgs.just      # task runner
  # debugpy goes in requirements.txt, NOT here
];
```

**Project config files to create:**

- `.editorconfig` (§10.8)
- `pyproject.toml` with `[tool.ruff]`, `[tool.ruff.format]`, `[tool.ruff.lint]`, `[tool.pyright]` (§10.9, §10.10, §10.11)
- `requirements.txt` with `debugpy>=1.8` (§10.13)
- `.vscode/launch.json` with Python configurations (§10.13)

**Verification:**

```bash
which pyright-langserver    # must show /nix/store/...
which ruff                  # must show /nix/store/...
python3 -c "import debugpy" # must succeed
```

Inside Neovim on a `.py` file:

```vim
:LspInfo          " pyright attached, /nix/store path
:LazyFormatInfo   " ruff + ruff_format, condition: true
```

#### TypeScript

**LazyExtra to enable:** `lang.typescript`

**`devenv.nix` packages:**

```nix
packages = [
  pkgs.nodePackages.typescript-language-server
  pkgs.nodePackages.vscode-langservers-extracted
  pkgs.nodePackages.prettier
  pkgs.just
];
```

**Project config files to create:**

- `.editorconfig`
- `tsconfig.json` (§10.11)
- `.prettierrc` (§10.9)
- `.eslintrc.json` or `eslint.config.js` (§10.10)
- `.vscode/launch.json` with Node.js configurations (§10.13)

**Verification:**

```bash
which typescript-language-server  # must show /nix/store/...
which prettier                    # must show /nix/store/...
```

Inside Neovim on a `.ts` file:

```vim
:LspInfo          " ts_ls and eslint attached
:LazyFormatInfo   " prettier, condition: true
```

#### Lua

**LazyExtra to enable:** `lang.lua`

**Where the binary comes from:** Mason (exception to the devenv rule — `lua_ls` is used to edit the Neovim config itself, which is not inside any devenv project)

**Project config file to create:** `.luarc.json` in the project root:

```json
{
  "$schema": "https://raw.githubusercontent.com/sumneko/vscode-lua/master/setting/schema.json",
  "Lua.runtime.version": "LuaJIT",
  "Lua.workspace.checkThirdParty": false,
  "Lua.diagnostics.globals": ["vim"],
  "Lua.completion.callSnippet": "Replace"
}
```

**`devenv.nix` packages:** none needed — Mason manages `lua_ls`

**Verification:**

```vim
:LspInfo    " lua_ls attached (Mason path is expected here)
```

#### YAML / TOML / JSON

**LazyExtras to enable:** none required — LazyVim includes basic support by default

**Where binaries come from:** Mason manages `yamlls` and `jsonls`

**Project config files:**

YAML schema validation is handled by `yamlls` reading schema annotations. For strict YAML linting, create `.yamllint` (§10.10).

TOML: tamasfe's `even-better-toml` VS Code extension and LazyVim's built-in TOML support handle this. No project config file is needed beyond the TOML files themselves.

JSON: `jsonls` provides schema-aware completion. Add `$schema` keys to JSON files to get project-specific validation.

**Verification:**

```vim
:LspInfo    " yamlls and jsonls attached (Mason paths are expected)
```

---

### 10.19 New Project Setup Checklist

The single ordered reference for setting up a new project's Neovim/tooling configuration. Each step links to the relevant section.

```
□ uv python install 3.14  (v16 only — before direnv allow) (§10.4, §10.9)
□ devenv init && direnv allow                   (§10.3)
□ Create .editorconfig                          (§10.8)
□ Create pyproject.toml with ruff + pyright     (§10.9, §10.10, §10.11)
  (or tsconfig.json + .prettierrc + .eslintrc)
□ Add pyright + ruff to devenv.nix packages     (§10.4, §10.11)
  (or typescript-language-server + prettier)
□ Add debugpy to requirements.txt               (§10.13)
□ Create .vscode/launch.json                    (§10.13)
□ Create .vscode/settings.json                  (§10.5)
□ Create .vscode/extensions.json                (§10.5)
□ Create justfile with setup/fmt/lint/test       (§10.9)
□ just setup  (installs pre-commit hooks)        (§10.9)
□ Verify: which pyright-langserver (→ /nix/store) (§10.11)
□ Verify: :LspInfo in Neovim                    (§10.11)
□ Verify: :LazyFormatInfo in Neovim             (§10.9)
□ Verify: python3 -c "import debugpy"           (§10.13)
□ Verify: yank in Neovim → paste in browser     (§10.12)
□ git add all project config files && commit
```

---

### 10.20 How to Add a New Language

1. Enable the LazyVim extra via `:LazyExtras`
2. Add `mason = false` for the LSP server in `lua/plugins/lsp.lua`
3. Add the LSP binary to `devenv.nix` packages (per project)
4. Create the project config file (`pyrightconfig.json`, `tsconfig.json`, etc.)
5. Verify with `:LspInfo` and `which binary-name`
6. Commit `lazyvim.json`, `lazy-lock.json`, and `lua/plugins/lsp.lua`

---

### 10.21 How to Add a New Plugin

1. Create `~/dotfiles/nvim/lua/plugins/your-plugin.lua` with the `lazy.nvim` spec:

```lua
return {
  "author/plugin-name",
  event = "VeryLazy",
  opts = {},
}
```

2. Run `:Lazy sync` — LazyVim detects the new file and installs the plugin
3. Commit both the new file and the updated `lazy-lock.json`:

```bash
cd ~/dotfiles
git add nvim/lua/plugins/your-plugin.lua nvim/lazy-lock.json
git commit -m "feat: add your-plugin"
git push
```

---

### Part 10 Summary

The central principle of this Part — and the one that carries across the entire stack — is that **tools belong to the project, not the editor**. LSP servers, formatters, and linters are declared in `devenv.nix`, run from `/nix/store`, and are identical for every developer on the project regardless of which editor they use. `mason = false` everywhere is not a limitation; it is the enforcement mechanism for this principle.

The four configuration vectors (LazyVim defaults → `plugins/` overrides → `config/` → `.lazy.lua` escape hatch) form a hierarchy. Work with the defaults as far as possible. Override at `plugins/` for tool integration. Use `.lazy.lua` only for per-project deviations that should not apply everywhere.

The `debugpy` exception (§10.13) is the most important "exception to the rule" in this Part. It cannot go in `devenv.nix packages`. It must be in `requirements.txt`. This is a `debugpy` architectural constraint, not a mistake in the setup.

**What carries forward:** Part 11 covers VS Code as the parallel editor path. It shares the entire project layer (`.editorconfig`, `pyproject.toml`, `devenv.nix`) with Neovim — no duplication, no conflict.

---

## Part 11: VS Code Configuration

> [!note] **What you now know**
> Neovim is configured with LSP, formatting, linting, and debugging for Python and TypeScript. The project-owns-its-config principle is implemented end to end. Part 11 covers VS Code as the parallel editor path.

---

> [!note] **What you will understand by the end of this part**
> - VS Code's role in this stack: a parallel editor path for when Neovim is not the right tool
> - The critical devenv/$PATH problem and why it is the most important VS Code configuration detail
> - How VS Code extensions replace Mason's role and how project-level `.vscode/` config works
> - The side-by-side comparison with Neovim so you can decide which editor to use for each task

VS Code and Neovim coexist in this stack without conflict. The project layer is entirely shared: `.editorconfig`, `pyproject.toml`, `pyrightconfig.json`, `tsconfig.json`, `.vscode/launch.json`, `devenv.nix`, and the CI pipeline are identical for both editors. A developer on either editor picks up the project's rules automatically.

The differences are all on the editor side, and smaller than you might expect.

---

### 11.1 Role in This Stack

VS Code reads `.vscode/launch.json` natively — this is its own format. It reads `.editorconfig`, `pyproject.toml`, `pyrightconfig.json`, and `tsconfig.json` through its extensions, exactly as those tools intend. The `mkhl.direnv` extension activates devenv inside VS Code's process so every extension uses the project-pinned binaries.

Where Neovim needed a global Home Manager plugin file (`formatting.lua`, `linting.lua`) to map filetypes to formatters and linters, VS Code uses `.vscode/settings.json` — a per-project file committed to the repository. This is actually more consistent with the "project owns its configuration" philosophy than the Neovim approach.

---

### 11.2 Installation

VS Code is installed via the official apt repository by `setup-desktop.sh` (Installation Step 5). The snap package is explicitly not used — the VS Code snap runs in a sandboxed filesystem that cannot access paths under `/nix/store`, which breaks the `mkhl.direnv` extension and prevents devenv binaries from being found.

Verify:

```bash
code --version
```

If `code` is not found after the bootstrap, the PATH may not include the apt-installed VS Code yet. Open a new shell and retry. If still not found, verify the apt repository was added:

```bash
apt list --installed 2>/dev/null | grep code
```

---

### 11.3 Extensions: What to Install and Why

Extensions are not installed automatically — `code --install-extension` requires a running display and fails when called from a setup script without one. Install them manually after the desktop is up (Installation Step 6):

```bash
grep -v '^#\|^$' ~/dotfiles/vscode/extensions.txt | xargs -I{} code --install-extension {}
```

Populate `~/dotfiles/vscode/extensions.txt` with the following (one extension ID per line, `#` comments are ignored):

```
ms-python.python            Python language support, Pylance LSP, debugger
charliermarsh.ruff          Ruff linter and formatter (replaces separate flake8 + black extensions)
ms-python.debugpy           Python DAP debugging adapter
mkhl.direnv                 devenv environment activation — critical (see §11.6)
ms-azuretools.vscode-docker Docker Compose integration, container management
eamodio.gitlens             Enhanced git history, inline blame, PR view
redhat.vscode-yaml          YAML with JSON schema validation
tamasfe.even-better-toml    TOML syntax and validation
esbenp.prettier-vscode      Prettier formatter for JS/TS/JSON/YAML/Markdown
dbaeumer.vscode-eslint      ESLint linter integration
```

**How extensions replace Mason:** in Neovim, `:Mason` downloads and manages tool binaries. In VS Code, extensions either bundle the tools directly or manage them. You do not use a `:Mason`-equivalent in VS Code. The extension handles binary management internally:

|Tool|VS Code Extension|
|---|---|
|Ruff (lint + format)|`charliermarsh.ruff`|
|Pyright (Python LSP)|`ms-python.python` (bundles Pylance/Pyright)|
|Prettier|`esbenp.prettier-vscode`|
|ESLint|`dbaeumer.vscode-eslint`|
|TypeScript LSP|Built into VS Code — no extension needed|
|Biome|`biomejs.biome` (if your project uses Biome)|
|direnv integration|`mkhl.direnv`|

> [!important] `mkhl.direnv` is not optional This extension is what connects devenv to VS Code. Without it, every other extension uses the system `$PATH` rather than devenv's project-pinned binaries. The `charliermarsh.ruff` extension would find Home Manager's global `ruff` instead of the project's pinned version. `ms-python.python` would fail to find the virtualenv's Python. Install it and add it to `.vscode/extensions.json` in every project that uses devenv.

---

### 11.4 How Extensions Replace Mason

The Neovim side of this stack used `mason = false` in `lsp.lua` to tell LazyVim to find binaries on `$PATH` rather than in Mason's directory. VS Code extensions handle this differently: they expose a binary path setting that VS Code's direnv extension populates by activating the devenv environment.

The flow when `mkhl.direnv` is installed and active:

```
VS Code opens a file in the project
        ↓
mkhl.direnv reads .envrc → activates devenv shell inside VS Code
        ↓
$PATH = /nix/store/abc-ruff/bin
      : /nix/store/def-pyright/bin
      : ... (devenv's pinned binaries)
        ↓
charliermarsh.ruff finds /nix/store/abc-ruff/bin/ruff    ✓
ms-python.python finds /nix/store/def-pyright/bin/pyright ✓
esbenp.prettier-vscode finds /nix/store/.../prettier       ✓
```

Without `mkhl.direnv`, VS Code extensions search the system `$PATH` — finding Home Manager's global versions, not the project-pinned ones.

---

### 11.5 Project-Level VS Code Configuration

Three files live in `.vscode/` at the project root and are committed to the repository. Together they ensure every VS Code developer on the team gets format-on-save, linting, and extension recommendations without any manual configuration.

#### `.vscode/settings.json` — The VS Code Equivalent of `formatting.lua` and `linting.lua`

This is the most important VS Code project file. Where Neovim used global `formatting.lua` and `linting.lua` in the Home Manager config, VS Code uses this per-project file. The key difference: `.vscode/settings.json` is committed to the repository, making it genuinely per-project rather than per-machine.

```jsonc
// .vscode/settings.json
// Committed to the repository — applies to all VS Code users on this project.
// This file is the VS Code equivalent of formatting.lua + linting.lua.

{
  // ── Python interpreter ─────────────────────────────────────────────────────
  // Point VS Code at the virtualenv created by devenv.
  // devenv.nix: languages.python.venv.enable = true creates .venv/
  // If this path does not exist, run `devenv update` to activate the environment.
  "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",

  // ── Global format on save ─────────────────────────────────────────────────
  // Enables format-on-save for all filetypes that have a formatter configured.
  // Overridden per-language below where needed.
  "editor.formatOnSave": true,

  // ── Python: ruff handles both formatting and linting ──────────────────────
  // The ruff extension reads rules from pyproject.toml [tool.ruff] and
  // [tool.ruff.lint] automatically — this just activates it.
  "[python]": {
    // Use the Ruff extension for formatting (replaces black, isort separately)
    "editor.defaultFormatter": "charliermarsh.ruff",
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
      // Run ruff's auto-fixable lint rules (import sorting, unused imports, etc.)
      "source.fixAll.ruff": "explicit",
      // Sort imports on save — equivalent to running isort
      "source.organizeImports.ruff": "explicit"
    }
  },

  // ── JavaScript and TypeScript: prettier ───────────────────────────────────
  // Prettier reads rules from .prettierrc in the project root.
  "[javascript]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[typescript]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[javascriptreact]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[typescriptreact]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },

  // ── Web assets: prettier ──────────────────────────────────────────────────
  "[html]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[css]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[json]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[yaml]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },
  "[markdown]": { "editor.defaultFormatter": "esbenp.prettier-vscode" },

  // ── Prettier condition gate ────────────────────────────────────────────────
  // The VS Code equivalent of conform.nvim's condition gate.
  // Prevents prettier from running on JS/TS files in projects that have
  // no .prettierrc config — mirrors the condition function in formatting.lua.
  "prettier.requireConfig": true,

  // ── Ruff linter activation ────────────────────────────────────────────────
  "ruff.lint.enable": true,

  // ── ESLint linter activation ──────────────────────────────────────────────
  // Reads rules from .eslintrc.json or eslint.config.js in the project root.
  "eslint.enable": true,

  // ── Python type checking mode ──────────────────────────────────────────────
  // This can also be set in pyrightconfig.json — either location works.
  // If both are set, pyrightconfig.json wins.
  // Options: "off" | "basic" | "standard" | "strict"
  "python.analysis.typeCheckingMode": "basic",

  // ── Python analysis paths ──────────────────────────────────────────────────
  // Helps Pyright resolve imports for ERPNext/Frappe projects.
  // Adjust paths to match your project's app structure.
  "python.analysis.extraPaths": [
    "${workspaceFolder}"
  ],

  // ── Editor: trailing whitespace and final newlines ─────────────────────────
  // These mirror what .editorconfig sets — belt-and-suspenders for VS Code.
  "files.trimTrailingWhitespace": true,
  "files.insertFinalNewline": true,

  // ── Files to exclude from the explorer and search ─────────────────────────
  "files.exclude": {
    "**/__pycache__": true,
    "**/.venv": true,
    "**/node_modules": true,
    "**/.devenv": true,
    "**/dist": true
  },
  "search.exclude": {
    "**/__pycache__": true,
    "**/.venv": true,
    "**/node_modules": true,
    "**/.devenv": true
  }
}
```

**Verification:** open VS Code in the project, open the Output panel (`View → Output`), select `Ruff` from the dropdown. The output should show the binary path being used — it must show a `/nix/store/...` path. If it shows a system path, `mkhl.direnv` is not active or `direnv allow` has not been run.

#### `.vscode/extensions.json` — Recommended Extensions

This file causes VS Code to prompt new contributors to install the correct extensions when they open the project. No manual installation needed:

```json
// .vscode/extensions.json
// VS Code prompts: "This workspace has extension recommendations. Install them?"
{
  "recommendations": [
    "charliermarsh.ruff",
    "ms-python.python",
    "ms-python.debugpy",
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "mkhl.direnv",
    "ms-azuretools.vscode-docker",
    "redhat.vscode-yaml",
    "tamasfe.even-better-toml"
  ]
}
```

The new VS Code developer onboarding flow once this file is committed:

```bash
git clone https://github.com/org/project.git
cd project
direnv allow      # activates devenv environment
just setup        # installs pre-commit hooks
code .            # VS Code opens, prompts to install recommended extensions → Yes
```

Four commands, fully configured editor with project-pinned tools.

#### `.vscode/launch.json` — Debug Configurations

This is VS Code's native debug configuration format. It is covered in full in §11.13, where the same file is read by both VS Code (natively) and Neovim's `nvim-dap` (via `load_launchjs()`). No additional setup is needed for VS Code beyond what was already created in §11.13.

---

### 11.6 The Devenv / `$PATH` Problem — The Most Important VS Code Configuration Detail

This section deserves its own treatment because the failure mode is silent and easy to miss.

**The problem:** VS Code does not inherit the shell's `$PATH` when launched from a GUI launcher (application menu, dock, file manager). When you double-click VS Code or launch it from Spotlight, it opens with a minimal system `$PATH` that contains no devenv binaries.

**Without `mkhl.direnv`:**

```
VS Code opens (launched from GUI)
        ↓
Extensions search $PATH for ruff, pyright, prettier
$PATH = /usr/bin:/usr/local/bin ...  ← system PATH only
        ↓
Extensions either fail to find tools
or find Home Manager's global versions (wrong pinned version)
        ↓
Formatting and linting "work" but use the wrong binary versions
Type checking may fail if pyright cannot find the project virtualenv
```

**With `mkhl.direnv` installed:**

```
VS Code opens any file in the project
        ↓
mkhl.direnv detects .envrc in the project root
        ↓
devenv environment activates inside VS Code's process
$PATH = /nix/store/abc-ruff-0.4.1/bin : ...  ← project's pinned tools
        ↓
All extensions use devenv's binaries ✓
```

**The two requirements for this to work:**

1. `mkhl.direnv` is installed (bootstrap installs it via `vscode/extensions.txt`)
2. `direnv allow` has been run in the project directory (once per developer per repo)

**Verification:**

```
View → Output → select "Ruff" from the dropdown
```

The binary path shown must start with `/nix/store/`. If it shows `/home/yourusername/.nix-profile/bin/ruff` (Home Manager's global version) instead, `mkhl.direnv` is not activating. Check:

```bash
# Confirm direnv allow has been run
direnv status

# If status shows "Found .envrc" but "not loaded", run:
direnv allow
```

Then reload the VS Code window (`Ctrl+Shift+P` → "Developer: Reload Window").

---

### 11.7 `.neoconf.json` Has No VS Code Equivalent — And Needs None

`.neoconf.json` exists because Neovim's LSP configuration is programmatic (Lua) with no JSON-based project config mechanism. VS Code extensions read their settings directly from `.vscode/settings.json` — there is no gap to bridge. Settings that go in `.neoconf.json` for Neovim either go into `.vscode/settings.json` for VS Code, or better, into native tool config files (`pyrightconfig.json`, `tsconfig.json`) where both editors read them automatically.

---

### 11.8 `.lazy.lua` Has No VS Code Equivalent — And None Is Needed

`.lazy.lua` exists because Neovim's plugin system is programmatic and global, requiring a per-project Lua escape hatch for overrides. VS Code's per-project configuration _is_ `.vscode/settings.json` — it is the primary mechanism, not a last resort. Every override you would put in `.lazy.lua` either belongs in `.vscode/settings.json` or was already in a project config file.

---

### 11.9 Side-by-Side Comparison: Neovim vs. VS Code

The full equivalence table covering every category where the two editors differ in implementation while sharing the same project-level files.

|Concern|Neovim (Home Manager global config)|VS Code|
|---|---|---|
|**Format on save**|`conform.nvim` in `lua/plugins/formatting.lua` — global, per-machine|`.vscode/settings.json` `"editor.formatOnSave": true` — committed to repo|
|**Lint on save**|`nvim-lint` in `lua/plugins/linting.lua` — global, per-machine|`.vscode/settings.json` `"ruff.lint.enable": true` + extension|
|**Condition gate**|`condition` function in `formatters` block (conform.nvim) and linter object patch (nvim-lint)|`"prettier.requireConfig": true` and equivalent extension settings|
|**Formatter rules**|`pyproject.toml`, `.prettierrc`, `stylua.toml` — project files, editor-agnostic|Same — identical|
|**Linter rules**|`pyproject.toml [tool.ruff.lint]`, `.eslintrc.json`, `.yamllint` — project files|Same — identical|
|**LSP server rules**|`pyrightconfig.json` / `pyproject.toml [tool.pyright]` / `tsconfig.json` — project files|Same — identical|
|**LSP editor settings**|`.neoconf.json` in project root|`.vscode/settings.json` language-specific keys|
|**Binary installation**|Mason (global, version-insensitive servers) + devenv (per project, `mason = false`)|Extensions bundle tools + devenv provides pinned versions|
|**devenv / `$PATH`**|Automatic — Neovim inherits shell `$PATH` when launched from terminal|Requires `mkhl.direnv` extension; breaks silently if not installed|
|**Debug configs**|`.vscode/launch.json` read via `require("dap.ext.vscode").load_launchjs()`|`.vscode/launch.json` — native format|
|**Per-project overrides**|`.lazy.lua` — last resort, requires trust approval per developer|`.vscode/settings.json` — primary mechanism, committed to repo|
|**Recommended extensions**|`:LazyExtras` (global, per-machine, interactive)|`.vscode/extensions.json` (committed to repo, prompts automatically)|
|**pre-commit / CI**|Identical — editor-agnostic|Identical — editor-agnostic|

**The pattern across every row:** project-level concerns (rules, configs, launch configs) are identical between editors. Editor-side concerns (how to activate a formatter, where to find the binary, how to enable a linter) differ in mechanism but produce the same result when the project is configured correctly.

---

### 11.10 How to Change or Add VS Code Settings

**Project-level settings (shared with the whole team):**

Edit `.vscode/settings.json`, commit, push. Every VS Code developer on the team gets the change on their next `git pull`.

```bash
nvim .vscode/settings.json
# Make changes
git add .vscode/settings.json
git commit -m "chore: enable eslint for this project"
git push
```

**User-level settings (personal, not committed):**

`Ctrl+Shift+P` → "Open User Settings (JSON)". These apply to all projects on your machine and are not version-controlled.

**Adding a new extension to project recommendations:**

Add the extension ID to `.vscode/extensions.json` `recommendations` array and commit. The next time a teammate opens the project in VS Code, they will be prompted to install it.

**Adding a new extension to your list:**

Add the extension ID to `~/dotfiles/vscode/extensions.txt`, install it, then commit:

```bash
echo "new-publisher.new-extension" >> ~/dotfiles/vscode/extensions.txt
code --install-extension new-publisher.new-extension
git -C ~/dotfiles add vscode/extensions.txt
git -C ~/dotfiles commit -m "feat: add new-extension to VS Code list"
git -C ~/dotfiles push
```

---

### Part 11 Summary

VS Code and Neovim share the entire project layer — `.editorconfig`, `pyproject.toml`, `pyrightconfig.json`, `devenv.nix`, and `.vscode/launch.json` are identical for both editors. There is no duplication and no conflict. A teammate on either editor picks up the same formatting rules, the same LSP config, and the same debug launch configuration automatically.

The devenv / `$PATH` problem (§11.6) is the single most important VS Code configuration detail. Without the `mkhl.direnv` extension activating first, every other extension (`pylance`, `eslint`, the debugger) uses system binaries instead of the project's pinned versions. Verify with `which python` from the VS Code integrated terminal — it must resolve to a `/nix/store/...` path, not `/usr/bin/python`.

VS Code extensions are not managed by Home Manager. After a fresh bootstrap, install them with the one-liner from `~/dotfiles/vscode/extensions.txt`. Note the command in `home.nix` as a reminder.

---

## Appendices

---

## Appendix A: Bootstrap Script (Complete)

Save this file as `bootstrap.sh` in the root of your **public** `workstation-scripts` repository. The script is idempotent — safe to re-run if it stops partway through.

> [!important] Two substitutions required before pushing. Set `GITHUB_USER` to your GitHub username and `DOTFILES_REPO` to the SSH URL of your private dotfiles repository. These are the only two personal values in the script — everything else is generic.

```bash
#!/usr/bin/env bash
# bootstrap.sh
# Idempotent workstation setup script.
# Lives in: workstation-scripts/ (PUBLIC repo) – fetched via wget
# Run with: wget -qO bootstrap.sh https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh && bash bootstrap.sh
#
# What this script does (headless-safe — no display required):
#   1.  Installs system dependencies and sets zsh as the login shell
#   2.  Verifies the SSH key is present and authenticated with GitHub
#   3.  Clones your PRIVATE dotfiles repo via SSH
#   4.  Installs Nix (Determinate Systems installer)
#   5.  Applies Home Manager from your flake (owns git config, tmux plugins,
#         Nerd Font, and all CLI packages declared in home.nix)
#   6.  Installs Docker Engine
#   7.  Verifies GitHub CLI (installed by Home Manager; apt fallback)
#   8.  Configures gh pager (delta – not manageable via Home Manager)
#   9.  Installs Gemini CLI + Conductor + Context7 MCP
#   10. Symlinks user-managed dotfiles (sessionizer)
#   11. Stages LazyVim starter into dotfiles
#   12. Runs LazyVim headless plugin sync
#
# GUI-only tools (WezTerm, VS Code, Chrome, ksnip) are installed by setup-desktop.sh.
# Run setup-desktop.sh after this script if you want a graphical environment.
#
# NOTE: git identity, delta pager, aliases, tmux plugins, and JetBrainsMono
# Nerd Font are managed entirely by Home Manager via home.nix. The bootstrap
# script does NOT write any git config or install fonts/tmux plugins manually.
#
# PREREQUISITE: Generate and register your SSH key on GitHub before running
# this script. The bootstrap runs fully automatically with no pauses once the
# key is in place.

set -euo pipefail

# Cache sudo credentials up front so subsequent sudo calls don't need a TTY.
sudo -v

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "${GREEN}▶ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $1${NC}"; }
ok()    { echo -e "${GREEN}✓ $1${NC}"; }

# ── Variables — substitute these two values before pushing ───────────────────
GITHUB_USER="yourusername"                                  # ← your GitHub username
DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"   # ← your PRIVATE dotfiles SSH URL
DOTFILES_DIR="$HOME/dotfiles"

echo -e "${GREEN}🚀 Starting workstation bootstrap...${NC}"

# ── Pre-flight: create user-owned XDG directories ────────────────────────────
# Must run before any sudo call. Some sudo-invoked tools (apt, gpg) implicitly
# create ~/.config/ owned by root, which causes "Permission denied" errors in
# any later user-space write to that tree.
step "Pre-creating user-owned directories"
mkdir -p \
    "$HOME/.config/git" \
    "$HOME/.config/tmux" \
    "$HOME/.local/bin" \
    "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ok "User directories ready"

# ── Step 1: System dependencies ──────────────────────────────────────────────
step "Installing system dependencies (git, curl, openssh-client, zsh)"
sudo apt-get update -qq
sudo apt-get install -y git curl openssh-client zsh
ok "System dependencies installed"

# ── Step 2: Set zsh as login shell ───────────────────────────────────────────
step "Setting zsh as login shell"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    sudo usermod -s /usr/bin/zsh "$USER"
    ok "Login shell changed to zsh (takes effect on next login)"
else
    ok "Login shell already set to zsh – skipping"
fi

# ── Step 2: Verify SSH key ────────────────────────────────────────────────────
# The key must exist and be registered on GitHub before this script is run.
step "Verifying SSH key for GitHub"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo -e "${RED}✗ SSH key not found at ~/.ssh/id_ed25519${NC}"
    echo ""
    echo "Generate and register an SSH key before running bootstrap:"
    echo "  ssh-keygen -t ed25519 -C \"${GITHUB_USER}@workstation\" -f ~/.ssh/id_ed25519 -N \"\""
    echo "  cat ~/.ssh/id_ed25519.pub"
    echo "Paste the key at https://github.com/settings/keys, then verify:"
    echo "  ssh-keyscan github.com >> ~/.ssh/known_hosts"
    echo "  ssh -T git@github.com"
    exit 1
fi

# Pre-seed known_hosts so ssh never prompts interactively (idempotent).
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

# ssh -T always exits 1 (GitHub denies shell access); capture stderr too.
SSH_OUTPUT=$(ssh -T git@github.com 2>&1 || true)
if ! echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
    echo -e "${RED}✗ SSH authentication to GitHub failed${NC}"
    echo ""
    echo "Ensure your public key is registered at https://github.com/settings/keys"
    echo "then verify with: ssh -T git@github.com"
    exit 1
fi
ok "SSH key verified – GitHub authentication successful"

# ── Step 3: Clone dotfiles ────────────────────────────────────────────────────
step "Cloning private dotfiles repository"
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    ok "Dotfiles cloned to $DOTFILES_DIR"
else
    git -C "$DOTFILES_DIR" fetch origin main
    git -C "$DOTFILES_DIR" reset --hard origin/main
    ok "Dotfiles already present – reset to origin/main"
fi
cd "$DOTFILES_DIR"

# ── Step 4: Install Nix (Determinate Systems) ────────────────────────────────
step "Installing Nix"
if ! command -v nix &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf -L \
        https://install.determinate.systems/nix \
        | sh -s -- install --no-confirm
    # Source Nix profile for the remainder of this script session.
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        # shellcheck disable=SC1091
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    ok "Nix installed"
else
    ok "Nix already installed – skipping"
fi

# ── Step 5: Apply Home Manager via Flake ──────────────────────────────────────
# Home Manager owns: git identity, delta config, git aliases, zsh, starship,
# direnv, fzf, tmux plugins, JetBrainsMono Nerd Font, and all CLI packages
# declared in home.nix. Do NOT write git config anywhere else in this script.
step "Applying Home Manager configuration"
# Fully qualified GitHub URI bypasses local registry lookup failures on fresh
# machines that have not yet populated the Nix registry.
nix run github:nix-community/home-manager -- \
    switch --flake "$DOTFILES_DIR#${GITHUB_USER}"
ok "Home Manager applied"

# Verify that Home Manager actually succeeded by checking for a key binary.
if ! command -v zsh &>/dev/null && [ ! -x "$HOME/.nix-profile/bin/zsh" ]; then
    warn "zsh not found after Home Manager apply – HM may have failed"
    warn "Re-run manually: nix run github:nix-community/home-manager -- switch --flake $DOTFILES_DIR#${GITHUB_USER}"
fi

# Source the new profile so subsequent steps find HM-installed binaries.
# shellcheck disable=SC1090
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
else
    warn "Nix profile script not found – HM-installed binaries may not be on PATH"
    warn "Expected: $HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# ── Step 6: Install Docker Engine ────────────────────────────────────────────
step "Installing Docker Engine"
if ! command -v docker &>/dev/null; then
    sudo apt-get install -y ca-certificates gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    ok "Docker Engine installed"
else
    ok "Docker already installed – skipping"
fi

# ── Step 7: Verify GitHub CLI ─────────────────────────────────────────────────
# gh is declared in home.nix packages; apt is a fallback for first-run timing
# issues where HM hasn't sourced yet.
step "Verifying GitHub CLI"
if ! command -v gh &>/dev/null && [ ! -f "$HOME/.nix-profile/bin/gh" ]; then
    warn "gh not found – installing via apt as fallback"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y gh
fi
ok "GitHub CLI available"

# ── Step 8: Configure gh pager ───────────────────────────────────────────────
# git pager (delta) is managed by Home Manager via programs.git.settings.
# The gh pager is a separate setting not exposed by Home Manager – set it here.
step "Configuring gh pager"
GH_BIN="${HOME}/.nix-profile/bin/gh"
DELTA_BIN="${HOME}/.nix-profile/bin/delta"
if [ -x "$GH_BIN" ] && [ -x "$DELTA_BIN" ]; then
    "$GH_BIN" config set pager "$DELTA_BIN" 2>/dev/null || true
    ok "gh pager set to delta"
else
    ok "gh or delta not in Nix profile yet – skipping gh pager config"
fi

# ── Step 9: Install Gemini CLI + extensions ──────────────────────────────────
step "Installing Gemini CLI and extensions"
if ! command -v gemini &>/dev/null; then
    NPM_BIN="${HOME}/.nix-profile/bin/npm"
    if [ -x "$NPM_BIN" ]; then
        # Install to ~/.local so npm doesn't write into the read-only /nix/store.
        NPM_PREFIX="$HOME/.local"
        "$NPM_BIN" install -g --prefix "$NPM_PREFIX" @google/gemini-cli
        export PATH="$NPM_PREFIX/bin:$PATH"
        if command -v gemini &>/dev/null; then
            if gemini extension install conductor; then
                ok "Gemini Conductor extension installed"
            else
                warn "Gemini Conductor extension install failed – install manually later"
            fi
            if gemini mcp install context7; then
                ok "Gemini Context7 MCP installed"
            else
                warn "Gemini Context7 MCP install failed – install manually later"
            fi
        fi
        ok "Gemini CLI installed"
    else
        warn "npm not found – skipping Gemini CLI install"
        warn "Ensure pkgs.nodejs_22 is in home.nix packages and re-run bootstrap"
    fi
else
    ok "Gemini CLI already installed – skipping"
fi

# ── Step 10: Symlink user-managed dotfiles ───────────────────────────────────
# sessionizer is a custom script not managed by Home Manager.
# tmux.conf is generated by Home Manager (programs.tmux.extraConfig) — no symlink needed.
# wezterm.lua is symlinked by setup-desktop.sh (WezTerm is desktop-only).
step "Symlinking user-managed dotfiles"
if [ -f "$DOTFILES_DIR/scripts/sessionizer" ]; then
    chmod +x "$DOTFILES_DIR/scripts/sessionizer"
    ln -sf "$DOTFILES_DIR/scripts/sessionizer" "$HOME/.local/bin/sessionizer"
    ok "sessionizer symlinked to ~/.local/bin/sessionizer"
else
    warn "scripts/sessionizer not found in dotfiles – symlink skipped"
    warn "Add scripts/sessionizer to your dotfiles repo and re-run bootstrap, or symlink manually"
fi
ok "Dotfile symlinks complete (tmux managed by HM, wezterm by setup-desktop.sh)"

# ── Step 11: Stage LazyVim starter into dotfiles ─────────────────────────────
step "Staging LazyVim starter"
NVIM_DIR="$DOTFILES_DIR/nvim"
if [ ! -s "$NVIM_DIR/init.lua" ]; then
    git clone --depth 1 https://github.com/LazyVim/starter /tmp/lazyvim-starter
    mkdir -p "$NVIM_DIR"
    cp -r /tmp/lazyvim-starter/. "$NVIM_DIR/"
    rm -rf "$NVIM_DIR/.git" /tmp/lazyvim-starter
    ok "LazyVim starter staged into dotfiles/nvim/"
else
    ok "LazyVim already staged – skipping"
fi

# ── Step 12: Run LazyVim headless plugin sync ────────────────────────────────
step "Running LazyVim headless plugin sync"
NVIM_BIN="${HOME}/.nix-profile/bin/nvim"
if [ -x "$NVIM_BIN" ]; then
    LAZY_LOG="$(mktemp /tmp/lazyvim-sync.XXXXXX.log)"
    if timeout 300 "$NVIM_BIN" --headless "+Lazy! sync" +qa >"$LAZY_LOG" 2>&1; then
        ok "LazyVim plugins synced headlessly"
    else
        warn "LazyVim headless sync exited non-zero or timed out after 300s"
        warn "Log saved to: $LAZY_LOG"
        warn "Run ':Lazy sync' manually on first Neovim open"
    fi
else
    warn "Neovim not found in Nix profile – skipping headless sync"
    warn "Run ':Lazy sync' manually on first Neovim open"
fi

# ── Complete ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}✔ Bootstrap complete!${NC}"
echo ""
echo -e "${YELLOW}Manual steps required before first use:${NC}"
echo "  1. Log out and back in (activates Docker group membership and zsh)"
echo "  2. gh auth login   (requires browser OAuth)"
echo "  3. gemini auth login (requires browser OAuth)"
echo "  4. Verify SSH remote: cd ~/dotfiles && git remote -v"
echo "     (should show: git@github.com:${GITHUB_USER}/dotfiles.git)"
echo ""
echo "Back up your SSH private key to a secure location:"
echo "  ~/.ssh/id_ed25519  (cannot be regenerated from dotfiles)"
echo ""
echo "Then verify the installation with the checklist in §2.6"
```

---

## Appendix B: `flake.nix` and `home.nix` Reference

Complete working implementations. Substitute `yourusername` with the output of `whoami` before saving.

```bash
# Find your exact username
whoami
```

### `flake.nix`

```nix
# dotfiles/flake.nix
{
  description = "Workstation Home Manager Flake";

  inputs = {
    # nixos-unstable is the default here because devenv's own nixpkgs input
    # also tracks unstable, and using the same channel avoids version skew
    # between Home Manager packages and devenv packages. If you need stricter
    # stability guarantees, switch to a pinned release channel (e.g.
    # "github:nixos/nixpkgs/nixos-24.11") and update devenv's nixpkgs input
    # to match — mismatched channels can cause binary cache misses.
    # nixos-unstable gives newer packages; pinned channels give more stability.
    #
    # To pin a specific nixpkgs commit (maximum reproducibility):
    #   1. Find a green "passing" commit at https://status.nixos.org
    #   2. Copy its full commit SHA
    #   3. Set: nixpkgs.url = "github:nixos/nixpkgs/<commit-sha>";
    #
    # The current value (nixos-unstable) is a good default for most workstations.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      # Use the same nixpkgs as above to avoid version conflicts
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }: {
    homeConfigurations."yourusername" =                 # ← substitute username
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;    # ← change arch if needed
        modules = [ ./home.nix ];
      };
  };
}
```

### `home.nix`

```nix
# dotfiles/home.nix
{ config, pkgs, ... }:

{
  # ── Identity ────────────────────────────────────────────────────────────────
  home.username = "yourusername";                      # ← substitute username
  home.homeDirectory = "/home/yourusername";           # ← substitute username

  # ── Packages: global CLI tools ──────────────────────────────────────────────
  # These are available in every shell, regardless of project.
  # Rule: if a tool's version doesn't matter per project, it goes here.
  # Rule: if a tool's version matters per project, it goes in devenv.nix.
  home.packages = with pkgs; [
    # ── Git and GitHub tooling ───
    git
    gh          # GitHub CLI
    lazygit     # Visual git TUI
    delta       # Syntax-highlighted diff viewer

    # ── Shell utilities ──────────
    fzf         # Fuzzy finder (required by sessionizer)
    zoxide      # Smart directory jumper
    bat         # cat with syntax highlighting
    eza         # Modern ls replacement
    ripgrep     # Fast recursive grep (rg)
    fd          # Fast find replacement
    just        # Task runner — global fallback for use outside any devenv project; devenv.nix pins the version per project
    jq          # JSON processor

    # ── Neovim and dependencies ──
    neovim
    tree-sitter # Required by nvim-treesitter
    gcc         # C compiler for treesitter parser compilation

    # ── Clipboard providers ──────
    # xclip for X11, wl-clipboard for Wayland.
    # Both are included; each is a no-op on the wrong display server.
    xclip
    wl-clipboard

    # ── Shell and terminal ───────
    zsh
    tmux
    starship    # Cross-shell prompt

    # ── Python package manager ───
    uv          # Fast Python package manager

    # ── Node.js for Gemini CLI ───
    # Provides npm for the bootstrap's Gemini CLI install step (bootstrap §10).
    # This is the GLOBAL Node.js — available in all shells, not project-specific.
    # It intentionally stays at nodejs_22 (current LTS) since Gemini CLI has no strict
    # Node version requirement and this avoids storing two identical Node binaries
    # in /nix/store.
    #
    # Project Node.js for ERPNext v16 is declared separately in devenv.nix as
    # pkgs.nodejs_24 — that version is per-project and activated only inside the
    # project directory via direnv. The two versions coexist without conflict
    # because devenv prepends to $PATH, shadowing this global version inside
    # any project that declares its own.
    nodejs_22

    # ── Devenv ───────────────────
    devenv      # Per-project Nix environments

    # ── Nix utilities ────────────
    nixpkgs-fmt # Nix file formatter

    # ── Fonts ────────────────────
    # Pinned via flake.lock; replaces the manual curl/unzip step.
    nerd-fonts.jetbrains-mono
  ];

  # ── Default editor ──────────────────────────────────────────────────────────
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  # ── Neovim config: mutable symlink outside /nix/store ──────────────────────
  # LazyVim writes lazy-lock.json at runtime — it needs a mutable directory.
  # mkOutOfStoreSymlink creates ~/.config/nvim → ~/dotfiles/nvim directly,
  # bypassing the read-only /nix/store.
  home.file.".config/nvim".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/nvim";

  # ── Shell: zsh ──────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;

    # Shell initialisation — ORDER MATTERS (see §11.4)
    initContent = ''
      # 1. PATH additions first — binaries below need to be findable
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.nix-profile/bin:$PATH"

      # 2. Nix environment
      . "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true

      # 3. direnv hook — MUST be early (tmux fires before .zshrc finishes)
      eval "$(direnv hook zsh)"

      # 4. cd alias — MUST come before zoxide init (see §11.4 rule 4)
      # Remove this line if you prefer to invoke zoxide as `z` directly.
      alias cd='z'

      # 5. zoxide — after the cd alias
      eval "$(zoxide init zsh)"

      # 6. fzf options
      # Shell key bindings (Ctrl-R, Ctrl-T, Alt-C) are sourced automatically by
      # Home Manager via programs.fzf.enableZshIntegration = true — do not add
      # a manual `source ~/.fzf.zsh` line here; it is redundant and may not
      # exist when fzf is installed via Nix rather than the fzf install script.
      export FZF_DEFAULT_OPTS="
        --height 40%
        --layout=reverse
        --border
        --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8
        --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc
        --color=marker:#f5e0dc,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8"

      # 7. Starship — MUST be last (wraps PS1; anything after breaks the prompt)
      eval "$(starship init zsh)"

      # 8. Remaining aliases — after all tool inits
      alias ls='eza --color=auto --icons'
      alias cat='bat'
      # hms: home-manager with flake path baked in.
      # With flakes, home-manager always needs --flake; this alias makes it ergonomic.
      alias hms='home-manager switch --flake ~/dotfiles#yourusername'  # ← substitute username

      # ── Shell utility functions (§11.4) ────────────────────────
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

      gpr() {
        local pr
        pr=$(
          gh pr list \
            --json number,title,author,headRefName \
            --template '{{range .}}{{tablerow .number .title .author.login .headRefName}}{{end}}' \
          | fzf \
            --prompt="  checkout PR: " \
            --pointer="▶" \
            --preview="gh pr view {1}" \
            --preview-window=right:60%:wrap \
            --border=rounded \
            --height=60% \
          | awk '{print $1}'
        )
        [ -n "$pr" ] && gh pr checkout "$pr"
      }

      poi() {
        echo "Fetching merged branches..."
        git fetch --prune
        git branch --merged main \
          | grep -vE '^\*|main|master|develop' \
          | xargs -r git branch -d
        echo "Done. Remaining local branches:"
        git branch
      }
    '';
  };

  # ── direnv: nix-direnv for fast devenv activation ──────────────────────────
  programs.direnv = {
    enable = true;
    # enableZshIntegration is intentionally false here.
    # When true, Home Manager appends `eval "$(direnv hook zsh)"` at the END
    # of .zshrc — but direnv must be initialised EARLY (position 3 in initContent)
    # so that tmux pane shells have it active before the initial window command
    # fires. The hook is added manually at the correct position in initContent above.
    # Setting this to true would produce a duplicate hook at the wrong position.
    enableZshIntegration = false;
    nix-direnv.enable = true;
  };

  # ── fzf: shell integration ──────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # ── tmux: declarative plugin management ─────────────────────────────────────
  # Plugins are pinned via flake.lock — replaces TPM (tmux-plugins/tpm).
  # extraConfig inlines tmux/tmux.conf; HM appends plugin run-shell lines after it.
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      catppuccin
      vim-tmux-navigator
      yank
    ];
    extraConfig = builtins.readFile ../tmux/tmux.conf;
  };

  # ── git: global config ──────────────────────────────────────────────────────
  # !! EDIT user.name and user.email before running the bootstrap !!
  programs.git = {
    enable = true;
    # user.name and user.email are declared here — bootstrap does NOT write git config
    settings = {
      user = {
        name  = "Your Name";               # ← your full name (e.g. "Jane Smith")
        email = "you@example.com";         # ← email registered on your GitHub account
      };
      init.defaultBranch = "main";
      core.pager    = "delta";
      delta = {
        side-by-side  = true;
        line-numbers  = true;
        navigate      = true;
      };
      alias = {
        sw    = "switch";
        co    = "checkout -b";
        st    = "status --short";
        pushf = "push --force-with-lease";
        lg    = "log --oneline --graph --decorate --all";
      };
      # Silence the "no signing format" warning emitted by newer Home Manager
      signing.format = null;
    };
  };

  # ── Starship prompt ─────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    # Minimal config — customize further to taste
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol   = "[❯](bold red)";
      };
    };
  };

  # ── State version ───────────────────────────────────────────────────────────
  # Do not change this after initial setup — it controls state migration behaviour
  home.stateVersion = "24.05";
}
```

---

## Appendix C: Example `devenv.nix`

Complete ERPNext v15/v16 development environment. Copy to your project root and run `direnv allow`. For a field-by-field explanation of every block, see **§11.4**.

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
    # (servers run in Docker Compose — see Appendix D)
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
  # See §11.8 for the full decision guide.
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

## Appendix D: Example `docker-compose.yml`

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

## Appendix E: Complete `tmux.conf`

Complete annotated configuration. Save to `~/dotfiles/tmux/tmux.conf`. Home Manager generates `~/.config/tmux/tmux.conf` from this file via `programs.tmux.extraConfig`. Reload with `prefix r` after any `hms`.

```bash
# ~/dotfiles/tmux/tmux.conf

# ── Prefix key ───────────────────────────────────────────────────────────────
# C-Space: doesn't conflict with Neovim (C-a = increment number)
# or readline (C-a = beginning-of-line). Easy thumb reach.
set -g prefix C-Space
unbind C-b
bind C-Space send-prefix

# ── Terminal and true colour ─────────────────────────────────────────────────
# BOTH lines are required. The first sets what tmux advertises to inner
# programs. The second passes the Tc (true-colour) capability through to the
# outer terminal (WezTerm). One without the other = washed-out Neovim themes.
# See §11.3 and §11.4 for the full explanation.
#
# ACTION: uncomment the line that matches your wezterm.lua term setting.
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",wezterm:Tc"        # if term = "wezterm"   ← default
# set -ga terminal-overrides ",xterm-256color:Tc" # if term = "xterm-256color"

# ── Window and pane numbering ────────────────────────────────────────────────
# Start at 1 (not 0): 1 is on the left of the keyboard, 0 is on the right.
# Alt-1, Alt-2, Alt-3 for window jumping is ergonomic.
set -g base-index 1
set -g pane-base-index 1
set-window-option -g pane-base-index 1
# Prevent gaps: closing window 2 of [1,2,3] gives [1,2] not [1,3]
set -g renumber-windows on

# ── Behaviour ────────────────────────────────────────────────────────────────
# tmux manages its own scrollback separately from WezTerm
set -g history-limit 50000

# CRITICAL for Neovim: default 500ms delay makes Escape feel laggy.
# Without this, every mode exit in Neovim has a half-second pause.
set -sg escape-time 0

# Required for Neovim autoread: tmux must forward FocusGained/FocusLost events.
# Without this, switching panes does not trigger buffer auto-reload in Neovim.
set -g focus-events on

# Mouse: click-to-focus and scroll. Use Shift-click to bypass tmux for
# WezTerm-level clipboard copies (see §11.6).
set -g mouse on

# Prevent tmux from renaming windows to the running command.
# The sessionizer names windows explicitly ("editor", "services", "git").
set -g automatic-rename off
set -g allow-rename off

# Required for tmux-yank to write to OS clipboard
set -g set-clipboard on

# ── Status bar ───────────────────────────────────────────────────────────────
# Catppuccin Mocha colours — must match WezTerm's color_scheme to prevent
# visible seams at pane borders. See §11.7.
# The Catppuccin tmux plugin (§4.7) will override most of this with a
# more polished version — these values serve as the fallback.
set -g status-position bottom
set -g status-style "bg=#1e1e2e,fg=#cdd6f4"
set -g status-left "#[fg=#89b4fa,bold] #S  "
set -g status-left-length 30
set -g status-right "#[fg=#6c7086] %H:%M "
set -g window-status-format "#[fg=#6c7086] #I:#W "
set -g window-status-current-format "#[fg=#cba6f7,bold] #I:#W "

# ── Pane borders ─────────────────────────────────────────────────────────────
set -g pane-border-style "fg=#313244"
set -g pane-active-border-style "fg=#cba6f7"

# ── Pane navigation: vim-tmux-navigator ──────────────────────────────────────
# Ctrl-h/j/k/l moves between panes AND Neovim windows seamlessly.
# The is_vim check detects whether the active pane is running Neovim or fzf;
# if so, the keystroke is passed through to that program instead.
# Requires the vim-tmux-navigator plugin in Neovim (§11.14).
is_vim="ps -o state= -o comm= -t '#{pane_tty}' \
    | grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?|fzf)(diff)?$'"

bind -n 'C-h' if-shell "$is_vim" 'send-keys C-h' 'select-pane -L'
bind -n 'C-j' if-shell "$is_vim" 'send-keys C-j' 'select-pane -D'
bind -n 'C-k' if-shell "$is_vim" 'send-keys C-k' 'select-pane -U'
bind -n 'C-l' if-shell "$is_vim" 'send-keys C-l' 'select-pane -R'

# ── Window navigation ─────────────────────────────────────────────────────────
# Alt+number: jump to window without prefix. No conflict with Neovim.
bind -n M-1 select-window -t :1
bind -n M-2 select-window -t :2
bind -n M-3 select-window -t :3
bind -n M-4 select-window -t :4

# ── Sessionizer binding ───────────────────────────────────────────────────────
# Ctrl-f: open sessionizer project picker from anywhere in tmux, no prefix
bind -n C-f run-shell "sessionizer"

# ── Pane splitting ────────────────────────────────────────────────────────────
# | for vertical split, - for horizontal — more intuitive than defaults.
# -c "#{pane_current_path}" opens the new pane in the current directory.
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

# ── Copy mode ─────────────────────────────────────────────────────────────────
# Vi-style copy mode. tmux-yank (TPM plugin) handles OS clipboard integration.
set-window-option -g mode-keys vi
bind -T copy-mode-vi v   send-keys -X begin-selection
bind -T copy-mode-vi y   send-keys -X copy-pipe-and-cancel
bind -T copy-mode-vi C-v send-keys -X rectangle-toggle

# ── Config reload ─────────────────────────────────────────────────────────────
bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded"

# ── Plugins ───────────────────────────────────────────────────────────────────
# Plugins are declared in home.nix (programs.tmux.plugins) and pinned via
# flake.lock. Home Manager appends the plugin run-shell lines after this file.
# Do not add TPM or plugin declarations here.
```

---

## Appendix F: Complete `wezterm.lua`

Complete annotated configuration. Save to `~/dotfiles/wezterm/wezterm.lua`. `setup-desktop.sh` symlinks it to `~/.config/wezterm/wezterm.lua`. Reload with `SUPER+SHIFT+R` after any change.

```lua
-- ~/dotfiles/wezterm/wezterm.lua
local wezterm = require 'wezterm'

return {

  -- ── Font ────────────────────────────────────────────────────────────────────
  -- Primary: JetBrainsMono Nerd Font (installed by Home Manager: nerd-fonts.jetbrains-mono).
  -- Nerd Font required for Powerline symbols, file icons, git branch indicators.
  -- Fallbacks: Noto Sans Symbols 2 and Noto Sans Symbols cover the Miscellaneous
  -- Technical Unicode block (U+2300–U+23FF), including U+23F5 (⏵) used by the
  -- Catppuccin tmux theme. Without the fallback, WezTerm logs glyph warnings.
  -- Noto fonts are installed by setup-desktop.sh: apt install fonts-noto fonts-noto-core
  -- If you see boxes (□) instead of icons, verify the primary font name with:
  --   fc-list | grep JetBrains
  font = wezterm.font_with_fallback({
    'JetBrainsMono Nerd Font',
    'Noto Sans Symbols 2',  -- Miscellaneous Technical + broader Unicode coverage
    'Noto Sans Symbols',    -- additional symbol fallback
  }),
  font_size = 13,   -- Adjust for your monitor DPI: 4K external → 15-16, laptop → 11-13

  -- ── Colour scheme ───────────────────────────────────────────────────────────
  -- Catppuccin Mocha: must match tmux's theme to prevent visible seams at
  -- pane borders. Both WezTerm and tmux must use the same palette.
  -- If you change this, also update tmux.conf Catppuccin flavour.
  -- See §11.7 for the full colour consistency mechanism.
  color_scheme = "Catppuccin Mocha",

  -- ── TERM setting ────────────────────────────────────────────────────────────
  -- "wezterm": enables undercurl (wavy LSP diagnostic underlines in Neovim)
  --            and richer true-colour support. Downside: SSH to remote hosts
  --            without the wezterm terminfo entry fails with "unknown terminal".
  --            Fix: infocmp wezterm | ssh remote "tic -x -"
  --
  -- "xterm-256color": universally supported, no SSH issues. Loses undercurl.
  --
  -- See §11.3 for the full trade-off explanation.
  term = "wezterm",

  -- ── Default program ──────────────────────────────────────────────────────────
  -- Launches tmux on every WezTerm window open.
  -- -A: attach if session named "main" exists, create it if not.
  -- This is what makes WezTerm disposable: close it, reopen, tmux is still there.
  default_prog = { "tmux", "new-session", "-A", "-s", "main" },

  -- ── Tab bar ──────────────────────────────────────────────────────────────────
  -- Tabs are for transient shells outside tmux (SSH, one-off commands).
  -- Hide when only one tab to reduce chrome — reappears when SUPER+T opens more.
  enable_tab_bar           = true,
  hide_tab_bar_if_only_one_tab = true,

  -- ── Window ───────────────────────────────────────────────────────────────────
  window_padding = { left = 6, right = 6, top = 6, bottom = 6 },
  -- "RESIZE": removes title bar, keeps resize handles. The tmux status bar
  -- provides all information the title bar would show.
  window_decorations = "RESIZE",

  -- ── Rendering ─────────────────────────────────────────────────────────────────
  force_reverse_video_cursor = false,  -- required for correct Neovim colour rendering
  scrollback_lines           = 5000,   -- WezTerm catches output before tmux attaches
  audible_bell               = "Disabled",
  default_cursor_style       = "BlinkingBlock",  -- easier to track across panes

  -- ── Clipboard ─────────────────────────────────────────────────────────────────
  -- false: prevents conflict with tmux copy mode (§11.9).
  -- Use Shift-click for WezTerm-level selection; prefix [ for tmux copy mode.
  copy_on_select = false,

  -- ── Keybindings ──────────────────────────────────────────────────────────────
  -- WezTerm-level bindings — operate around tmux, not inside it.
  keys = {
    -- New WezTerm tab (plain shell outside tmux — useful for SSH, one-offs)
    { key = "t", mods = "SUPER",       action = wezterm.action.SpawnTab "CurrentPaneDomain" },
    -- Reload wezterm.lua without restarting WezTerm
    { key = "r", mods = "SUPER|SHIFT", action = wezterm.action.ReloadConfiguration },
    -- Font size adjustment
    { key = "=", mods = "SUPER",       action = wezterm.action.IncreaseFontSize },
    { key = "-", mods = "SUPER",       action = wezterm.action.DecreaseFontSize },
    { key = "0", mods = "SUPER",       action = wezterm.action.ResetFontSize },
  },
}
```

---

## Appendix G: VS Code Extensions List

Save as `vscode/extensions.txt` in your dotfiles repository. One extension ID per line. Blank lines and lines starting with `#` are skipped by the bootstrap.

```
# Python
ms-python.python
ms-python.debugpy
charliermarsh.ruff

# JavaScript / TypeScript
esbenp.prettier-vscode
dbaeumer.vscode-eslint

# devenv / Nix integration — critical for $PATH (§11.6)
mkhl.direnv

# Docker
ms-azuretools.vscode-docker

# Git
eamodio.gitlens

# Data formats
redhat.vscode-yaml
tamasfe.even-better-toml

# Optional: Biome (if your JS/TS projects use Biome instead of Prettier + ESLint)
# biomejs.biome
```

---

## Appendix H: Troubleshooting

Organised by symptom. Each entry: symptom, cause, resolution. Setup and activation failures only — git and workflow failures are in Dev Workflows.

> [!tip] **Before searching this appendix, ask: which layer owns this?**
> The §1.2 debugging heuristic resolves 90% of problems faster than any symptom list:
> - Missing command or wrong version → **Devenv** (`devenv.nix` packages) or **Home Manager** (`home.nix` packages)
> - Tool missing globally → **Home Manager** → `hms`
> - Tool missing in one project → **Devenv** → `devenv.nix` packages + `devenv update`
> - Database/service not connecting → **Docker Compose** → `docker compose up -d`
> - Environment not activating on `cd` → **Direnv** → `direnv allow`; check hook order (§7.4)
> - Icons/colour broken → **Nerd Font** (Part 6) or **TERM propagation** (§3.3, §4.4)
> - Editor LSP not finding tools → **Devenv `$PATH` not reaching editor** → §8.5, §11.6
>
> The full layer reference is §1.9.

---

### Nix Installation Fails

**Symptom:** `curl: (6) Could not resolve host: install.determinate.systems` **Cause:** Network connectivity issue. **Resolution:** Verify internet access (`ping google.com`). If behind a proxy, configure `https_proxy` before running the installer.

**Symptom:** `error: the user 'nobody' does not exist` **Cause:** Rare on Ubuntu minimal installs — the `nobody` system user is missing. **Resolution:**

```bash
sudo useradd -r nobody
# Then re-run the bootstrap from step 3
```

---

### `hms` (`home-manager switch`) Errors

**Symptom:** `error: attribute 'yourusername' missing` **Cause:** The username string after `#` in the switch command does not match the `homeConfigurations` key in `flake.nix`. **Resolution:** Confirm `whoami` matches the key in `flake.nix` and `home.nix`:

```bash
whoami
grep "homeConfigurations" ~/dotfiles/flake.nix
```

**Symptom:** `error: undefined variable 'pkgs'` or Nix syntax error with a line number **Cause:** Syntax error in `home.nix`. **Resolution:** Open `home.nix`, go to the reported line, fix the syntax. Common mistakes: missing semicolons in Nix expressions, unclosed braces, wrong attribute path.

**Symptom:** `error: package 'xyz' not found` **Cause:** A package name in `home.packages` does not exist in nixpkgs. **Resolution:** Search the correct attribute name at `search.nixos.org/packages`. Nix package names are not always the same as the tool's binary name.

**Symptom:** Step hangs for more than 30 minutes without output **Cause:** Slow or stalled package download from `cache.nixos.org`. **Resolution:** Press `Ctrl-C` to abort. Check internet connectivity. Re-run the bootstrap — Nix downloads are resumable and will pick up where they left off.

---

### WezTerm Shows Boxes instead of Icons

**Symptom:** Powerline separators in the tmux status bar appear as `□` or `?`. File icons in Neovim's file explorer are missing. **Cause:** Either the Nerd Font is not installed, WezTerm is configured with the wrong font name, or Flatpak's sandbox is blocking access to Nix-managed fonts.

**Diagnosis — check if font is installed:**

```bash
fc-list | grep JetBrains
```

If this returns nothing: the bootstrap font installation failed. Re-run manually:

```bash
mkdir -p ~/.local/share/fonts/NerdFonts
cd /tmp && curl -fLo JetBrainsMono.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
unzip JetBrainsMono.zip -d ~/.local/share/fonts/NerdFonts/
fc-cache -fv
```

If `fc-list | grep JetBrains` returns output but WezTerm still shows the _"Unable to load a font"_ warning: WezTerm is installed via Flatpak and its sandbox cannot follow the symlink `~/.nix-profile/share/fonts → /nix/store/...`. Fix by granting Flatpak read access to the Nix store:

```bash
flatpak override --user --filesystem=/nix:ro org.wezfurlong.wezterm
```

Then restart WezTerm. This is now applied automatically by `setup-desktop.sh`.

If the font is installed and Flatpak access is granted but boxes persist: the family name in `wezterm.lua` is wrong. Use the exact name from `fc-list` output:

```bash
fc-list | grep JetBrains | head -3
# The family name is the second field: "JetBrainsMono Nerd Font"
```

---

### Direnv not Activating on `cd`

**Symptom:** Entering a project directory does not activate the devenv environment. `which python` shows a system path.

**Cause 1:** `direnv allow` has not been run in this directory. **Resolution:** `direnv allow` (run once per developer per repo).

**Cause 2:** The direnv hook is initialised too late in `.zshrc`. **Symptom detail:** This specifically affects the first pane in new tmux sessions — tmux fires the initial window command before `.zshrc` finishes. **Resolution:** In `home.nix` `programs.zsh.initContent`, move `eval "$(direnv hook zsh)"` to position 3 in the load order (after PATH and Nix profile, before zoxide and fzf). See §11.4.

**Cause 3:** nix-direnv is not enabled in `home.nix`. **Resolution:** Verify `programs.direnv.nix-direnv.enable = true` in `home.nix` and run `hms`.

---

### Devenv Binary not Found after `devenv init`

**Symptom:** `devenv: command not found` after the bootstrap. **Cause:** The Nix profile PATH is not active in the current shell session. **Resolution:**

```bash
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
devenv --version
```

If this works, the issue is the shell load order — the Nix profile sourcing line in `home.nix` `initContent` must run before any command that depends on Nix-installed binaries. Open a new terminal to get the fully-loaded shell.

---

### `docker ps` Returns Permission Denied

**Symptom:** `permission denied while trying to connect to the Docker daemon socket` **Cause:** The Docker group membership added by the bootstrap has not taken effect — it requires a session boundary. **Resolution:** Log out of the Ubuntu desktop session and log back in. Then:

```bash
docker ps
# Should return empty container list, no error
```

Temporary workaround for the current terminal session only:

```bash
newgrp docker
```

---

### VS Code Cannot Find Python Interpreter or Uses Wrong Binary Version

**Symptom:** VS Code shows "Python interpreter not found" or the Ruff extension uses a different version than the terminal. **Cause:** `mkhl.direnv` extension is not installed or not active. VS Code is using the system `$PATH` instead of devenv's. **Resolution:**

1. Confirm `direnv allow` has been run in the project directory:

```bash
direnv status
```

2. Confirm `mkhl.direnv` is installed in VS Code:

```
View → Extensions → search "direnv"
```

3. If installed but not active, reload the VS Code window:

```
Ctrl+Shift+P → "Developer: Reload Window"
```

4. Verify in Output panel: `View → Output → select "Ruff"` — binary path must start with `/nix/store/`.

See §11.6 for the full `$PATH` flow diagram.

---

### Neovim LSP not Attaching

**Symptom:** `:LspInfo` shows no attached servers, or the server shows a Mason binary path instead of `/nix/store/`.

**Cause 1:** `mason = false` is not set for the server in `lua/plugins/lsp.lua`. **Resolution:** Add `mason = false` to the server's entry in `lsp.lua`. Restart Neovim.

**Cause 2:** The devenv environment is not active — Neovim was opened outside the project directory or before `direnv allow` was run. **Resolution:**

```bash
cd ~/projects/my-project
direnv allow   # if not already done
which pyright-langserver   # must show /nix/store/...
nvim app/main.py
```

**Cause 3:** The LazyExtra for this language is not enabled. **Resolution:** Run `:LazyExtras` in Neovim, find the language extra, enable it with `x`.

---

### Neovim Clipboard not Working

**Symptom:** `yy` in Neovim does not paste in the browser. `p` in Neovim does not paste from the browser. **Cause:** Either `vim.opt.clipboard = "unnamedplus"` is not set, or the clipboard provider is missing. **Resolution:**

1. Confirm the setting in `~/dotfiles/nvim/lua/config/options.lua`:

```lua
vim.opt.clipboard = "unnamedplus"
```

2. Confirm the clipboard provider is installed:

```bash
echo $XDG_SESSION_TYPE    # x11 or wayland
which xclip               # for X11
which wl-copy             # for Wayland
```

If missing, add `pkgs.xclip` or `pkgs.wl-clipboard` to `home.nix` packages and run `hms`.

---

### Tmux Colours Look Wrong in Neovim

**Symptom:** Neovim's colour scheme uses muted, incorrect colours instead of the expected vibrant ones. **Cause:** The two required tmux true-colour lines are missing or one is incorrect. **Diagnosis:**

```vim
:checkhealth
" Look for a termguicolors warning
```

**Resolution:** Verify both lines are present in `tmux.conf` and that the `terminal-overrides` value matches your WezTerm `term` setting (§11.4):

```bash
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",wezterm:Tc"        # if wezterm.lua: term = "wezterm"
# set -ga terminal-overrides ",xterm-256color:Tc" # if wezterm.lua: term = "xterm-256color"
```

Reload with `prefix r`.

---

### Escape in Neovim Feels Laggy

**Symptom:** Pressing Escape to leave insert mode has a noticeable half-second delay. **Cause:** `escape-time` is not set to 0 in `tmux.conf`. **Resolution:** Add or verify in `tmux.conf`:

```bash
set -sg escape-time 0
```

Reload with `prefix r`. Verify: `tmux show-options -g escape-time` must output `0`.

---

### Direnv not Activating in New Tmux Panes

**Symptom:** Opening a new tmux pane in a project directory does not activate the devenv environment. The existing session has it active but new panes do not. **Cause:** The direnv hook is initialised too late in `.zshrc` — tmux fires the initial window command before the hook is loaded. **Resolution:** In `home.nix` `programs.zsh.initContent`, move `eval "$(direnv hook zsh)"` to position 3 — after PATH and Nix sourcing, before zoxide and fzf. The correct full load order is in §11.4.

---

### LazyVim Shows Errors on First Open

**Symptom:** Neovim opens with red error messages about missing plugins or modules. **Cause:** The headless plugin sync in bootstrap step 13 failed silently. **Resolution:** Run the sync interactively:

```vim
:Lazy sync
```

Wait 1–3 minutes for all plugins to install. Restart Neovim.

---

## Appendix I: Automated LSP Injection Script

This script patches existing `devenv.nix` files to add the project-bound LSP binaries (`pyright`, `ruff`, `typescript-language-server`, `just`) to the `packages` list. Useful when migrating a project that was set up before this guide's LSP strategy was established.

> [!note] **`nodePackages` namespace on `nixos-unstable`**
> This script injects `pkgs.nodePackages.typescript-language-server`. On `nixos-unstable` (the channel this guide uses), many Node packages have migrated from `nodePackages.*` to top-level attribute names. If `devenv update` fails after injection with an error like `error: attribute 'typescript-language-server' missing`, replace it with `pkgs.typescript-language-server`. Similarly, `pkgs.nodePackages.vscode-langservers-extracted` may need to become `pkgs.vscode-langservers-extracted`, and `pkgs.nodePackages.prettier` may need to become `pkgs.nodePackages_latest.prettier`. Check the correct attribute name at [search.nixos.org/packages](https://search.nixos.org/packages) if in doubt.

Save as `inject-lsps.sh` in your dotfiles `scripts/` directory.

```bash
#!/usr/bin/env bash
# inject-lsps.sh
# Scans a directory tree for devenv.nix files and injects LSP binaries
# into the packages list if they are not already present.
#
# Usage: ./inject-lsps.sh [target-directory]
# Default target: ~/projects
#
# The script uses awk for portable multi-line injection, which works
# correctly across both GNU and BSD variants.

set -euo pipefail

TARGET_DIR="${1:-$HOME/projects}"

# Packages to inject if not already present
INJECT_PACKAGES=(
    "pkgs.pyright"
    "pkgs.ruff"
    "pkgs.nodePackages.typescript-language-server"
    "pkgs.just"
)

# Build the injection string (indented to match typical devenv.nix style)
INJECT_STR=""
for pkg in "${INJECT_PACKAGES[@]}"; do
    INJECT_STR+="    ${pkg}\n"
done

echo "Scanning $TARGET_DIR for devenv.nix files..."
echo ""

PATCHED=0
SKIPPED=0

# Use process substitution so PATCHED/SKIPPED are modified in the current shell,
# not a subshell. A pipe (find ... | while ...) would create a subshell, making
# the counter updates invisible to the outer shell and always printing 0.
while read -r file; do
    # Skip if pyright is already present (assume already migrated)
    if grep -q "pkgs.pyright" "$file" 2>/dev/null; then
        echo "SKIP  $file (LSPs already present)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Skip if the file has no packages block to inject into
    if ! grep -q "packages = \[" "$file" 2>/dev/null; then
        echo "SKIP  $file (no 'packages = [' block found)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Backup original
    cp "$file" "${file}.bak"

    # Inject using awk — find the first 'packages = [' line and insert after it.
    # awk is used instead of sed to handle multi-line injection portably.
    awk -v inj="$INJECT_STR" '
        /packages = \[/ && !injected {
            print
            printf "%s", inj
            injected = 1
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    echo "PATCH $file"
    echo "      (backup saved as ${file}.bak)"
    PATCHED=$((PATCHED + 1))
done < <(find "$TARGET_DIR" -name "devenv.nix" -type f | sort)

echo ""
echo "Complete."
echo "  Patched: $PATCHED"
echo "  Skipped: $SKIPPED"
echo ""
echo "Next steps:"
echo "  1. Review each patched file: the injected packages appear at the"
echo "     top of the packages list — reorder if needed."
echo "  2. Run 'devenv update' in each patched directory to update devenv.lock."
echo "  3. Verify: cd into the project, 'which pyright-langserver' should"
echo "     show a /nix/store/... path."
echo "  4. Remove backup files once satisfied: find $TARGET_DIR -name '*.bak' -delete"
```

Make executable:

```bash
chmod +x ~/dotfiles/scripts/inject-lsps.sh
```

Usage:

```bash
# Scan ~/projects (default)
~/dotfiles/scripts/inject-lsps.sh

# Scan a specific directory
~/dotfiles/scripts/inject-lsps.sh ~/work

# After reviewing the patches, update each project's lockfile:
find ~/projects -name "devenv.nix" | while read -r f; do
    dir=$(dirname "$f")
    echo "Updating $dir..."
    (cd "$dir" && devenv update)
done
```

---

---

## Appendix J: Getting a Machine — Where to Start

Before the bootstrap can run, you need exactly one thing: a machine with Ubuntu 22.04 or 24.04, internet access, and `sudo` rights. How you get there does not matter — the Nix bootstrap is identical on bare metal, a VM, a cloud VPS, or WSL2. This appendix routes you to the right starting point.

> [!note] **The development environment does not require a desktop.** Nix, Home Manager, tmux, and Neovim all run headlessly over SSH. A desktop is a separate optional layer, covered in Appendix L, that is useful if you need GUI applications or remote graphical access via RDP. You can install the desktop before or after the bootstrap, or not at all. The stack is the same either way.

---

### J.1 Prepare Any Ubuntu Machine

Whether your Ubuntu machine is brand new or has been running for months, the preparation is the same commands. `apt install` is idempotent — it skips packages that are already installed, so there is no risk in running this on an existing system.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git openssh-client build-essential \
  ca-certificates gnupg unzip xz-utils
```

That is the entire machine preparation for the development environment. The bootstrap handles everything else.

**If you also want a graphical desktop:** see Appendix L — but complete the bootstrap first. The desktop can be added at any time and does not interact with the Nix layer.

**If you are on VMware Workstation specifically:** see Appendix K for bridged networking, VMware Tools, and the snapshot workflow. Then come back here.

---

### J.2 Getting the Setup Script onto a Fresh Machine

The commands in §J.1 are short enough to type manually. If you prefer a script, `setup-base.sh` lives in your **public** `workstation-scripts` repository and can be fetched with a single command — no SSH key, no git, no credentials needed:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/setup-base.sh)
```

Replace `yourusername` with your GitHub username. The script is idempotent — safe to run on a machine that already has some of the packages installed.

> [!note] `setup-base.sh` lives in `workstation-scripts` (public), not `dotfiles` (private). This is intentional: `wget` and `curl` cannot fetch from a private repository without credentials. The scripts repo is public precisely so any new machine can fetch from it anonymously — no SSH key or GitHub login required. See Appendix M (§M.1) for the full explanation of why the two-repository split exists.

If you have not yet created your repositories, go to Appendix M first.

---

### J.3 Decision Summary

| Your situation | What to do |
|---|---|
| Haven't created repositories yet | Appendix M first — creates `workstation-scripts` + `dotfiles` |
| Any Ubuntu machine (new or existing) | Commands in §J.1, then Part 1 |
| VMware Workstation | Appendix K first, then §J.1, then Part 1 |
| Want a graphical desktop | Bootstrap first (Part 2), then Appendix L |
| Unsure whether you need a desktop | Bootstrap first — desktop can be added later |

---

## Appendix K: VMware Workstation — Platform-Specific Setup

This appendix covers the VMware-specific setup steps: bridged networking, Ubuntu Server installation, VMware Tools, and the snapshot workflow. These steps are specific to VMware Workstation. If you are on another platform (bare metal, VirtualBox, Hyper-V, cloud), skip this appendix and use Appendix J (§J.2) instead.

> [!note] **What this appendix does and does not cover**
> This appendix gets you to a clean Ubuntu Server with network access and VMware Tools installed. It does not install a desktop environment — that is in Appendix L, and is optional. After completing this appendix, go to **Part 1**.

---

### K.1 VMware Network Configuration

> [!warning] Do this before creating the VM. If the VM already exists, power it off before changing settings.

By default, VMware uses **NAT networking**, which isolates the VM. This prevents other machines on your LAN from connecting via RDP.

### Use Bridged Mode

Bridged mode connects the VM directly to your network, giving it an IP on your LAN that is reachable from other machines.

### Steps

1. VM → Settings → Network Adapter
2. Select **Bridged**
3. Choose your **specific physical adapter** (avoid "Automatic" — it picks the wrong one when multiple adapters are present)
4. Start the VM

### Verify

```bash
ip addr show
```

You should see an IP in your LAN range (`192.168.x.x` or `10.x.x.x`). If a NAT IP persists after switching to Bridged:

```bash
sudo ip addr del 192.168.75.x/24 dev ens33
```

---

### K.2 Install Ubuntu Server 24.04 LTS

### During Installation

* Use **Ubuntu Server 24.04 LTS**
* Allocate: **≥4 GB RAM · 2 CPUs · 40 GB disk**
* Create a **non-root sudo user**
* Skip optional snaps

---

### First Boot — Base System

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git build-essential ca-certificates gnupg \
  lsb-release software-properties-common apt-transport-https unzip zip xz-utils
```

> [!info] `git` is included here only because the bootstrap script (§2.4) uses `git clone` as its first action. All meaningful git configuration — identity, aliases, delta pager — is handled later by the bootstrap (§3.2), not here.

---

---

### K.3 VMware Tools

```bash
sudo apt install -y open-vm-tools open-vm-tools-desktop
sudo reboot
```

**Why this matters:**

* Correct display resolution in the VMware window
* Clipboard sharing between host and VM
* Smooth mouse input without capture/release friction

---

> [!note] **Why no reboot here?** VMware Tools installs correctly without a reboot. Full clipboard integration and display resolution adjustment require a reboot, but those only matter if you are adding a desktop (Appendix L). If you are running headless, skip the reboot until after the Nix bootstrap is complete.

---

### K.4 Take a Snapshot

> [!tip] Take a VMware snapshot immediately after completing A.5. This is your clean-slate checkpoint — before Nix touches anything.

VMware → **VM → Snapshot → Take Snapshot**

Name it something dated and unambiguous:

```
Host OS ready — YYYY-MM-DD
```

If the Nix installation later goes wrong, you can revert to this snapshot and start the bootstrap again without repeating A.0–A.5.

---

---

### K.5 Base Setup Script

> [!tip] **📋 This section is the source for `setup-base.sh`** in your `workstation-scripts` repository. Copy the script below into that file.

The steps in §K.2 can be run as a single script. Once your `workstation-scripts` repository is created and pushed (Appendix M), fetch and run it with:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/setup-base.sh)
```

This script lives in `workstation-scripts` (public), not `dotfiles` (private). `wget` can fetch it anonymously — no SSH key or credentials needed on the new machine.

Save this as `setup-base.sh` at the root of your `workstation-scripts` repository. It is idempotent — safe to re-run.

```bash
#!/usr/bin/env bash
# setup-base.sh
# Installs base system packages needed before the Nix bootstrap.
# Works on any Ubuntu 22.04/24.04 machine — bare metal, VM, or cloud.
# Safe to re-run (idempotent).
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "${GREEN}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }

step "Updating package index"
sudo apt update && sudo apt upgrade -y
ok "Package index updated"

step "Installing base packages"
sudo apt install -y \
  curl wget git openssh-client build-essential ca-certificates gnupg \
  lsb-release software-properties-common apt-transport-https \
  unzip zip xz-utils
ok "Base packages installed"

echo ""
echo -e "${GREEN}✅ Base setup complete.${NC}"
echo ""
echo "Next steps:"
echo "  1. Generate an SSH key and register it on GitHub (§2.1)"
echo "  2. Go to Part 1 of the guide"
```

---

### K.6 Installation Order Reference (VMware path)

| Step | Action | How |
|---|---|---|
| K.1 | VMware Bridged networking | Manual (before creating VM) |
| K.2 | Ubuntu Server installation | Manual |
| K.2 | Base packages | Script (setup-base.sh) or manual |
| K.3 | VMware Tools | `sudo apt install -y open-vm-tools` |
| K.4 | Snapshot | Manual (VMware UI) |
| — | **Go to Part 1** | Main guide |
| — | *(Optional)* Desktop environment | Appendix L |

---

## Appendix L: Desktop — Connection and Tiling Reference

> [!note] **Installation is fully automated.** XFCE4, LightDM, XRDP, WezTerm, VS Code, Chrome, ksnip, and the polkit shutdown rule are all installed by `setup-desktop.sh` (Installation Step 5). This appendix covers the steps that the script cannot automate: connecting from Windows and configuring window tiling shortcuts.

> [!note] **This appendix applies to any Ubuntu machine** — VMware VM, bare metal, VirtualBox, or cloud instance. VMware Tools (Appendix K) improves clipboard and display behaviour if you are in a VMware VM, but it is not required for XRDP to work.

---

### L.1 Why XFCE4?

- **Lightweight** — low RAM footprint
- **XRDP-compatible** — LightDM uses Xorg by default (do not switch to Wayland — XRDP does not support it)
- **Not Xubuntu** — Xubuntu uses Arctica Greeter, which conflicts with XRDP

None of the desktop components interact with Nix, Home Manager, or your dotfiles repository. Adding or removing the desktop does not affect the development environment.

---

### L.2 Connecting from Windows via RDP

#### Single Monitor

1. Open **Remote Desktop Connection** (`mstsc`)
2. Enter the VM's IP address (from `ip addr show`)
3. Select **Xorg** as the session type
4. Log in with your Ubuntu username and password

---

#### Firewall Considerations

> [!warning] **Enabling UFW with a subnet rule can block your RDP connections.**
>
> A common pattern found in tutorials looks like this:
> ```bash
> sudo ufw allow from 192.168.1.0/24 to any port 3389 proto tcp
> sudo ufw enable
> ```
> This has two problems. First, the subnet `192.168.1.0/24` is hardcoded — if your LAN uses a different range (common with ISP routers that assign `10.x.x.x` or `192.168.0.x`), the rule silently does not match and RDP connections are blocked. Second, enabling UFW on a VM that is already behind a NAT router or a corporate firewall adds a second firewall layer with no practical security benefit for a single-developer workstation.

**For a VM on a trusted private LAN (home office, dedicated dev network), the recommended approach is to leave UFW disabled.** Your router is the perimeter. The VM is not directly reachable from the internet.

If you are on a network where you cannot trust other machines on the same LAN segment — a shared office network, a conference network, a colocation environment — then enable UFW with a rule that matches your actual LAN range:

```bash
# First, find your actual LAN subnet:
ip route | grep -v default

# Then set a rule matching that subnet, allow SSH first:
sudo ufw allow OpenSSH
sudo ufw allow from <your-actual-subnet> to any port 3389 proto tcp
sudo ufw enable
```

**Verify connectivity before closing your current terminal session.** If you lose access, power-cycle the VM from the VMware console.

---

#### Connect from Windows — Single Monitor

* Open **Remote Desktop Connection** (`mstsc`)
* Enter the VM's IP address (from `ip addr show`)
* Select **Xorg** as the session type
* Log in with your Ubuntu username and password

---

#### Connect from Windows — Multiple Monitors

XRDP supports two approaches for multi-monitor setups. Choose based on how you want the session to behave.

#### Option A: Span Mode (recommended — Zero Server configuration)

Span mode sends both monitors as a single wide logical display to XRDP. The VM sees one screen whose width is the sum of your two monitors (e.g. 3840×1080 for two 1920×1080 displays). XFCE and all applications work normally within this wide canvas.

**Steps:**

1. Open **Remote Desktop Connection** and click **Show Options**
2. Go to the **Display** tab
3. Check **Use all my monitors for the remote session**
4. Connect as normal

Alternatively, save the configuration to an `.rdp` file and set it directly:

```
screen mode id:i:2
use multimon:i:1
desktopwidth:i:3840
desktopheight:i:1080
```

Replace `3840` and `1080` with the combined width and height of your monitors. Run `mstsc /l` in a Windows terminal to list your monitor numbers if you want to use only specific monitors.

> [!note] **What tiling looks like in span mode**
> With a single wide logical display, xfwm4 tiles relative to the full 3840px canvas. "Left half" places a window in the left 1920px — which happens to be your left physical monitor. "Right half" places it in the right 1920px. Halves and quarters work naturally for a two-monitor setup. If you have three or more monitors, the arithmetic becomes less convenient; consider Option B.

#### Option B: True Dual-Monitor via xrdp_dualmon (advanced)

`xrdp_dualmon` is a small open-source hook that intercepts the XRDP session startup and writes a fake Xinerama configuration file, telling Xorg there are two separate screens at the correct dimensions. Applications then maximise to one screen rather than the full combined width, and XFCE's panel spans both monitors correctly.

> [!warning] **This is an advanced option.** It requires compiling and installing a small C program and editing XRDP's session startup script. It is not officially supported by XRDP. It has been tested on Ubuntu 22.04 and 24.04 but may break on XRDP version upgrades. For most workflows, span mode (Option A) is sufficient.

```bash
# Install build dependency
sudo apt install -y build-essential libx11-dev

# Clone and build
git clone https://github.com/asafge/xrdp_dualmon.git
cd xrdp_dualmon
make

# Install the hook
sudo cp xrdp_dualmon /usr/local/bin/
sudo chmod +x /usr/local/bin/xrdp_dualmon

# Inject into XRDP's session startup — adds the call before the final exec line
sudo sed -i 's|^exec|/usr/local/bin/xrdp_dualmon\nexec|' /etc/xrdp/startwm.sh

sudo systemctl restart xrdp
```

Connect using the same `.rdp` settings as Option A. The hook fires at session start and splits the wide display into two virtual Xinerama screens automatically.

---

> [!warning] **One session at a time**
> Do not keep a local XFCE session open at the VM console while an XRDP session is also active. Both sessions fight over the same user session resources, producing display corruption and clipboard failures.

---

#### Left-Handed Mouse (Optional)

```bash
xinput set-button-map "xrdpMouse" 3 2 1
```

To persist across sessions:

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/left-handed-mouse.desktop << EOF
[Desktop Entry]
Type=Application
Name=Left-handed mouse
Exec=xinput set-button-map xrdpMouse 3 2 1
X-GNOME-Autostart-enabled=true
EOF
```

> [!tip] Use the device name `xrdpMouse` rather than a numeric ID. Device IDs are reassigned on each connection; the name is stable.

---

#### Enable Shutdown / Restart via XRDP

By default, the power-off and reboot buttons in XFCE's session menu are greyed out for XRDP sessions because polkit requires an active local console session to authorise these actions. The rule below grants the permission to sudo-group members in any active session:

```bash
sudo tee /etc/polkit-1/rules.d/85-shutdown.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.reboot") &&
        subject.isInGroup("sudo") && subject.active) {
        return polkit.Result.YES;
    }
});
EOF

sudo systemctl restart polkit
```

---

#### Recommended Reboot

```bash
sudo reboot
```

---

### L.3 Window Tiling — Keyboard Shortcuts via Xfwm4

XFCE's own window manager, xfwm4, includes full tiling support: halves (left, right, top, bottom) and quarters (all four corners). No additional software is required. Configuration is done once through the XFCE settings GUI and persists across sessions.

> [!note] **This section applies to any monitor setup.** Single monitor, dual monitor in span mode, or dual monitor via xrdp_dualmon — the tiling shortcuts work identically in all cases. The only difference is what "left half" means geometrically: on a single 1920×1080 display it occupies 960px; in span mode across two 1920×1080 monitors it occupies 1920px, which conveniently aligns with your left physical screen.

---

#### L.3.1 Enabling Drag-to-Tile (Mouse)

Before configuring keyboard shortcuts, enable the mouse drag-to-tile feature so both input methods work:

1. Open **Settings Manager** → **Window Manager Tweaks**
2. Go to the **Accessibility** tab
3. Enable **"Automatically tile windows when moving towards the screen edge"**

With this on, dragging a window to the middle third of a screen edge snaps it to a half; dragging to a corner snaps it to a quarter. This is helpful during initial exploration — you can discover the positions by mouse before relying on keyboard shortcuts exclusively.

---

#### L.3.2 Assigning Keyboard Shortcuts

xfwm4's tiling actions have no shortcuts assigned by default. Set them through:

**Settings Manager → Window Manager → Keyboard tab**

Scroll to the tiling actions and assign the following. Click an action, then press the desired key combination.

| Action | Recommended shortcut | Position |
|---|---|---|
| Tile window to the left | `Super + Left` | Left half |
| Tile window to the right | `Super + Right` | Right half |
| Tile window to the top | `Super + Up` | Top half |
| Tile window to the bottom | `Super + Down` | Bottom half |
| Tile window to the top-left | `Super + Ctrl + Left` | Top-left quarter |
| Tile window to the top-right | `Super + Ctrl + Right` | Top-right quarter |
| Tile window to the bottom-left | `Super + Shift + Left` | Bottom-left quarter |
| Tile window to the bottom-right | `Super + Shift + Right` | Bottom-right quarter |
| Maximize window | `Super + M` | Full screen |
| Restore window | `Super + R` | Back to original size |

These bindings follow the Windows 11 muscle memory pattern for halves (`Super+Arrow`) while extending it to quarters with `Ctrl` and `Shift` modifiers.

> [!tip] **Using a numpad?** xfwm4's tiling actions map spatially to the numpad layout. `KP_4` is left, `KP_6` is right, `KP_7` is top-left corner, and so on. If your keyboard has a numpad and NumLock is enabled, you can use `Super+KP_1` through `Super+KP_9` as an alternative to the arrow-key bindings above. The two sets can coexist — assign both if you switch between keyboard types.

---

#### L.3.3 The Whisker Menu Conflict

xfwm4 has a known issue: **if `Super` alone is assigned to open the Whisker menu (the application launcher), `Super+Arrow` tiling shortcuts will not fire.** The Super key is consumed on keypress for the menu binding before xfwm4 can process the combination.

Check whether you have this conflict:

```bash
xfconf-query -c xfce4-keyboard-shortcuts -p /commands/custom -l -v | grep -i super
```

If the output contains a line where `Super_L` or `Super_R` alone (without any other modifier) is mapped to `xfce4-popup-whiskermenu`, you have the conflict.

**Fix — reassign the Whisker menu to a combination:**

1. Open **Settings Manager → Keyboard → Application Shortcuts**
2. Find the `xfce4-popup-whiskermenu` entry
3. Change it from `Super` to `Super + Space` (or `Ctrl + F1` if you prefer)

Now `Super+Arrow` works as expected for tiling, and `Super+Space` opens the app launcher.

> [!note] The Super key still works as the Windows key in most application contexts (e.g. inside WezTerm and VS Code). The conflict only affects xfwm4-level shortcuts, not application-internal ones.

---

#### L.3.4 Cycling Through Sizes

xfwm4's tiling is not a one-size-per-position system. Pressing the same shortcut repeatedly **cycles the window through width presets** at that position. For example, pressing `Super+Left` once snaps the window to the left half. Pressing it again may snap it to the left third or left two-thirds, depending on your xfwm4 version and configuration.

This cycling behaviour is built in and requires no configuration. It is useful on wide displays where 50% is too wide for a reference pane — one extra keypress reduces it.

---

#### L.3.5 Backing Up the Configuration

The tiling shortcuts are stored in:

```
~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
```

To include them in your dotfiles repository:

```bash
cp ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml \
   ~/dotfiles/xfce4/xfce4-keyboard-shortcuts.xml
```

Add a corresponding entry to your dotfiles `README.md` noting that restoring this file requires either importing it through the XFCE settings editor or replacing the file while `xfconfd` is not running:

```bash
# To restore on a new machine:
pkill xfconfd
cp ~/dotfiles/xfce4/xfce4-keyboard-shortcuts.xml \
   ~/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
# Then log out and back in, or restart xfconfd:
/usr/lib/x86_64-linux-gnu/xfce4/xfconf/xfconfd &
```

> [!note] The bootstrap script does not restore XFCE settings — it manages the Nix/Home Manager layer only. XFCE configuration files are outside the Home Manager boundary (§1.5). Backing up `xfce4-keyboard-shortcuts.xml` in your dotfiles repo is optional but saves repeating this setup on a new machine.

---

### L.4 Desktop Setup Script Reference

The full `setup-desktop.sh` script installs XFCE4, LightDM, XRDP, Noto fonts, WezTerm, VS Code, ksnip, the polkit shutdown rule, and sets WezTerm as the default terminal. It lives in your `workstation-scripts` repository and is run in Installation Step 5:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/setup-desktop.sh)
```

The authoritative source is `setup-desktop.sh` in your `workstation-scripts` repository. Refer to the script file for full implementation details.

### L.5 Installation Order Reference (Desktop path)

| Step | Action | How |
|---|---|---|
| — | Complete the Nix bootstrap first | Installation Steps 1–4 |
| Step 5 | XFCE4, LightDM, XRDP, WezTerm, VS Code, Chrome, ksnip, polkit | `setup-desktop.sh` (automated) |
| — | **Reboot** | Manual |
| Step 6 | Connect via RDP | §L.2 |
| Step 6 | Window tiling keyboard shortcuts | §L.3 (post-login, one time) |

> [!note] **VMware users** — install VMware Tools (§K.3) before running `setup-desktop.sh` if you have not already. VMware Tools enables clipboard sharing and display auto-resize between the VM and the XRDP session.

---

## Appendix M: Creating Your GitHub Repositories

This appendix walks through creating the two repositories this guide uses and populating them from the reference material. If you are setting up this environment for the first time, do this before anything else.

> [!note] **What you will have by the end of this appendix**
> - A public `workstation-scripts` repository on GitHub containing the three runnable setup scripts
> - A private `dotfiles` repository on GitHub containing your personal environment declaration
> - Both repositories verified as accessible — `curl` can fetch the scripts, SSH can reach the dotfiles
> - A clear understanding of why each repository has the visibility it does

---

### M.1 Why Two Repositories?

Most dotfiles guides use a single repository for everything. This guide uses two, and the reason is worth understanding before you create them — it affects every decision that follows.

**The problem with a single repository:**

The bootstrap must be runnable on a brand-new machine that has no SSH key, no git configuration, and no credentials. The only tool available is `curl`, which fetches files over unauthenticated HTTPS. A private repository is not accessible via unauthenticated HTTPS — so either the bootstrap cannot be fetched, or the repository containing your personal config must be public.

**The solution — separate by audience:**

A setup script has no personal data. `bootstrap.sh` is essentially the same for every developer using this guide — it installs Nix, clones a dotfiles repo, and builds an environment. There is nothing in it that needs to be private. Making it public costs nothing.

Your dotfiles are the opposite. `home.nix` contains your git identity, your shell aliases, your preferred tools. `wezterm.lua` has your font and colour preferences. The sessionizer script knows your project directory structure. None of this is sensitive in the security sense, but it is personal — and there is no reason to share it publicly.

Two repositories with different visibility solves both requirements cleanly:

```
workstation-scripts  (PUBLIC)
  └── bootstrap.sh           ← fetched by curl on any new machine
  └── setup-base.sh          ← fetched by curl before the bootstrap
  └── setup-desktop.sh       ← fetched by curl to add the desktop layer

dotfiles  (PRIVATE)
  └── flake.nix              ← cloned via SSH once key is verified by bootstrap
  └── home.nix
  └── wezterm.lua, tmux.conf, sessionizer, ...
```

The bootstrap verifies that your SSH key exists and is authenticated with GitHub, then clones your private dotfiles. If the key is missing, the bootstrap exits immediately with instructions — no generation, no pause. `wget` never touches the private repository. SSH never touches the public one.

---

### M.2 Create the `workstation-scripts` Repository

**On GitHub:**

1. Go to [github.com/new](https://github.com/new)
2. Set these values:
   - **Repository name:** `workstation-scripts`
   - **Visibility:** Public
   - **Initialize with README:** Yes
   - Leave everything else at defaults
3. Click **Create repository**

**Clone it locally:**

```bash
cd ~
git clone git@github.com:yourusername/workstation-scripts.git
cd workstation-scripts
```

> [!note] You are cloning this repo locally so you can edit scripts in your editor and push them. The scripts will be *run* on other machines via `curl` — but you *author* them here.

---

### M.3 Populate the Scripts

Copy each script from the appendix listed below into the corresponding file. These are complete, working implementations — not snippets.

| File | Source | Notes |
|---|---|---|
| `bootstrap.sh` | Appendix A | Edit `GITHUB_USER` and `DOTFILES_REPO` at the top |
| `setup-base.sh` | Appendix K (§K.5) | No edits needed |
| `setup-desktop.sh` | Appendix L (§L.4) | No edits needed |

Make them executable:

```bash
chmod +x bootstrap.sh setup-base.sh setup-desktop.sh
```

**Edit `bootstrap.sh`** — open it and set the two variables at the top:

```bash
GITHUB_USER="yourusername"                              # ← your GitHub username
DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"  # ← your PRIVATE dotfiles SSH URL
```

> [!important] `DOTFILES_REPO` must point to your private `dotfiles` repository using the SSH URL format (`git@github.com:...`), not the HTTPS format (`https://github.com/...`). The bootstrap clones this repository using SSH — the SSH URL is required.

Verify none are empty:

```bash
wc -l bootstrap.sh setup-base.sh setup-desktop.sh
```

Expected: all three show non-zero line counts.

---

### M.4 Commit and Push `workstation-scripts`

```bash
git add .
git commit -m "chore: initial setup scripts"
git push
```

**Verify the raw URL works** — this is the exact URL a new machine will use:

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh | head -3
```

Expected output: the first three lines of `bootstrap.sh` (the shebang and first comment). If you get a 404 or empty output:

- Confirm the repository is **public** (GitHub → Settings → General → Danger Zone → Change visibility)
- Confirm the file is at the **repository root** (not in a subdirectory)
- Confirm you have pushed (not just committed)

---

### M.5 Create the `dotfiles` Repository

**On GitHub:**

1. Go to [github.com/new](https://github.com/new)
2. Set these values:
   - **Repository name:** `dotfiles`
   - **Visibility:** Private
   - **Initialize with README:** Yes
   - Leave everything else at defaults
3. Click **Create repository**

**Clone it locally:**

```bash
cd ~
git clone git@github.com:yourusername/dotfiles.git
cd dotfiles
```

> [!note] If you do not yet have an SSH key registered on GitHub, you will not be able to clone the private repository. That is expected — the bootstrap will generate and register your SSH key. You can create the repository on GitHub now (steps above), and clone it after the bootstrap has run and registered the key. Alternatively, generate an SSH key manually now by following §2.1 before continuing.

---

### M.6 Create the Directory Structure

```bash
cd ~/dotfiles
mkdir -p wezterm tmux nvim/lua/config nvim/lua/plugins vscode scripts xfce4
```

Create placeholder files and a `.gitignore`:

```bash
# Nix files — copy working versions from Appendix B in Step M.7
touch flake.nix home.nix

# Config files — covered in Parts 3, 4, 5 respectively
touch wezterm/wezterm.lua tmux/tmux.conf
touch scripts/sessionizer && chmod +x scripts/sessionizer

# Neovim — staged by bootstrap; placeholder only here
touch nvim/init.lua

# VS Code extensions list — covered in Part 11
touch vscode/extensions.txt

# .gitignore
cat > .gitignore << 'EOF'
# Local secrets — never commit
.env
.env.*

# macOS metadata
.DS_Store

# Nix build artefacts
result
result-*
EOF
```

---

### M.7 Populate `flake.nix` and `home.nix`

Open Appendix B and copy both complete files. These are the most important files in your dotfiles — they declare your entire user environment.

Before saving, substitute your Linux username in both files:

```bash
whoami   # prints your username — use this value below
```

Every occurrence of `yourusername` in both files must be replaced with the output of `whoami`. A mismatch causes the Home Manager step of the bootstrap to fail with a configuration error.

Verify neither is empty:

```bash
wc -l flake.nix home.nix   # both must be non-zero
```

> [!tip] **The remaining config files** (`wezterm.lua`, `tmux.conf`, `sessionizer`) can stay as empty placeholders for now. The bootstrap symlinks them into place — the symlinks will exist pointing to empty files, and WezTerm and tmux will use their defaults. You populate them as you work through Parts 3, 4, and 5. If you want a fully working environment immediately after the bootstrap, copy the reference configs from Appendix F (WezTerm), Appendix E (tmux), and Part 5 §5.5 (sessionizer) now.

---

### M.8 Commit and Push `dotfiles`

```bash
cd ~/dotfiles
git add .
git commit -m "chore: initial dotfiles structure"
git push
```

Verify the push succeeded:

```bash
git log --oneline
```

Expected output:

```
a1b2c3d chore: initial dotfiles structure
b4e5f6a Initial commit
```

> [!note] Your `dotfiles` repository is private — it will not be visible in a browser unless you are logged into your GitHub account. That is correct. Its contents are never accessed by `curl` — only by `git clone` via SSH after the bootstrap has registered your key.

---

### M.9 What You Now Have

At this point:

- `workstation-scripts` is public on GitHub, contains three working scripts, and is fetchable by any machine via `curl`
- `dotfiles` is private on GitHub, contains your Nix environment declaration, and is clonable via SSH

The full setup sequence from here is:

```
Any new machine:
  wget → setup-base.sh          # installs apt prerequisites
  [manual] ssh-keygen + register key on GitHub
  wget → bootstrap.sh           # installs the environment (fully unattended)
    └── verifies SSH key        # exits with instructions if missing
    └── git clone dotfiles      # pulls your private config
    └── hms     # builds the environment
```

You are ready to go to Part 1 (or skip straight to §2.4 if you prefer to read while the bootstrap runs).

---

### M.10 Managing the Repositories Going Forward

**The Edit → Apply → Verify → Commit loop** (§1.11) applies to both repositories:

For `dotfiles/`:

```bash
# Edit: change home.nix, wezterm.lua, tmux.conf, etc.
# Apply: hms (for home.nix) or SUPER+SHIFT+R (for wezterm.lua) etc.
# Verify: confirm the change works
cd ~/dotfiles && git add -A && git commit -m "description" && git push
```

For `workstation-scripts/`:

```bash
# Edit: improve bootstrap.sh, setup-base.sh, or setup-desktop.sh
# Verify: test on a spare machine or VM before pushing
cd ~/workstation-scripts && git add -A && git commit -m "description" && git push
```

> [!tip] **Changes to `workstation-scripts` take effect immediately on the next `curl` fetch** — there is no caching. If you push an improved `bootstrap.sh`, the next time you run the bootstrap command on a new machine, it uses the new version. This is why verifying changes on a test machine before pushing is a good habit.

**Keeping the repositories in sync:**

The bootstrap script hardcodes `GITHUB_USER` and `DOTFILES_REPO`. If you ever rename the `dotfiles` repository or change your GitHub username, update `bootstrap.sh` in `workstation-scripts` and push.

**New machine setup — always two commands:**

```bash
bash <(wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/setup-base.sh)
bash <(wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh)
```

The first installs apt prerequisites. The second does everything else. Both are idempotent.
