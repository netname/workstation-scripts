> **Development Workstation** · [Overview](0-Overview.md) · [Stack](1-Stack.md) · **Installation** · [Terminal](3-Terminal.md) · [Projects](4-Projects.md) · [Editors](5-Editors.md) · [Desktop](6-Desktop.md) · [Troubleshooting](7-Troubleshooting.md) · [Workflows](8-DevWorkflows.md)

---

## Part 2: Installation — From Zero to Working Workstation

> [!note] **Already have repositories and a dotfiles repo?** Skip to §2.4 (the bootstrap step). This document spends most of its length creating repositories and populating templates for first-time setup.

---

### 2.1 What You Need Before Starting

> [!tip] **📋 Scripts available for this section.** `scripts/bootstrap.sh` installs the full environment including its own prerequisites — no pre-step needed. Fetch it via `curl` on any fresh Ubuntu machine. If you have not yet created your repositories, see the Creating Your Repositories section below first.

**Hardware and OS:**

- A machine running Ubuntu 22.04 or 24.04 (fresh install strongly preferred)
- Internet access
- `sudo` rights

> [!note] **Haven't created your repositories yet?** See the Creating Your Repositories section below first — it walks through creating both the public `workstation-scripts` and private `dotfiles` repositories. If you have already done that, continue here.
>
> **Don't have a machine yet?** See the Getting a Machine section below for a short routing guide covering all starting points: existing Ubuntu, fresh server, VMware VM, or cloud instance.

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

> [!note] **`git` binary vs. git configuration.** The `git` binary is installed by the bootstrap before it clones your dotfiles repository. All git *configuration* — your identity (`user.name`, `user.email`), `init.defaultBranch`, delta as pager, and aliases — is managed by Home Manager via `home.nix` and applied during Step 5 of the bootstrap. Do not configure git manually before the bootstrap; Home Manager handles it declaratively.

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
> The bootstrap will not remove existing tools, but Nix and Home Manager will prepend to `$PATH`, which usually shadows conflicting versions. If you encounter issues during or after the bootstrap, [7-Troubleshooting.md](7-Troubleshooting.md) has per-tool troubleshooting entries.

---

## Getting a Machine — Where to Start

Before the bootstrap can run, you need exactly one thing: a machine with Ubuntu 22.04 or 24.04, internet access, and `sudo` rights. How you get there does not matter — the Nix bootstrap is identical on bare metal, a VM, a cloud VPS, or WSL2. This appendix routes you to the right starting point.

> [!note] **The development environment does not require a desktop.** Nix, Home Manager, tmux, and Neovim all run headlessly over SSH. A desktop is a separate optional layer, covered in [6-Desktop.md](6-Desktop.md), that is useful if you need GUI applications or remote graphical access via RDP. You can install the desktop before or after the bootstrap, or not at all. The stack is the same either way.

---

### J.1 Prepare Any Ubuntu Machine

Whether your Ubuntu machine is brand new or has been running for months, the preparation is the same commands. `apt install` is idempotent — it skips packages that are already installed, so there is no risk in running this on an existing system.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git openssh-client build-essential \
  ca-certificates gnupg unzip xz-utils
```

That is the entire machine preparation for the development environment. The bootstrap handles everything else.

**If you also want a graphical desktop:** see [6-Desktop.md](6-Desktop.md) — but complete the bootstrap first. The desktop can be added at any time and does not interact with the Nix layer.

**If you are on VMware Workstation specifically:** see the VMware section below for bridged networking, VMware Tools, and the snapshot workflow. Then come back here.

---

### J.2 Getting the Bootstrap onto a Fresh Machine

The commands in §J.1 are short enough to type manually. Once your `workstation-scripts` repository is created, `bootstrap.sh` installs its own prerequisites — just fetch it directly:

```bash
wget -qO bootstrap.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh
bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
```

Replace `yourusername` with your GitHub username. The script is idempotent — safe to re-run.

> [!note] `scripts/bootstrap.sh` lives in `workstation-scripts` (public), not `dotfiles` (private). `wget` can fetch it anonymously — no SSH key or credentials needed on the new machine. See the Creating Your Repositories section below (§M.1) for the full explanation of the two-repository split.

If you have not yet created your repositories, go to the Creating Your Repositories section below first.

---

### J.3 Decision Summary

| Your situation | What to do |
|---|---|
| Haven't created repositories yet | Creating Your Repositories section first — creates `workstation-scripts` + `dotfiles` |
| Any Ubuntu machine (new or existing) | Commands in §J.1, then Part 1 |
| VMware Workstation | VMware section below first, then §J.1, then Part 1 |
| Want a graphical desktop | Bootstrap first (Part 2), then [6-Desktop.md](6-Desktop.md) |
| Unsure whether you need a desktop | Bootstrap first — desktop can be added later |

---

## VMware Workstation — Platform-Specific Setup

This appendix covers the VMware-specific setup steps: bridged networking, Ubuntu Server installation, VMware Tools, and the snapshot workflow. These steps are specific to VMware Workstation. If you are on another platform (bare metal, VirtualBox, Hyper-V, cloud), skip this appendix and use the Getting a Machine section above (§J.2) instead.

> [!note] **What this appendix does and does not cover**
> This appendix gets you to a clean Ubuntu Server with network access and VMware Tools installed. It does not install a desktop environment — that is in Appendix L, and is optional. After completing this appendix, go to **Part 1**.

---

### §1 VMware Network Configuration

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

### §2 Install Ubuntu Server 24.04 LTS

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

> [!note] `git` is included here only so you can clone and author your repositories before the bootstrap runs. On the target machine, the bootstrap installs `git` itself before cloning dotfiles. All meaningful git configuration — identity, aliases, delta pager — is managed by Home Manager via `home.nix` during the bootstrap, not here.

---

---

### §3 VMware Tools

```bash
sudo apt install -y open-vm-tools open-vm-tools-desktop
sudo reboot
```

**Why this matters:**

* Correct display resolution in the VMware window
* Clipboard sharing between host and VM
* Smooth mouse input without capture/release friction

---

> [!note] **Why no reboot here?** VMware Tools installs correctly without a reboot. Full clipboard integration and display resolution adjustment require a reboot, but those only matter if you are adding a desktop ([6-Desktop.md](6-Desktop.md)). If you are running headless, skip the reboot until after the Nix bootstrap is complete.

---

### §4 Take a Snapshot

> [!tip] Take a VMware snapshot immediately after completing A.5. This is your clean-slate checkpoint — before Nix touches anything.

VMware → **VM → Snapshot → Take Snapshot**

Name it something dated and unambiguous:

```
Host OS ready — YYYY-MM-DD
```

If the Nix installation later goes wrong, you can revert to this snapshot and start the bootstrap again without repeating A.0–A.5.

---

---

### §5 Bootstrap Script — Prerequisites

`scripts/bootstrap.sh` installs all system prerequisites (git, curl, zsh, build-essential, etc.) as its first step. No separate pre-script is needed.

Once your `workstation-scripts` repository is created and pushed (Creating Your Repositories section below), fetch and run the bootstrap directly:

```bash
wget -qO bootstrap.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh
bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
```

The bootstrap is idempotent — safe to re-run. See the Bootstrap Script section below for the full script contents.

---

### §6 Installation Order Reference (VMware path)

| Step | Action | How |
|---|---|---|
| §1 | VMware Bridged networking | Manual (before creating VM) |
| §2 | Ubuntu Server installation | Manual |
| §2 | Base packages | Manual (bootstrap.sh installs them as its first step) |
| §3 | VMware Tools | `sudo apt install -y open-vm-tools` |
| §4 | Snapshot | Manual (VMware UI) |
| — | **Go to Part 1** | Main guide |
| — | *(Optional)* Desktop environment | [6-Desktop.md](6-Desktop.md) |

---

## Creating Your GitHub Repositories

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
  └── scripts/bootstrap.sh      ← fetched by curl on any new machine
  └── scripts/setup-desktop.sh  ← fetched by curl to add the desktop layer
  └── templates/                ← starter Nix config files (copy into dotfiles)

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
| `scripts/bootstrap.sh` | Bootstrap Script section below | No edit required; pass `--github-user` and `--dotfiles-repo` when running |
| `scripts/setup-desktop.sh` | [6-Desktop.md §L.4](6-Desktop.md) | No edits needed |

Make them executable:

```bash
chmod +x scripts/bootstrap.sh scripts/setup-desktop.sh
```

**Edit `bootstrap.sh`** — open it and set the two variables at the top:

```bash
GITHUB_USER="yourusername"                              # ← your GitHub username
DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"  # ← your PRIVATE dotfiles SSH URL
```

> [!important] `DOTFILES_REPO` must point to your private `dotfiles` repository using the SSH URL format (`git@github.com:...`), not the HTTPS format (`https://github.com/...`). The bootstrap clones this repository using SSH — the SSH URL is required.

