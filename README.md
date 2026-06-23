# workstation-scripts

Public bootstrap scripts and starter templates for building a reproducible Ubuntu development workstation with Nix, Home Manager, Devenv, Docker Compose, tmux, Neovim, VS Code, and SOPS + Age.

## Start Here

| If you want to... | Read this |
|---|---|
| Understand what this repo is for | [docs/overview.md](docs/overview.md) |
| Build your first workstation | [docs/tutorials/first-workstation.md](docs/tutorials/first-workstation.md) |
| Add another machine from existing dotfiles | [docs/how-to/add-another-machine.md](docs/how-to/add-another-machine.md) |
| Troubleshoot a broken setup | [docs/how-to/troubleshoot-common-problems.md](docs/how-to/troubleshoot-common-problems.md) |
| Look up scripts, templates, or config details | [Reference](docs/README.md#reference) |
| Understand the design decisions | [Explanation](docs/README.md#explanation) |

The full documentation index is [docs/README.md](docs/README.md).

## The Two-Repository Model

This repository is the public half of the setup. It contains scripts and templates that can be fetched anonymously on a fresh Ubuntu machine.

Your private `dotfiles` repository is the source of truth for personal configuration: git identity, Home Manager modules, shell config, editor config, encrypted secret wiring, and host profiles.

| Repository | Visibility | Contains |
|---|---|---|
| `workstation-scripts` | Public | Bootstrap scripts, desktop setup script, dotfiles initializer, templates |
| `dotfiles` | Private | Your personal workstation configuration and encrypted-secret scaffolding |

The split matters because a brand-new machine usually has no SSH key yet. Public scripts can be downloaded with `wget` or `curl`; private dotfiles are cloned only after SSH access is ready.

## Quick Start for Existing Repositories

Use this only when your private `dotfiles` repository already exists and contains the generated templates.

```bash
ssh-keygen -t ed25519 -C "yourname@workstation" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
# Paste the public key at https://github.com/settings/keys
ssh -T git@github.com

wget -qO bootstrap.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh

bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
```

For first-time setup, follow the full guided path in [First Workstation](docs/tutorials/first-workstation.md). Do not run the bootstrap until the private `dotfiles` repository exists and has been pushed.

## Repository Layout

```text
workstation-scripts/
  docs/       Diataxis-organized documentation
  scripts/    bootstrap.sh, init-dotfiles.sh, setup-desktop.sh
  templates/  Starter files copied into your private dotfiles repo
  tools/      Local validation helpers used by CI
```

Authoritative lookup pages:

- [Scripts reference](docs/reference/scripts.md)
- [Bootstrap options](docs/reference/bootstrap-options.md)
- [Templates reference](docs/reference/templates.md)
- [Repository layout](docs/reference/repository-layout.md)

## Local Checks

```bash
bash -n scripts/bootstrap.sh scripts/init-dotfiles.sh scripts/setup-desktop.sh
bash -n scripts/check-consistency.sh templates/check-secrets.sh templates/sessionizer
shellcheck scripts/bootstrap.sh scripts/init-dotfiles.sh scripts/setup-desktop.sh scripts/check-consistency.sh templates/check-secrets.sh templates/sessionizer
bash scripts/check-consistency.sh
pwsh -NoProfile -File tools/check-markdown-links.ps1
```
