# Add Another Machine

Use this guide when you already have a pushed private `dotfiles` repository and want to bootstrap another Ubuntu machine from it.

## Prerequisites

- Ubuntu Server 24.04 LTS recommended
- `sudo` rights
- Your GitHub username
- Your private dotfiles SSH URL, for example `git@github.com:yourusername/dotfiles.git`

## 1. Prepare the Machine

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git openssh-client build-essential \
  ca-certificates gnupg unzip xz-utils
```

## 2. Register SSH Access

```bash
ssh-keygen -t ed25519 -C "yourusername@workstation" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

Add the public key to GitHub, then verify:

```bash
ssh -T git@github.com
```

## 3. Run Bootstrap

```bash
wget -qO bootstrap.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh

bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
```

## 4. Complete Manual Steps

1. Log out and back in.
2. Run `gh auth login`.
3. Restore or create the Age key at `~/.config/sops/age/keys.txt`.
4. Run `hms` from `~/dotfiles`.

If this machine should decrypt existing secrets, restore the same Age private key that was used to encrypt them, or update SOPS recipients from a machine that can already decrypt.

## 5. Verify

```bash
nix --version
home-manager --version
docker ps
gh auth status
sops --version
direnv --version
devenv --version
```

For failures, see [Troubleshoot Common Problems](troubleshoot-common-problems.md).