Verify they are not empty:

```bash
wc -l scripts/bootstrap.sh scripts/setup-desktop.sh
```

Expected: both show non-zero line counts.

---

### M.4 Commit and Push `workstation-scripts`

```bash
git add .
git commit -m "chore: initial setup scripts"
git push
```

**Verify the raw URL works** — this is the exact URL a new machine will use:

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh | head -3
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

> [!note] If you do not yet have an SSH key registered on GitHub, you will not be able to clone the private repository. That is expected. Create the repository on GitHub now, then generate and register the SSH key by following §2.1 before cloning or running the bootstrap. The bootstrap verifies the key and prints recovery instructions if it is missing, but it does not create or register keys for you.

---

### M.6 Create the Directory Structure

```bash
cd ~/dotfiles
mkdir -p wezterm tmux nvim/lua/config nvim/lua/plugins vscode scripts xfce4
```

Create placeholder files and a `.gitignore`:

```bash
# Nix files — copy working versions from the Reference Files section below in Step M.7
touch flake.nix home.nix

# Config files — covered in Parts 3, 4, 5 respectively
touch wezterm/wezterm.lua tmux/tmux.conf
touch scripts/sessionizer && chmod +x scripts/sessionizer

# Neovim — staged by bootstrap; placeholder only here
touch nvim/init.lua

# VS Code extensions list — covered in Part 11
cat > vscode/extensions.json << 'EOF'
{
  "recommendations": [
    "ms-python.python",
    "ms-python.debugpy",
    "charliermarsh.ruff",
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "mkhl.direnv",
    "ms-azuretools.vscode-docker",
    "eamodio.gitlens",
    "redhat.vscode-yaml",
    "tamasfe.even-better-toml",
    "yzhang.markdown-all-in-one",
    "bierner.markdown-mermaid"
  ]
}
EOF

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

### M.7 Populate `flake.nix`, `home.nix`, and `sessionizer`

The `workstation-scripts` repository ships three starter templates for the files your dotfiles repo needs on day one. Copy them now:

```bash
cd ~/dotfiles

# Copy the starter files from your workstation-scripts checkout
cp ~/workstation-scripts/templates/flake.nix .
cp ~/workstation-scripts/templates/home.nix .
cp ~/workstation-scripts/templates/sessionizer scripts/sessionizer
chmod +x scripts/sessionizer
```

> [!note] **Don't have `workstation-scripts` cloned locally yet?** Fetch the templates directly from GitHub (replace `yourusername`):
> ```bash
> wget -qO flake.nix \
>   https://raw.githubusercontent.com/yourusername/workstation-scripts/main/templates/flake.nix
> wget -qO home.nix \
>   https://raw.githubusercontent.com/yourusername/workstation-scripts/main/templates/home.nix
> wget -qO scripts/sessionizer \
>   https://raw.githubusercontent.com/yourusername/workstation-scripts/main/templates/sessionizer
> chmod +x scripts/sessionizer
> ```

**What each file is and why it exists:**

`flake.nix` is the entry point for your Nix configuration. It declares two inputs — the nixpkgs package collection and the home-manager tool — and wires them together under your Linux username. Nix uses this file every time you run `hms` to know which nixpkgs commit to build from and which `home.nix` to load.

`home.nix` is the declaration of your entire user environment: every global CLI tool, your shell initialisation order, your git identity, your prompt, and the hooks that glue direnv and fzf into the shell. Home Manager reads this file and produces a concrete, reproducible environment from it. Adding a tool here installs it everywhere; removing it uninstalls it.

`sessionizer` is the tmux project switcher — a small bash script that presents your project directories in fzf, then creates or switches to a tmux session rooted in the selected directory. The bootstrap symlinks it to `~/.local/bin/sessionizer` so it is on your `$PATH`. The tmux binding `bind -n C-f display-popup -E "~/.local/bin/sessionizer"` (added in Part 4) makes it a single keypress. §5.5 walks through every line.

---

**Substitute your Linux username.** Both Nix files contain `CHANGE_ME` placeholders. The key in `flake.nix` and the `home.username` value in `home.nix` must both match the exact output of `whoami` — not your GitHub username, not your display name, your Linux login name:

```bash
whoami   # prints your username
```

Replace all occurrences in one pass:

```bash
USERNAME=$(whoami)
sed -i "s/CHANGE_ME/$USERNAME/g" flake.nix home.nix
```

> [!important] **A mismatch causes bootstrap failure.** If the key in `flake.nix` (`homeConfigurations."yourname"`) does not match the `home.username` value in `home.nix`, or if either does not match the output of `whoami`, the Home Manager step fails with `error: attribute 'yourname' missing`. The `sed` command above replaces every occurrence in both files at once.

**Set your git identity.** `home.nix` still has two placeholders that `sed` cannot fill in automatically — your real name and email for git commits:

```bash
nvim home.nix   # or any editor
```

Find the `programs.git.settings` block and fill in your values:

```nix
user = {
  name  = "CHANGE_ME";              # ← your full name, e.g. "Jane Smith"
  email = "CHANGE_ME@example.com";  # ← the email registered on your GitHub account
};
```

These values end up in every `git commit` you make. Home Manager writes them to `~/.config/git/config` — never run `git config --global` manually, it writes to the same file and `hms` will overwrite it.

**Verify all three files have content:**

```bash
wc -l flake.nix home.nix scripts/sessionizer   # all must be non-zero
```

> [!tip] **The remaining config files** (`wezterm.lua`, `tmux.conf`) can stay as empty placeholders for now. The bootstrap symlinks them into place — WezTerm and tmux will use their built-in defaults until you populate them. You do that in Parts 3 and 4. For a full explanation of what every block in `flake.nix` and `home.nix` does and why it is structured the way it is, read the **Understanding your `flake.nix` and `home.nix`** section below before running the bootstrap.

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
  [manual] ssh-keygen + register key on GitHub
  wget → scripts/bootstrap.sh   # installs prerequisites + the full environment (fully unattended)
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
# Edit: improve scripts/bootstrap.sh or scripts/setup-desktop.sh
# Verify: test on a spare machine or VM before pushing
cd ~/workstation-scripts && git add -A && git commit -m "description" && git push
```

