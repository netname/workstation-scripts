# First Workstation

This tutorial guides you from a fresh Ubuntu machine to a verified development workstation.

By the end, you will have a public `workstation-scripts` repository, a private `dotfiles` repository, Nix and Home Manager installed, Docker working, GitHub CLI authenticated, SOPS + Age ready, and project tooling available.

## Success Criteria

You are done when:

- the public `workstation-scripts` repository contains `scripts/`, `templates/`, `docs/`, `tools/`, and `README.md`
- the private `dotfiles` repository exists, is pushed, and uses an SSH remote
- `bootstrap.sh` completes without errors
- `docker ps`, `gh auth status`, `sops --version`, `direnv --version`, `devenv --version`, and `nvim --version` work
- generated lock files are committed to the private `dotfiles` repository

## What This Tutorial Does Not Do

This tutorial does not create GitHub repositories through `gh`, choose your editor preferences, rotate existing secrets, or install the optional desktop. Those are separate tasks linked from the docs index.

## 1. Prepare Ubuntu

Start from Ubuntu Server 24.04 LTS with internet access and `sudo`. The scripts accept Ubuntu 22.04 and 26.04 as compatible paths, but 24.04 is the recommended documented workstation baseline.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git openssh-client build-essential \
  ca-certificates gnupg unzip xz-utils
```

## 2. Create an SSH Key for GitHub

```bash
ssh-keygen -t ed25519 -C "yourname@workstation" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub
```

Paste the public key into GitHub at `https://github.com/settings/keys`, then verify:

```bash
ssh -T git@github.com
```

The expected result says GitHub authenticated you and does not provide shell access.

## 3. Create the Public Scripts Repo

Create a public GitHub repository named `workstation-scripts`, then clone it locally.

```bash
cd ~
git clone git@github.com:yourusername/workstation-scripts.git
cd workstation-scripts
```

Populate that repo with this reference implementation. First clone the reference checkout beside your new repo:

```bash
cd ~
REFERENCE_REPO_URL="https://github.com/netname/workstation-scripts.git"
git clone "$REFERENCE_REPO_URL" workstation-scripts-reference
cd ~/workstation-scripts
```

If your canonical reference lives somewhere else, change only `REFERENCE_REPO_URL`.

Copy these paths from the reference checkout into your new public repo:

- `scripts/bootstrap.sh`
- `scripts/init-dotfiles.sh`
- `scripts/setup-desktop.sh`
- `templates/`
- `docs/`
- `tools/`
- `.github/workflows/ci.yml`
- `README.md`

If you keep a CI badge in your copied `README.md`, update it to point at your GitHub owner and repository.

From inside your new empty `~/workstation-scripts` checkout:

```bash
cp -R ~/workstation-scripts-reference/scripts .
cp -R ~/workstation-scripts-reference/templates .
cp -R ~/workstation-scripts-reference/docs .
cp -R ~/workstation-scripts-reference/tools .
mkdir -p .github/workflows
cp ~/workstation-scripts-reference/.github/workflows/ci.yml .github/workflows/ci.yml
cp ~/workstation-scripts-reference/README.md .
chmod +x scripts/*.sh templates/check-secrets.sh templates/sessionizer
git add .
git commit -m "chore: add workstation bootstrap reference"
git push -u origin main
```

If you are maintaining this repository directly instead of copying it into your own GitHub account, make sure your pushed public repo contains those same paths before running bootstrap commands from a new machine.

## 4. Generate the Private Dotfiles Repo

Use the initializer to create your private dotfiles project from templates.

```bash
bash scripts/init-dotfiles.sh \
  --target-dir "$HOME/dotfiles" \
  --linux-user "$(whoami)" \
  --git-name "Your Name" \
  --git-email "you@example.com"
```

Create a private GitHub repository named `dotfiles`, add it as `origin`, and push.

```bash
cd ~/dotfiles
git remote add origin git@github.com:yourusername/dotfiles.git
git push -u origin main
```

If you need the dotfiles creation steps without the full tutorial, use [Create Private Dotfiles](../how-to/create-private-dotfiles.md).

## 5. Run the Bootstrap

On the target Ubuntu machine, fetch the public bootstrap and point it at your private dotfiles repo.

```bash
wget -qO bootstrap.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh

bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
```

The bootstrap installs system prerequisites, verifies SSH, clones dotfiles, installs Nix, applies Home Manager, installs Docker, configures GitHub CLI defaults, links user-managed files, and stages Neovim.

For exact script behavior, see [Scripts](../reference/scripts.md) and [Bootstrap Options](../reference/bootstrap-options.md).

## 6. Complete Manual Steps

Some work is intentionally manual because it involves session boundaries, browser auth, or secret custody.

1. Log out and back in so Docker group membership and shell changes take effect.
2. Run `gh auth login`, choose GitHub.com, SSH, and browser login.
3. Create and back up your Age key:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

Paste the public recipient into `~/dotfiles/.sops.yaml`, then run:

```bash
cd ~/dotfiles
hms
```

## 7. Verify the Workstation

Run these checks after the manual steps:

```bash
nix --version
home-manager --version
echo "$SHELL"
docker ps
docker compose version
gh auth status
sops --version
age --version
direnv --version
devenv --version
nvim --version
```

If a check fails, use [Troubleshoot Common Problems](../how-to/troubleshoot-common-problems.md).

## 8. Make the Result Durable

Commit generated lock files and any intentional config changes in the private dotfiles repo.

```bash
cd ~/dotfiles
git status --short
git add flake.lock
test ! -f nvim/lazy-lock.json || git add nvim/lazy-lock.json
git commit -m "chore: record initial generated locks"
git push
```

Now continue with [First Configuration Change](first-configuration-change.md) or [First Project Environment](first-project-environment.md).
