# Troubleshoot Common Problems

Use this guide when a setup or daily workflow check fails.

## Bootstrap Cannot Fetch or Clone

**Symptom:** `wget` returns 404.

**Likely cause:** The public `workstation-scripts` repo is private, the file path is wrong, or changes were not pushed.

**Fix:**

```bash
wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh | head -3
```

Confirm the repository is public and the script exists at `scripts/bootstrap.sh`.

**Symptom:** `Permission denied (publickey)`.

**Likely cause:** The SSH key is missing or not registered with GitHub.

**Fix:**

```bash
test -f ~/.ssh/id_ed25519.pub
cat ~/.ssh/id_ed25519.pub
ssh -T git@github.com
```

## Nix or Home Manager Is Not on PATH

**Symptom:** `nix`, `home-manager`, or `hms` returns `command not found`.

**Fix:**

```bash
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
nix --version
home-manager --version
```

Open a new login shell after Home Manager changes.

## Docker Permission Denied

**Symptom:** `docker ps` reports permission denied on the Docker socket.

**Likely cause:** Group membership has not taken effect.

**Fix:** Log out and back in. Temporary current-terminal workaround:

```bash
newgrp docker
docker ps
```

## GitHub CLI Not Authenticated

**Symptom:** `gh auth status` reports not logged in.

**Fix:**

```bash
gh auth login
gh auth status
```

Choose GitHub.com, SSH, and browser authentication.

## SOPS Cannot Decrypt

**Symptom:** `sops` reports no matching identity.

**Likely cause:** The Age private key is missing or the file was not encrypted to this recipient.

**Fix:**

```bash
test -f ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

Confirm the printed recipient is in `.sops.yaml`, then update keys from a machine that can decrypt.

## direnv Does Not Activate

**Symptom:** entering a project does not load project tools.

**Fix:**

```bash
direnv status
direnv allow
```

If it fails only in new tmux panes, check the zsh load order in [Terminal Config](../reference/terminal-config.md).

## Neovim LSP or VS Code Tooling Uses the Wrong Binary

**Likely cause:** The editor did not inherit the direnv/devenv environment, or the LSP is configured through Mason instead of project tools.

**Fix:**

```bash
which pyright-langserver
which ruff
direnv status
```

For the model, see [Editor Environment Model](../explanation/editor-environment-model.md). For exact config notes, see [Editor Config](../reference/editor-config.md).

## WezTerm Shows Boxes Instead of Icons

**Likely cause:** the Nerd Font is missing, WezTerm is using the wrong family name, or Flatpak cannot read Nix-managed fonts.

**Fix:**

```bash
fc-list | grep JetBrains
flatpak info --show-permissions org.wezfurlong.wezterm | grep /nix
```

If `/nix` is not visible to the Flatpak sandbox:

```bash
flatpak override --user --filesystem=/nix:ro org.wezfurlong.wezterm
```

Restart WezTerm after changing font access.

## tmux or Neovim Colors Look Wrong

**Likely cause:** tmux true-color settings do not match the terminal.

**Fix:** confirm the tmux config contains a true-color override for the terminal name WezTerm reports.

```bash
tmux show-options -g default-terminal
tmux show-options -ga terminal-overrides
```

Reload tmux with `prefix r`.

## Escape Feels Laggy in Neovim

**Likely cause:** tmux `escape-time` is too high.

**Fix:**

```bash
tmux show-options -g escape-time
```

Set it to `0` in `tmux.conf`, then reload tmux.

## Rebase or Merge Is Stuck

Check the repository state:

```bash
git status
```

If you are resolving conflicts, edit files to remove conflict markers, then continue:

```bash
git add <resolved-files>
git rebase --continue
```

If you need to stop and return to the pre-rebase state:

```bash
git rebase --abort
```

If you lost track of where a commit went:

```bash
git reflog --date=relative
```

For workflow commands, see [Use Daily Development Workflow](use-daily-development-workflow.md) and [Git and GitHub Reference](../reference/git-and-gh-reference.md).