> [!tip] **Changes to `workstation-scripts` take effect immediately on the next `curl` fetch** — there is no caching. If you push an improved `bootstrap.sh`, the next time you run the bootstrap command on a new machine, it uses the new version. This is why verifying changes on a test machine before pushing is a good habit.

**Keeping the repositories in sync:**

The bootstrap accepts `GITHUB_USER`, `DOTFILES_REPO`, `DOTFILES_DIR`, and `SSH_KEY_PATH` as environment variables or command-line flags. If you rename the `dotfiles` repository or change your GitHub username, pass the new values when you run the bootstrap, or update any wrapper command you keep in your notes.

**New machine setup — one command:**

```bash
wget -qO bootstrap.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh
bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
```

The bootstrap installs its own prerequisites and does everything else. It is idempotent.

---

### 2.2 The Dotfiles Repository: Your Environment's Source of Truth

The dotfiles repository is a Git repository, hosted on GitHub, that contains every configuration file for your workstation. It is the source of truth: the machine is a reflection of the repository, not the other way around. The bootstrap script clones this repository to `~/dotfiles` and builds your entire environment from its contents.

This repository is also what makes a new machine setup a single command: you clone the repository and run the bootstrap. The bootstrap reads the repository and produces your workstation.

> [!important] The repository must exist before the bootstrap runs The bootstrap installs prerequisites first, then clones your dotfiles repository. If the repository does not exist or does not have the required file structure, the bootstrap will fail at the clone or Home Manager step. Complete §2.3 fully before attempting the bootstrap.

#### The Required Directory Structures

Each repository has required files. The bootstrap script references these paths by name — a missing file causes a named, diagnosable failure.

**`workstation-scripts/` (public repo):**

```
workstation-scripts/
  scripts/
    bootstrap.sh               # Main bootstrap — installs the full dev environment
    setup-desktop.sh           # Optional desktop — XFCE4 + XRDP + WezTerm + VS Code + ksnip (see 6-Desktop.md)
  templates/
    flake.nix                  # Starter Home Manager flake — copy into dotfiles/
    home.nix                   # Starter user environment declaration — copy into dotfiles/
    devenv.nix                 # Starter per-project environment — copy into project root
    docker-compose.yml         # Starter MariaDB + Redis services — copy into project root
    sessionizer                # tmux project switcher — copy into dotfiles/scripts/
```

These files have no personal data. Anyone can read them. Their purpose is to be fetchable by a new machine with nothing installed, and to give new adopters a working starting point for their dotfiles.

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
    extensions.json            # VS Code recommended extensions — install manually after setup (see §11.3)
  scripts/
    sessionizer                # tmux project session manager script
  xfce4/
    xfce4-keyboard-shortcuts.xml  # XFCE tiling shortcuts backup (§L.3.5, optional)
```

This repository contains your identity and preferences. Keep it private.

**What each file is for:**

`flake.nix` is the entry point for the Nix build. It does two things: it declares _inputs_ (which version of nixpkgs and Home Manager to use), and it declares _outputs_ (your Home Manager configuration, identified by your username). When you run `hms --flake ~/dotfiles#yourusername`, Nix reads this file to know which version of Home Manager to use, which version of nixpkgs to resolve packages from, and which configuration to apply (the one identified by `yourusername`). The `flake.lock` file that accompanies it records the exact Git commit hashes for all declared inputs — this is what makes two machines with the same `flake.lock` produce identical environments. Full reference in the Reference Files section below.

`home.nix` is the declaration of your user environment: every global CLI tool, your shell configuration, your git config, your prompt. Think of it as a complete, machine-readable description of what your workstation should look like. When Home Manager evaluates it, it translates every declaration into concrete actions: downloading packages to `/nix/store`, generating `~/.zshrc` from your shell configuration, creating symlinks from generated files into your home directory. The file is structured as a Nix attribute set — keys like `home.packages`, `programs.zsh`, `programs.git`, and `programs.starship` each configure a different aspect of your environment. This is the file you edit most often. Full reference in the Reference Files section below.

`scripts/bootstrap.sh` is the script covered in Part 2. It reads `flake.nix` and `home.nix` to build your environment via Home Manager, then handles the tools that cannot be managed by Nix (Docker via apt). GUI tools (WezTerm, VS Code, Chrome, ksnip) are installed separately by `scripts/setup-desktop.sh` and are not part of the bootstrap.

`wezterm/wezterm.lua` is your WezTerm configuration. It is symlinked to `~/.config/wezterm/wezterm.lua` by `setup-desktop.sh`. You edit this file directly and reload with `SUPER+SHIFT+R`. Covered in Part 3.

`tmux/tmux.conf` is your tmux configuration. It is symlinked to `~/.config/tmux/tmux.conf` via `mkOutOfStoreSymlink` in `home.nix` — a Home Manager helper that creates a symlink pointing directly at `~/dotfiles/tmux/tmux.conf` instead of copying the file into the read-only `/nix/store`. This means TPM can write plugin state at runtime (the symlink target stays mutable). You edit this source file directly and reload with `prefix r` — no `hms` required. Plugins are managed by TPM (`~/.tmux/plugins/tpm`); install them inside tmux with `Ctrl-Space I`. Covered in Part 3.

`nvim/` starts as a placeholder directory. The bootstrap stages the LazyVim starter into it during step 10 and runs a headless plugin sync in step 11 (§2.4.3). After that, it is a mutable directory containing your Neovim/LazyVim configuration. It is symlinked to `~/.config/nvim/` via the `mkOutOfStoreSymlink` pattern in `home.nix`. Covered in Part 3.

`vscode/extensions.json` uses VS Code's native recommendations format. You install these manually after the desktop setup — see [5-Editors.md §11.3](5-Editors.md).

`scripts/sessionizer` is the project session manager script. It is symlinked to `~/.local/bin/sessionizer` by the bootstrap and bound to `Ctrl-f` in tmux. Covered in Part 3.

`scripts/bootstrap.sh` installs all apt prerequisites and then the full environment in one run. It is the single script to fetch on any new machine.

`scripts/setup-desktop.sh` installs the optional desktop layer: XFCE4, LightDM, XRDP, WezTerm, VS Code, Chrome, ksnip, and the polkit shutdown rule. Run it after the bootstrap if you want a graphical environment accessible via RDP (Installation Step 5).

`xfce4/xfce4-keyboard-shortcuts.xml` is an optional backup of the XFCE4 window tiling keyboard shortcuts configured in §L.3. Not used by the bootstrap — restore manually if needed on a new desktop machine (§L.3.5).

> [!tip] `flake.nix` and `home.nix` reference Complete, working implementations of both files — not snippets — are in the Reference Files section below. Read this section to understand the structure; go to the Reference Files section below to copy the files. The appendix versions are annotated and ready to use with only your username substituted.

---

### 2.3 Creating Your Two Repositories

