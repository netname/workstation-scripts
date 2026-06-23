# Why Two Repositories

The setup uses two repositories because the bootstrap and the personal configuration have different audiences and access requirements.

## The Public Repo

`workstation-scripts` is public so a new machine can fetch scripts before it has credentials.

A fresh machine may have no SSH key, no GitHub CLI login, no git identity, and no configured editor. Public HTTPS downloads are the simplest reliable way to get the bootstrap script onto that machine.

## The Private Repo

`dotfiles` is private because it contains personal configuration:

- git identity
- shell and editor preferences
- host profiles
- private project paths
- encrypted-secret scaffolding
- machine-specific choices

Even if most of that is not secret, it is personal and does not need to be public.

## The Boundary

The public repo contains reusable setup machinery. The private repo contains the actual declaration of your workstation.

The bootstrap crosses the boundary only after SSH is ready. It downloads from the public repo, verifies GitHub SSH access, then clones the private dotfiles repo.

This keeps the first-machine path simple while keeping personal configuration out of the public internet.
