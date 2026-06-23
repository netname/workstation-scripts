# Create Private Dotfiles

Use this guide when you need the private `dotfiles` repository that `bootstrap.sh` clones and applies.

## 1. Generate the Dotfiles Tree

From the public `workstation-scripts` repo:

```bash
bash scripts/init-dotfiles.sh \
  --target-dir "$HOME/dotfiles" \
  --linux-user "$(whoami)" \
  --git-name "Your Name" \
  --git-email "you@example.com"
```

The initializer creates Home Manager entrypoints, host and user modules, shell/editor placeholders, SOPS scaffolding, and helper scripts. Project templates stay in `workstation-scripts/templates/` until you copy them into a project repository.

## 2. Inspect the Generated Files

```bash
cd ~/dotfiles
test -f flake.nix
test -f home.nix
test -f "homes/$(whoami).nix"
test -f hosts/workstation.nix
test -f modules/git.nix
test -x scripts/sessionizer
```

Search for unresolved placeholders:

```bash
grep -R -E "CHANGE_ME|YOUR_FULL_NAME|YOUR_EMAIL" --include='*.nix' .
```

Expected output: nothing.

## 3. Create the Private GitHub Repo

Create a private GitHub repository named `dotfiles`, then attach it as the remote.

```bash
git remote add origin git@github.com:yourusername/dotfiles.git
git push -u origin main
```

## 4. Verify SSH Access

```bash
ssh -T git@github.com
git remote -v
```

The remote should use `git@github.com:...`, not HTTPS.

## 5. Continue

Return to [First Workstation](../tutorials/first-workstation.md) and run the bootstrap.

For the full list of generated files, see [Templates](../reference/templates.md).