> [!tip] **📋 The Creating Your Repositories section above has the full repository setup walkthrough.** If you already have both repositories set up and your SSH key registered, skip to §2.4. If you are here for the first time, continue below.

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
https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh
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
mkdir -p scripts templates
```

Scripts live in `scripts/` and starter Nix config files live in `templates/` so their raw URLs are simple and predictable.

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
mkdir -p scripts templates

# Scripts — NOT placeholders; copy from appendices (see Step 5)
touch scripts/bootstrap.sh scripts/setup-desktop.sh
chmod +x scripts/bootstrap.sh scripts/setup-desktop.sh
```

**In `dotfiles/`:**

```bash
cd ~/dotfiles

# Nix flake entry point — copy working version from the Reference Files section below
touch flake.nix

# Home Manager config — copy working version from the Reference Files section below
touch home.nix

# WezTerm config — covered in Part 3
touch wezterm/wezterm.lua

# tmux config — covered in Part 3
touch tmux/tmux.conf

# LazyVim entry point — staged by bootstrap in Part 2, placeholder only
touch nvim/init.lua

# VS Code extensions list — install manually after desktop setup (see 5-Editors.md §11.3)
cat > vscode/extensions.json << 'EOF'
{
  "recommendations": [
    "ms-python.python",
    "ms-python.debugpy",
    "charliermarsh.ruff",
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "mkhl.direnv",
    "ms-azuretools.vscode-docker",
    "eamodio.gitlens",
    "redhat.vscode-yaml",
    "tamasfe.even-better-toml",
    "yzhang.markdown-all-in-one",
    "bierner.markdown-mermaid"
  ]
}
EOF

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

Copy the script content from each source listed below. No personal substitutions are needed in any of these — they are generic.

| File | Source | Substitutions needed |
|---|---|---|
| `scripts/bootstrap.sh` | Bootstrap Script section below | No edit required; pass `--github-user` and `--dotfiles-repo` when running |
| `scripts/setup-desktop.sh` | [6-Desktop.md §L.4](6-Desktop.md) | None |

After copying, you do not need to edit `scripts/bootstrap.sh`. Pass your values when running it:

```bash
bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
```

These are the only lines in `scripts/bootstrap.sh` that are personal. Everything else is generic and will not need changing.

Verify they are not empty:

```bash
cd ~/workstation-scripts
wc -l scripts/bootstrap.sh scripts/setup-desktop.sh   # both must be non-zero
```

**In `dotfiles/` — two Nix files to populate:**

**`flake.nix` and `home.nix` — from the Reference Files section below:**

Open the Reference Files section below and copy both files into your repository, substituting your username where indicated.

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

Expected output: a non-zero line count. If the output is `0 flake.nix`, the file was not populated from the Reference Files section below.

Verify `home.nix` is not empty:

```bash
wc -l home.nix
```

Expected output: a non-zero line count. If the output is `0 home.nix`, the file was not populated from the Reference Files section below.

#### Step 6: Populate the Remaining Config Files

At this point, `wezterm.lua`, `tmux.conf`, and `sessionizer` are empty placeholders. The bootstrap script symlinks these files into place — the symlinks will exist, but they will point to empty files until you fill them in.

This is intentional: you can run the bootstrap with empty placeholder configs and then populate each file as you work through Parts 4, 5, and 6. WezTerm will open with its defaults, tmux will load with its defaults, and the sessionizer will not work until its script is populated.

If you want a fully working environment immediately after the bootstrap, populate these files now from the reference configs in the relevant appendices:

- `wezterm/wezterm.lua` → [3-Terminal.md — Complete wezterm.lua Reference](3-Terminal.md)
- `tmux/tmux.conf` → [3-Terminal.md — Complete tmux.conf Reference](3-Terminal.md)
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

Confirm you can see `scripts/bootstrap.sh` and `scripts/setup-desktop.sh` in the `scripts/` directory.

**Test that the raw URL works** — this is the URL a new machine will use:

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh | head -5
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

> [!important] Both repositories must be pushed before running anything on a new machine. `scripts/bootstrap.sh` and `scripts/setup-desktop.sh` are fetched from `raw.githubusercontent.com` and executed directly — a locally committed but unpushed change is invisible to `curl`. The dotfiles repo must be pushed so the bootstrap can clone it via SSH. Always `git push` in both repos before bootstrapping a new machine.

---

## Understanding your `flake.nix` and `home.nix`

You already copied these files from `templates/` in §M.7. This section explains what every block does, why it is structured the way it is, and what to watch out for when you start customising. Read it now before running the bootstrap, or return to it later when you want to understand a specific setting.

The annotated versions below are identical in structure to the templates — the difference is that the templates use `CHANGE_ME` placeholders (which you have already substituted), while the examples here use `yourusername` to show what the substituted result should look like.

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

    # ── Node.js (global) ─────────
    # Available in all shells. Project-specific Node (e.g. nodejs_24 in devenv.nix)
    # shadows this via direnv $PATH prepend, so the two versions coexist without conflict.
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

  # ── Fonts: symlink into ~/.local/share/fonts for Flatpak apps ───────────────
  # Flatpak sandboxes cannot access ~/.nix-profile/share/fonts; ~/.local/share/fonts
  # is allowed. WezTerm is installed as a Flatpak by setup-desktop.sh.
  home.file.".local/share/fonts/JetBrainsMono".source =
    "${pkgs.nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";

  programs.home-manager.enable = true;

  # ── Shell: zsh ──────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;

    # Shell initialisation — ORDER MATTERS (see 3-Terminal.md §7.4)
    initContent = ''
      # 1. PATH additions first — binaries below need to be findable
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$HOME/.nix-profile/bin:$PATH"

      # 2. Nix environment
      . "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true

      # 3. direnv hook — MUST be early (tmux fires before .zshrc finishes)
      eval "$(direnv hook zsh)"

      # 4. cd alias — MUST come before zoxide init (see 3-Terminal.md §7.4)
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

      # ── Shell utility functions ──────────────────────────────────
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

  # ── tmux config: mutable symlink outside /nix/store ────────────────────────
  # TPM writes plugin state to ~/.tmux/plugins at runtime — it needs a mutable
  # location. mkOutOfStoreSymlink creates ~/.config/tmux/tmux.conf →
  # ~/dotfiles/tmux/tmux.conf directly, bypassing the read-only /nix/store.
  # Plugins are declared and installed by TPM inside tmux.conf itself.
  home.file.".config/tmux/tmux.conf".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/dotfiles/tmux/tmux.conf";

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
      core.pager    = "delta";
      delta = {
        side-by-side  = true;
        line-numbers  = true;
        navigate      = true;
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      alias = {
        sw    = "switch";
        co    = "checkout -b";
        st    = "status --short";
        pushf = "push --force-with-lease --force-if-includes";
        lg    = "log --oneline --graph --decorate --all";
      };
    };
    # Silence the "no signing format" warning emitted by newer Home Manager versions
    signing.format = null;
  };

  # ── Starship prompt ─────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    # Minimal config — customize further to taste
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol   = "[➜](bold red)";
      };
    };
  };

  # ── State version ───────────────────────────────────────────────────────────
  # Do not change this after initial setup — it controls state migration behaviour
  home.stateVersion = "24.05";
}
```

---

### 2.4 The Bootstrap — One Command to a Working Workstation

With the dotfiles repository live on GitHub (§2.3), setting up a workstation is a single command. This section explains what the bootstrap script does, why each step is ordered the way it is, what correct completion looks like, and what to do when something goes wrong.

---

#### 2.4.1 What the Bootstrap Script Does

