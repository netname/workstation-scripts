# Workstation Model

This repo builds a development workstation by separating stable automation from private personal configuration.

The main promise is repeatability: a fresh Ubuntu machine should become a useful workstation without hand-replaying weeks of terminal, Git, editor, Docker, and shell setup.

## Why This Approach

Traditional workstation setup tends to become a long list of manual commands. It works once, then slowly drifts:

- packages are installed by memory
- global config is edited in place
- project tools leak into the host system
- secrets become mixed with normal config
- a second machine never quite matches the first

This repo uses scripts, Nix, Home Manager, direnv, devenv, Docker Compose, and SOPS to make ownership explicit.

## Layer Map

| Layer | Owns | Source of truth |
|---|---|---|
| Ubuntu | base OS, users, system services | machine installation |
| Bootstrap scripts | first-run automation | public `workstation-scripts` repo |
| Nix | package store and reproducible packages | Nix installer and flake inputs |
| Home Manager | user packages and generated config | private `dotfiles` repo |
| User-managed dotfiles | fast-changing tool config | private `dotfiles` repo |
| direnv | per-project activation | project `.envrc` |
| devenv | project runtimes and tools | project `devenv.nix` |
| Docker Compose | stateful project services | project `docker-compose.yml` |
| SOPS + Age | encrypted secrets | private or project secret files |

## Two Repository Boundary

The public repository contains reusable automation and templates. It should be safe to share.

The private dotfiles repository contains personal identity, host names, private preferences, encrypted secrets, and machine-specific choices.

This keeps the bootstrap reusable while giving each user a private source of truth.

## The One Loop

For workstation configuration:

1. Edit the source in `~/dotfiles`.
2. Apply with `hms` when Home Manager owns the setting.
3. Reload the tool directly when the file is user-managed.
4. Verify behavior in a fresh shell or fresh tool session.
5. Commit the change to the private dotfiles repo.

For project configuration:

1. Edit `.envrc`, `devenv.nix`, `docker-compose.yml`, or project docs.
2. Run `direnv allow` if `.envrc` changed.
3. Start services with Docker Compose when needed.
4. Run project checks.
5. Commit the project change.

## What "Working Workstation" Means

A working workstation has:

- shell, prompt, and navigation tools available
- Git and GitHub CLI authenticated
- Home Manager switch working through `hms`
- Docker usable by the regular user
- direnv and devenv activating project environments
- Neovim available for terminal editing
- optional graphical tools installed only when requested

The canonical path is [First Workstation](../tutorials/first-workstation.md). The exact scripts are documented in [Scripts](../reference/scripts.md).
