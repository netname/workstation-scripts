# Overview

`workstation-scripts` is a public bootstrap and template repository for building a reproducible Ubuntu development workstation.

It helps you get from a fresh machine to a working environment with:

- Nix and Home Manager for reproducible global tools and user configuration
- tmux, WezTerm, shell helpers, and a sessionizer for terminal workflow
- Neovim with LazyVim and VS Code support
- Devenv, direnv, and Docker Compose for project-local environments and services
- SOPS + Age for encrypted secrets that can be committed safely
- Optional XFCE + XRDP desktop setup

## Who This Is For

Use this repo if you want your workstation to be rebuilt from version-controlled files instead of from memory, notes, and one-off manual installs.

It is especially useful when you:

- set up fresh Ubuntu machines more than once
- want dotfiles that are private but bootstrap scripts that are public
- want project tools isolated from global tools
- want a repeatable recovery path when a machine is lost or rebuilt
- want secrets committed only in encrypted form

## What "Working Workstation" Means

A working workstation has:

- a private `dotfiles` repo cloned through SSH
- Nix and Home Manager active in the login shell
- global CLI tools installed declaratively
- Docker available without permission errors
- `gh` authenticated
- SOPS + Age ready for encrypted secrets
- direnv and devenv ready for project environments
- Neovim and optional desktop tools ready for daily work

## The Two-Repository Model

This repo stays public because a fresh machine can fetch public scripts before it has SSH credentials.

Your private `dotfiles` repo contains personal configuration and encrypted-secret scaffolding. The bootstrap only clones it after your SSH key is registered with GitHub.

Learn the rationale in [Why Two Repositories](explanation/why-two-repositories.md). Look up the files in [Repository Layout](reference/repository-layout.md) and [Templates](reference/templates.md).

## Happy Path Map

```text
public workstation-scripts repo
  -> private dotfiles repo generated from templates
  -> SSH key registered with GitHub
  -> bootstrap.sh clones dotfiles and applies Home Manager
  -> manual login/auth/secret-key steps
  -> verified workstation
```

## Choose Your Path

| Goal | Next page |
|---|---|
| Build a workstation for the first time | [First Workstation](tutorials/first-workstation.md) |
| Add another machine | [Add Another Machine](how-to/add-another-machine.md) |
| Create the private dotfiles repo | [Create Private Dotfiles](how-to/create-private-dotfiles.md) |
| Add a graphical desktop | [Add Graphical Desktop](how-to/add-graphical-desktop.md) |
| Change your workstation config | [Update Workstation Config](how-to/update-workstation-config.md) |
| Start a project environment | [First Project Environment](tutorials/first-project-environment.md) |
| Fix a problem | [Troubleshoot Common Problems](how-to/troubleshoot-common-problems.md) |
| Look up exact behavior | [Reference](README.md#reference) |
| Understand the design | [Explanation](README.md#explanation) |