The bootstrap script (`bootstrap.sh`, full implementation in the Bootstrap Script section below) turns a fresh Ubuntu Desktop installation into your complete development workstation. It is designed around two properties that make it safe to run in any situation:

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
| Step 1 | System dependencies | Installs `git`, `curl`, `wget`, `openssh-client`, `zsh`, `build-essential`, `xz-utils`, and related apt packages; sets zsh as the login shell |
| Step 2 | Verify SSH key | Confirms `~/.ssh/id_ed25519` exists and is authenticated with GitHub — exits with error if missing |
| Step 3 | Clone dotfiles | Clones your private dotfiles repository to `~/dotfiles` |
| Step 4 | Install Nix | Installs Nix via the Determinate Systems installer |
| Step 5 | Apply Home Manager | Builds your full user environment — installs all global CLI tools, JetBrainsMono Nerd Font, and owns git identity, delta pager, and aliases |
| Step 6 | Install Docker Engine | Adds the official apt repository, installs Docker Engine, adds user to `docker` group |
| Step 7 | Verify GitHub CLI | Confirms `gh` is available (Home Manager installs it; apt is the fallback) |
| Step 8 | Configure GitHub CLI | Sets `gh` git protocol to SSH and pager to delta when available |
| Step 9 | Symlink dotfiles | Creates the sessionizer symlink |
| Step 10 | Stage LazyVim | Copies LazyVim starter into `~/dotfiles/nvim/` |
| Step 11 | LazyVim headless sync | Installs all LazyVim plugins without opening Neovim |

> [!note] **GUI tools (WezTerm, VS Code, Chrome, ksnip) are installed by `setup-desktop.sh`**, not by the bootstrap. The bootstrap is headless-safe and runs identically on a server or desktop VM.

**Total duration:** 20–40 minutes on first run, depending on internet speed. The majority of the time is Nix downloading packages during step 5.

> [!important] Run the bootstrap only after completing §2.3 The script clones your dotfiles repository at step 3. If the repository does not exist on GitHub, or if `flake.nix` and `home.nix` are empty placeholders, the bootstrap will fail at steps 3 or 5 respectively. Complete Part 2 — including pushing to GitHub — before proceeding.

---

#### 2.4.2 Running the Bootstrap

> [!tip] **📋 Script available.** The bootstrap is `bootstrap.sh` in your public `workstation-scripts` repository. If you created and registered your SSH key in §2.1, the bootstrap runs fully automatically with no pauses. Re-running is safe — it is idempotent.

> [!tip] First time running this? Read §2.4.3 before executing the command below. §2.4.3 walks through every step the script performs, explains what correct output looks like, and covers all known failure modes. Knowing what to expect makes it much easier to diagnose a failure if one occurs — and you will know exactly which step to look up rather than searching through shell output.

On your fresh Ubuntu installation, open a terminal and run:

```bash
wget -qO bootstrap.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh

bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
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
▶ Installing Docker Engine
▶ Verifying GitHub CLI
▶ Configuring gh (pager + git protocol)
▶ Symlinking user-managed dotfiles
▶ Staging LazyVim starter
▶ Running LazyVim headless plugin sync
✔ Headless bootstrap complete.
```

**If the script stops with an error:** The error message names the step. Find the matching step in §2.4.3, read the failure output description, and follow the resolution. Every expected failure mode is covered there.

---

#### 2.4.3 What the Script Does, Step by Step

This section walks through every step of the bootstrap in the order the script executes them. For each step: what is being installed, why it is needed, what the idempotency check looks like, and what correct completion output looks like.

The full script is in the Bootstrap Script section below. This section describes each step in prose so you understand what is happening and can diagnose failures without reading shell code.

> [!important] **The SSH key must exist before running the bootstrap.** The bootstrap verifies that `~/.ssh/id_ed25519` is present and that `ssh -T git@github.com` succeeds. If the key is missing, the script exits immediately (code 1) and prints the `ssh-keygen` command and registration instructions — there is no generation, no pause, and no interactive prompt. Complete the SSH key setup in §2.1, then re-run.

---

#### Step 1: Install System Dependencies

**Pre-flight (before Step 1):** Before any `sudo` call, the script creates user-owned XDG directories: `~/.config/git`, `~/.config/tmux`, `~/.local/bin`, and `~/.ssh`. This prevents `apt` or `gpg` from implicitly creating `~/.config` owned by root, which would cause "Permission denied" errors in later user-space writes.

**What:** Installs `git`, `curl`, `wget`, `openssh-client`, `zsh`, `build-essential`, and `xz-utils` via `apt`. Then sets zsh as your login shell via `usermod`.

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

The script then exits with code 1. Complete the SSH key setup in §2.1 and re-run.

**Idempotency:** Pre-seeding `known_hosts` is idempotent (same entry can appear multiple times safely). The SSH check itself is a read-only operation.

**Correct completion:** `✓ SSH key verified – GitHub authentication successful`

---

#### Step 3: Clone or Refresh the Dotfiles Repository

**What:** Clones `git@github.com:yourusername/dotfiles.git` to `~/dotfiles`. If `~/dotfiles` already exists (re-run scenario), the bootstrap checks whether the working tree is clean before fetching `origin/main`.

**Why here:** All subsequent steps read files from `~/dotfiles`. The Home Manager step reads `flake.nix` and `home.nix`. The symlink step reads `wezterm/wezterm.lua`, `tmux/tmux.conf`, and `scripts/sessionizer`. Nothing can proceed until the repository is local.

**Idempotency:** Checks for the existence of `~/dotfiles` before cloning. On re-run, a clean checkout fast-forwards to `origin/main`. A dirty checkout stops with instructions so local edits are not lost. If you intentionally want to discard local dotfiles changes, re-run with `--force-reset`.

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

#### Step 7: Verify GitHub CLI

**What:** Verifies that `gh` is available on `$PATH`. If it is not (edge case where the Home Manager PATH has not propagated), installs `gh` via the official apt repository as a fallback.

**Why verify rather than install:** `gh` is declared in `home.nix` packages and is installed by Home Manager in step 5. On a clean run, it is already available and this step completes in under a second. The apt install is the fallback for the rare case where `gh` is not yet findable via `$PATH` after the Home Manager switch.

> [!tip] If `gh` was installed by Home Manager in step 5, this step's idempotency check (`command -v gh`) fires immediately and the step takes less than a second.

---

#### Step 8: Configure GitHub CLI

**What:** Configures GitHub CLI to use SSH remotes and sets the `gh` pager to delta when delta is available.

**Why configure gh separately from git:** Git's pager (`core.pager`) and gh's pager are independent settings. Home Manager's `programs.git` manages the git pager via `home.nix`. The gh pager is a runtime config value (`~/.config/gh/config.yml`) that Home Manager does not expose as a declarative option — it must be set imperatively. Both settings are required to get delta-highlighted diffs everywhere.

**Why set `git_protocol` to SSH:** This makes `gh repo clone` create SSH remotes instead of HTTPS remotes, matching the dotfiles bootstrap path and avoiding token prompts on push.

---

#### Step 9: Symlink User-Managed Dotfiles

> [!important] **This step must run before LazyVim (steps 10–11).** The sessionizer symlink is independent of LazyVim, but it belongs before editor setup so all user-managed command shims are in place before the final verification steps.

**What:** Creates one symlink:

```
~/dotfiles/scripts/sessionizer  →  ~/.local/bin/sessionizer
```

