# workstation-scripts

[![CI](https://github.com/netname/workstation-scripts/actions/workflows/ci.yml/badge.svg)](https://github.com/netname/workstation-scripts/actions/workflows/ci.yml)

Public half of a two-repository workstation setup. Contains the bootstrap scripts and starter templates that turn a fresh Ubuntu machine into a reproducible development environment using Nix, Home Manager, Devenv, and Docker Compose.

## The two-repository model

| Repository | Visibility | Contains |
|---|---|---|
| **workstation-scripts** (this repo) | Public | Bootstrap scripts fetchable via `curl`; Nix config templates |
| **dotfiles** | Private | Your `flake.nix`, `home.nix`, WezTerm/tmux config, Neovim config |

Scripts in this repo are fetched anonymously by `curl` on a fresh machine that has no SSH key yet. Your personal config stays private in your dotfiles repo, cloned only after an SSH key is registered. See [docs/0-Overview.md](docs/0-Overview.md) for the full bootstrap flow.

## Which path should I take?

| Situation | Start here |
|---|---|
| New user, no repositories, or no dotfiles yet | Read [docs/0-Overview.md](docs/0-Overview.md), then follow [docs/2-Installation.md](docs/2-Installation.md) |
| Already have `workstation-scripts` and a populated `dotfiles` repo | Use the quick start below |
| Adding another machine from existing dotfiles | Use the quick start below, or read [docs/2-Installation.md §2.4](docs/2-Installation.md#24-the-bootstrap--one-command-to-a-working-workstation) |
| Want a graphical desktop | Run the headless bootstrap first, then follow [docs/6-Desktop.md](docs/6-Desktop.md) |

> [!important]
> If you do not already have both repositories, do not run the bootstrap yet. The bootstrap expects a pushed private `dotfiles` repository with populated `flake.nix` and `home.nix`; it does not create that repository for you. First-time setup is covered in [docs/2-Installation.md](docs/2-Installation.md).

## Quick start for existing repos

**Prerequisites:** Ubuntu 22.04 or 24.04 (bare metal, VM, or cloud). An SSH key registered on GitHub — generate one if you don't have it:

```bash
ssh-keygen -t ed25519 -C "yourname@workstation" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub   # paste this at https://github.com/settings/keys
ssh -T git@github.com       # verify: should print "Hi yourusername!"
```

**Bootstrap:**

```bash
# 1. Fetch the script
wget -qO bootstrap.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh

# 2. Run — fully unattended once the SSH key is in place (~20–40 min)
bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
```

After it completes:

```bash
# Required before first use:
# 1. Log out and back in  (activates Docker group + zsh login shell)
# 2. gh auth login        (device flow — opens a browser URL)
```

**Optional graphical desktop** (XFCE4 + XRDP + WezTerm + VS Code):

```bash
wget -qO setup-desktop.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/setup-desktop.sh
bash setup-desktop.sh
```

## Repository layout

```
workstation-scripts/
├── docs/          Documentation — read docs/0-Overview.md first
├── scripts/       bootstrap.sh and setup-desktop.sh
└── templates/     Starter Nix config files to copy into your dotfiles repo
```

## Templates

Copy these into your private `dotfiles` repository as a starting point. First-time users do this as part of the repository setup flow in [docs/2-Installation.md](docs/2-Installation.md); the quick start above assumes this has already happened.

| File | Destination in dotfiles | Purpose |
|---|---|---|
| `templates/flake.nix` | `flake.nix` | Home Manager flake entry point |
| `templates/home.nix` | `home.nix` | Global packages, shell, git, prompt |
| `templates/devenv.nix` | `projectroot/devenv.nix` | Per-project environment |
| `templates/docker-compose.yml` | `projectroot/docker-compose.yml` | MariaDB + Redis services |
| `templates/sessionizer` | `scripts/sessionizer` | tmux project switcher |

## CI

GitHub Actions runs on every push and pull request to `main`:

- **Syntax check** — `bash -n` on all shell scripts
- **Shellcheck** — static analysis on `scripts/bootstrap.sh`, `scripts/setup-desktop.sh`, and `templates/sessionizer`

The badge at the top of this file reflects the current status. If it is red, check the [Actions tab](https://github.com/yourusername/workstation-scripts/actions) for the failing step.

To run the same checks locally before pushing:

```bash
bash -n scripts/bootstrap.sh && bash -n scripts/setup-desktop.sh
bash -n scripts/check-consistency.sh
shellcheck scripts/bootstrap.sh scripts/setup-desktop.sh scripts/check-consistency.sh templates/sessionizer
bash scripts/check-consistency.sh
```

## Documentation

Start here: **[docs/0-Overview.md](docs/0-Overview.md)**

| Doc | Covers |
|---|---|
| [0-Overview.md](docs/0-Overview.md) | What you're building and why |
| [1-Stack.md](docs/1-Stack.md) | Six-layer model, Nix fundamentals |
| [2-Installation.md](docs/2-Installation.md) | Step-by-step from zero to working |
| [3-Terminal.md](docs/3-Terminal.md) | WezTerm, tmux, sessionizer, fonts |
| [4-Projects.md](docs/4-Projects.md) | Devenv, Docker, git tooling |
| [5-Editors.md](docs/5-Editors.md) | Neovim + LazyVim, VS Code |
| [6-Desktop.md](docs/6-Desktop.md) | XFCE4 + XRDP (optional graphical desktop) |
| [7-Troubleshooting.md](docs/7-Troubleshooting.md) | Per-tool problem/fix reference |
| [8-DevWorkflows.md](docs/8-DevWorkflows.md) | Day-to-day development workflows |