**Why `~/.local/bin/` for the sessionizer:** `~/.local/bin/` is the standard per-user executable directory on Ubuntu. Home Manager adds it to `$PATH` via `home.nix`. Once the symlink exists, `sessionizer` is available as a command from anywhere.

**tmux and WezTerm configs:** `~/.config/tmux/tmux.conf` is symlinked by Home Manager (`home.file.mkOutOfStoreSymlink`) to `~/dotfiles/tmux/tmux.conf` — no manual symlink is needed. `~/.config/wezterm/wezterm.lua` is symlinked by `setup-desktop.sh`, not the bootstrap.

**Idempotency:** Uses `ln -sf` (force), which overwrites an existing symlink with the correct target. Safe to re-run.

---

#### Step 10: Stage LazyVim Starter

**What:** Clones the LazyVim starter repository to `/tmp/lazyvim-starter`, copies its contents into `~/dotfiles/nvim/`, and removes the `.git` directory from the copy.

**Why copy rather than clone into place:** Cloning the starter directly into `~/dotfiles/nvim/` would create a nested git repository, which breaks git operations in the outer `~/dotfiles` repository. Copying the files and removing `.git` gives you the LazyVim starter as plain files that are tracked by your dotfiles repository.

**The `mkOutOfStoreSymlink` connection:** `home.nix` declares `home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/nvim"`. This means Home Manager created `~/.config/nvim` as a symlink pointing to `~/dotfiles/nvim/` during step 5. After step 10 populates that directory, Neovim can find its configuration immediately.

**Idempotency:** Checks whether `~/dotfiles/nvim/init.lua` exists and is non-empty before cloning. If it is already populated (re-run or manual setup), this step is skipped.

---

#### Step 11: Run LazyVim Headless Plugin Sync

**What:** Runs `nvim --headless "+Lazy! sync" +qa` to install all LazyVim plugins without opening an interactive Neovim session.

**Why headless sync during bootstrap:** Without this step, the first time you open Neovim, LazyVim downloads all its plugins interactively while you watch. This takes 1–3 minutes and produces a screen full of progress output before the editor is usable. Running the sync headlessly during bootstrap means the first manual Neovim open is fully ready with all plugins installed and no waiting.

**What correct output looks like:** The command runs silently for 1–3 minutes and returns to the shell prompt. It does not print progress to the terminal (headless mode suppresses UI output). If it returns immediately (under 5 seconds), something went wrong — check that `~/dotfiles/nvim/init.lua` exists and is not empty.

**Idempotency:** Headless sync is safe to re-run; it installs missing plugins and updates any that have changed since the last sync.

---

---

## Bootstrap Script (Authoritative Copy)

Save this file as `scripts/bootstrap.sh` in your **public** `workstation-scripts` repository. The script is idempotent — safe to re-run if it stops partway through.

> [!important] No script edits required. Pass `--github-user`, `--dotfiles-repo`, `--dotfiles-dir`, or `--ssh-key-path` when running the script, or set the matching environment variables. The script refuses to run with missing or example placeholder values.

```bash
#!/usr/bin/env bash
# bootstrap.sh
# Idempotent workstation setup script.
# Lives in: workstation-scripts/scripts/ (PUBLIC repo) – fetched via curl
# Run with:
#   wget -qO bootstrap.sh https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh
#   bash bootstrap.sh --github-user yourusername --dotfiles-repo git@github.com:yourusername/dotfiles.git
#
# What this script does (headless-safe — no display required):
#   1.  Installs system dependencies and sets zsh as the login shell
#   2.  Verifies the SSH key is present and authenticated with GitHub
#   3.  Clones your PRIVATE dotfiles repo via SSH
#   4.  Installs Nix (Determinate Systems installer)
#   5.  Applies Home Manager from your flake (owns git identity, delta config,
#         git aliases, zsh, starship, direnv, fzf, JetBrainsMono
#         Nerd Font, and all CLI packages declared in home.nix)
#   6.  Installs Docker Engine
#   7.  Verifies GitHub CLI (installed by Home Manager; apt fallback)
#   8.  Configures gh pager (delta – not manageable via Home Manager)
#   9.  Symlinks user-managed dotfiles (sessionizer)
#   10. Stages LazyVim starter into dotfiles
#   11. Runs LazyVim headless plugin sync when Neovim is available
#
# GUI-only tools (WezTerm, VS Code, Chrome, ksnip) are installed by scripts/setup-desktop.sh.
# Run setup-desktop.sh after this script if you want a graphical environment.
#
# NOTE: git identity, delta pager, aliases, and JetBrainsMono
# Nerd Font are managed entirely by Home Manager via home.nix. The bootstrap
# script does NOT write any git config or install fonts manually. Tmux plugins
# are declared in tmux.conf and installed by TPM when tmux loads that config.
#
# PREREQUISITE: Generate and register your SSH key on GitHub before running
# this script. The bootstrap runs fully automatically with no pauses once the
# key is in place.

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "${GREEN}▶ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $1${NC}"; }
ok()    { echo -e "${GREEN}✓ $1${NC}"; }
die()   { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

# ── Variables ─────────────────────────────────────────────────────────────────
# Example values:
#   GITHUB_USER="yourusername"
#   DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"
#
# Prefer environment variables or flags over editing this script:
#   GITHUB_USER=octocat DOTFILES_REPO=git@github.com:octocat/dotfiles.git bash bootstrap.sh
GITHUB_USER="${GITHUB_USER:-}"
DOTFILES_REPO="${DOTFILES_REPO:-}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
FORCE_RESET=false
# Linux login name — must match the homeConfigurations key in flake.nix.
# Usually your Linux username (whoami), which may differ from GITHUB_USER.
LINUX_USER="$(whoami)"

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [options]

Options:
  --github-user USER       GitHub username used for URLs and SSH hints
  --dotfiles-repo URL      Private dotfiles SSH URL (git@github.com:USER/dotfiles.git)
  --dotfiles-dir PATH      Local dotfiles checkout path (default: ~/dotfiles)
  --ssh-key-path PATH      SSH private key path (default: ~/.ssh/id_ed25519)
  --force-reset            Discard local dotfiles changes and reset to origin/main
  -h, --help               Show this help

Environment variables with the same names are also supported:
  GITHUB_USER, DOTFILES_REPO, DOTFILES_DIR, SSH_KEY_PATH
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --github-user)
            [ "$#" -ge 2 ] || die "--github-user requires a value"
            GITHUB_USER="$2"
            shift 2
            ;;
        --dotfiles-repo)
            [ "$#" -ge 2 ] || die "--dotfiles-repo requires a value"
            DOTFILES_REPO="$2"
            shift 2
            ;;
        --dotfiles-dir)
            [ "$#" -ge 2 ] || die "--dotfiles-dir requires a value"
            DOTFILES_DIR="$2"
            shift 2
            ;;
        --ssh-key-path)
            [ "$#" -ge 2 ] || die "--ssh-key-path requires a value"
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --force-reset)
            FORCE_RESET=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1 (run --help)"
            ;;
    esac
done

if [ -n "$GITHUB_USER" ] && [ -z "$DOTFILES_REPO" ]; then
    DOTFILES_REPO="git@github.com:${GITHUB_USER}/dotfiles.git"
fi

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_config() {
    [ -n "$GITHUB_USER" ] || die "Set GITHUB_USER via environment or --github-user"
    [ "$GITHUB_USER" != "yourusername" ] || die "Replace the example GITHUB_USER value"
    [ -n "$DOTFILES_REPO" ] || die "Set DOTFILES_REPO via environment or --dotfiles-repo"
    case "$DOTFILES_REPO" in
        *yourusername*) die "Replace the example DOTFILES_REPO value" ;;
        git@github.com:*) ;;
        *) die "DOTFILES_REPO must be an SSH URL like git@github.com:${GITHUB_USER}/dotfiles.git" ;;
    esac
    [ -n "$DOTFILES_DIR" ] || die "DOTFILES_DIR cannot be empty"
    case "$DOTFILES_DIR" in
        /*) ;;
        *) die "DOTFILES_DIR must be an absolute path" ;;
    esac
    [ "$DOTFILES_DIR" != "/" ] || die "DOTFILES_DIR cannot be /"
    [ -n "$SSH_KEY_PATH" ] || die "SSH_KEY_PATH cannot be empty"
    case "$SSH_KEY_PATH" in
        /*) ;;
        *) die "SSH_KEY_PATH must be an absolute path" ;;
    esac
}

validate_host() {
    require_command apt-get
    require_command systemctl
    require_command getent

    [ -r /etc/os-release ] || die "/etc/os-release not found; this script supports Ubuntu 22.04 and 24.04"
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "${ID:-}" = "ubuntu" ] || die "Unsupported OS: ${PRETTY_NAME:-unknown}. Use Ubuntu 22.04 or 24.04."
    case "${VERSION_ID:-}" in
        22.04|24.04) ;;
        *) die "Unsupported Ubuntu version: ${VERSION_ID:-unknown}. Use Ubuntu 22.04 or 24.04." ;;
    esac

    case "$(uname -m)" in
        x86_64) ;;
        *) die "Unsupported architecture: $(uname -m). This reference flake targets x86_64-linux." ;;
    esac

    [ -d /run/systemd/system ] || die "systemd does not appear to be running"
    getent hosts github.com >/dev/null || die "Cannot resolve github.com; check internet/DNS before bootstrapping"
}

print_config() {
    echo "Resolved configuration:"
    echo "  Linux user:     $LINUX_USER"
    echo "  GitHub user:    $GITHUB_USER"
    echo "  Dotfiles repo:  $DOTFILES_REPO"
    echo "  Dotfiles dir:   $DOTFILES_DIR"
    echo "  SSH key path:   $SSH_KEY_PATH"
    echo "  Force reset:    $FORCE_RESET"
    echo ""
}

echo -e "${GREEN}🚀 Starting workstation bootstrap...${NC}"

step "Running preflight checks"
validate_config
validate_host
print_config

# Cache sudo credentials up front so subsequent sudo calls don't need a TTY.
sudo -v
ok "Preflight checks passed"

# ── Pre-flight: create user-owned XDG directories ────────────────────────────
# Must run before any sudo call. Some sudo-invoked tools (apt, gpg) implicitly
# create ~/.config/ owned by root, which causes "Permission denied" errors in
# any later user-space write to that tree.
step "Pre-creating user-owned directories"
mkdir -p \
    "$HOME/.config/git" \
    "$HOME/.config/tmux" \
    "$HOME/.local/bin" \
    "$HOME/.ssh" \
    "$(dirname "$SSH_KEY_PATH")"
chmod 700 "$HOME/.ssh" "$(dirname "$SSH_KEY_PATH")"
ok "User directories ready"

# ── Step 1: System dependencies ──────────────────────────────────────────────
step "Installing system dependencies"
sudo apt-get update -qq
sudo apt-get install -y git curl wget openssh-client zsh build-essential xz-utils
ok "System dependencies installed"

# Set zsh as login shell ─────────────────────────────────────────────────────
step "Setting zsh as login shell"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$current_shell" != "/usr/bin/zsh" ]; then
    sudo usermod -s /usr/bin/zsh "$USER"
    ok "Login shell changed to zsh (takes effect on next login)"
else
    ok "Login shell already set to zsh – skipping"
fi

# ── Step 2: Verify SSH key ────────────────────────────────────────────────────
# The key must exist and be registered on GitHub before this script is run.
step "Verifying SSH key for GitHub"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}✗ SSH key not found at $SSH_KEY_PATH${NC}"
    echo ""
    echo "Generate and register an SSH key before running bootstrap:"
    echo "  ssh-keygen -t ed25519 -C \"${GITHUB_USER}@workstation\" -f \"$SSH_KEY_PATH\" -N \"\""
    echo "  cat \"${SSH_KEY_PATH}.pub\""
    echo "Paste the key at https://github.com/settings/keys, then verify:"
    echo "  ssh-keyscan github.com >> ~/.ssh/known_hosts"
    echo "  ssh -i \"$SSH_KEY_PATH\" -o IdentitiesOnly=yes -T git@github.com"
    exit 1
fi

# Pre-seed known_hosts so ssh never prompts interactively (idempotent).
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

# ssh -T always exits 1 (GitHub denies shell access); capture stderr too.
SSH_OUTPUT=$(ssh -i "$SSH_KEY_PATH" -o IdentitiesOnly=yes -T git@github.com 2>&1 || true)
if ! echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
    echo -e "${RED}✗ SSH authentication to GitHub failed${NC}"
    echo ""
    echo "Ensure your public key is registered at https://github.com/settings/keys"
    echo "then verify with: ssh -i \"$SSH_KEY_PATH\" -o IdentitiesOnly=yes -T git@github.com"
    exit 1
fi
ok "SSH key verified – GitHub authentication successful"

export GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o IdentitiesOnly=yes"

# ── Step 3: Clone dotfiles ────────────────────────────────────────────────────
step "Cloning private dotfiles repository"
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    ok "Dotfiles cloned to $DOTFILES_DIR"
else
    [ -d "$DOTFILES_DIR/.git" ] || die "$DOTFILES_DIR exists but is not a git repository"
    dotfiles_status="$(git -C "$DOTFILES_DIR" status --porcelain)"
    if [ -n "$dotfiles_status" ] && [ "$FORCE_RESET" != true ]; then
        echo -e "${RED}✗ Dotfiles repository has local changes${NC}"
        echo ""
        echo "Refusing to overwrite local edits in: $DOTFILES_DIR"
        echo "Review them first:"
        echo "  git -C \"$DOTFILES_DIR\" status --short"
        echo "  git -C \"$DOTFILES_DIR\" diff"
        echo ""
        echo "Then either commit/stash them and re-run, or intentionally discard them with:"
        echo "  bash bootstrap.sh --github-user \"$GITHUB_USER\" --dotfiles-repo \"$DOTFILES_REPO\" --force-reset"
        exit 1
    fi
    git -C "$DOTFILES_DIR" fetch origin main
    if [ "$FORCE_RESET" = true ]; then
        git -C "$DOTFILES_DIR" checkout -B main origin/main
        git -C "$DOTFILES_DIR" clean -fd
        ok "Dotfiles reset to origin/main (--force-reset)"
    else
        current_branch="$(git -C "$DOTFILES_DIR" rev-parse --abbrev-ref HEAD)"
        [ "$current_branch" = "main" ] || die "Dotfiles checkout is on '$current_branch', not 'main'. Switch branches or re-run with --force-reset."
        if git -C "$DOTFILES_DIR" merge --ff-only origin/main; then
            ok "Dotfiles fast-forwarded to origin/main"
        else
            die "Dotfiles cannot fast-forward to origin/main. Resolve divergence manually or re-run with --force-reset."
        fi
    fi
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
# direnv, fzf, and all CLI packages declared in home.nix.
# Do NOT write git config anywhere else in this script.
step "Applying Home Manager configuration"
# Fully qualified GitHub URI bypasses local registry lookup failures on fresh
# machines that have not yet populated the Nix registry.
nix run github:nix-community/home-manager -- \
    switch --flake "$DOTFILES_DIR#${LINUX_USER}"
ok "Home Manager applied"

# Verify that Home Manager actually succeeded by checking for a key binary.
if ! command -v zsh &>/dev/null && [ ! -x "$HOME/.nix-profile/bin/zsh" ]; then
    warn "zsh not found after Home Manager apply – HM may have failed"
    warn "Re-run manually: nix run github:nix-community/home-manager -- switch --flake $DOTFILES_DIR#${LINUX_USER}"
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
        | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
${VERSION_CODENAME} stable" \
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
step "Configuring gh (pager + git protocol)"
GH_BIN="$(command -v gh || true)"
DELTA_BIN="$(command -v delta || true)"
if [ -n "$GH_BIN" ]; then
    # Always use SSH so 'gh repo clone' produces SSH remotes (not HTTPS).
    # HTTPS remotes prompt for token credentials on every push.
    "$GH_BIN" config set git_protocol ssh 2>/dev/null || true
    ok "gh git_protocol set to ssh"
    if [ -n "$DELTA_BIN" ]; then
        "$GH_BIN" config set pager "$DELTA_BIN" 2>/dev/null || true
        ok "gh pager set to delta"
    fi
else
    ok "gh not in Nix profile yet – skipping gh config"
fi

# ── Step 9: Symlink user-managed dotfiles ────────────────────────────────────
# sessionizer is a custom script not managed by Home Manager.
# tmux.conf is symlinked by Home Manager (home.file.mkOutOfStoreSymlink) — no manual symlink needed.
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

# ── Step 10: Stage LazyVim starter into dotfiles ─────────────────────────────
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

# ── Step 11: Run LazyVim headless plugin sync ────────────────────────────────
step "Running LazyVim headless plugin sync"
NVIM_BIN="$(command -v nvim || true)"
LAZY_LOG="$(mktemp /tmp/lazyvim-headless-sync.XXXXXX.log)"
if [ -n "$NVIM_BIN" ]; then
    if timeout 300 "$NVIM_BIN" --headless "+Lazy! sync" +qa >"$LAZY_LOG" 2>&1; then
        ok "LazyVim plugins synced headlessly"
        rm -f "$LAZY_LOG"
    else
        warn "LazyVim headless sync exited non-zero or timed out after 300s"
        warn "Open Neovim and run :Lazy sync manually, or inspect: $LAZY_LOG"
    fi
else
    warn "Neovim not found in PATH – skipping headless sync"
fi

# ── Complete ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}✔ Headless bootstrap complete.${NC}"
echo ""
echo -e "${YELLOW}Manual steps required before first use:${NC}"
echo "  1. Log out and back in (activates Docker group membership and zsh)"
echo "  2. gh auth login  (device flow — prints a code; open the URL on any browser)"
echo "  3. Verify SSH remote: cd ~/dotfiles && git remote -v"
echo "     (should show: git@github.com:${GITHUB_USER}/dotfiles.git)"
echo "  4. Commit generated lock/state files if present:"
echo "     cd ~/dotfiles && git status --short"
echo "     git add flake.lock nvim/lazy-lock.json && git commit -m \"chore: record initial generated locks\""
echo ""
echo "Verification commands:"
echo "  nix --version"
echo "  home-manager --version"
echo "  echo \$SHELL"
echo "  docker ps"
echo "  gh auth status"
echo "  direnv --version && devenv --version && nvim --version"
echo ""
echo "Optional desktop next step (XFCE4 + XRDP + WezTerm + VS Code):"
echo "  wget -O setup-desktop.sh https://raw.githubusercontent.com/${GITHUB_USER}/workstation-scripts/main/scripts/setup-desktop.sh"
echo "  chmod +x setup-desktop.sh && ./setup-desktop.sh --dotfiles-dir \"$DOTFILES_DIR\""
echo ""
echo "Back up keys that dotfiles cannot recover:"
echo "  $SSH_KEY_PATH"
echo "  ~/.config/sops/age/keys.txt  (if you later adopt SOPS + Age)"
echo ""
echo "Then verify the installation with the checklist in §2.6"
```

---

### 2.5 Post-Bootstrap Manual Steps

Three steps cannot be automated and must be completed immediately after the bootstrap. They require browser interaction or a session boundary that a script cannot cross. Complete them in order before doing anything else.

#### Manual Step 1: Re-login for Docker Group

The Docker group membership added in step 6 takes effect at a session boundary — when you start a new login session. Until you re-login, `docker ps` returns:

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

Your SSH key was registered with GitHub in §2.1, and your dotfiles were cloned via SSH in §2.3. On re-run, the bootstrap fetches `origin/main` and fast-forwards only when the local checkout is clean. No action is needed here unless your dotfiles remote is still set to HTTPS for some reason.

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

---

### 2.6 Verifying the Complete Installation

Run these checks in sequence after completing all three manual steps. Each check confirms one layer of the stack is working correctly.

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

- LazyVim loads immediately with no plugin installation progress (the headless sync in step 11 already handled this)
- No red error messages in the status line
- `:checkhealth` (run with `:checkhealth` inside Neovim) shows no ERROR lines — WARNING lines for optional features are acceptable

> [!warning] If Neovim shows plugin errors on first open The headless sync in step 11 may have failed or timed out. Run `:Lazy sync` inside Neovim to install missing plugins interactively. This takes 1–3 minutes and only needs to happen once.

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

| File | Apply command | Mechanism |
|---|---|---|
| `wezterm/wezterm.lua` | `SUPER+SHIFT+R` in WezTerm | WezTerm re-reads its config file and applies changes immediately |
| `tmux/tmux.conf` | `prefix r` inside tmux | tmux sources the config file and applies changes to all active sessions |
| `scripts/sessionizer` | (none needed) | The script is re-executed on each invocation; changes take effect on the next call |

> [!tip] Write useful commit messages Your dotfiles commit history is the audit log of every change you have made to your workstation. "Update config" is not useful six months later. "feat: add ripgrep to packages" or "fix: increase escape-time for remote SSH sessions" tells you exactly what changed and why.

**Syncing to a second machine:**

Once your dotfiles repository is pushed, setting up any additional machine is:

```bash
# Step 1 — generate and register the SSH key before the bootstrap runs
ssh-keygen -t ed25519 -C "yourusername@workstation" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
# → paste at github.com/settings/keys, then verify:
ssh -T git@github.com

# Step 2 — fetch and run the bootstrap (no pauses if the key is already registered)
wget -qO bootstrap.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh

bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
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
> A fully operational headless workstation — SSH key on GitHub, dotfiles repository tracking your environment, Nix and Home Manager managing your global tools, Docker running, Neovim staged with LazyVim, and the four-step workflow active. If you also ran `setup-desktop.sh`, WezTerm, VS Code, Chrome, ksnip, XFCE4, and XRDP are installed as the optional desktop layer.

---

**Next:** [3-Terminal.md — Terminal Workspace](3-Terminal.md)
