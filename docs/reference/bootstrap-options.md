# Bootstrap Options

`scripts/bootstrap.sh` is the canonical headless setup script.

## Options

| Input | Example | Meaning |
|---|---|---|
| `--github-user` | `--github-user octocat` | GitHub account that owns the public scripts repo |
| `--dotfiles-repo` | `--dotfiles-repo git@github.com:octocat/dotfiles.git` | SSH URL for the private dotfiles repo |
| `--dotfiles-dir` | `--dotfiles-dir "$HOME/dotfiles"` | Local checkout path for the private dotfiles repo |
| `--ssh-key-path` | `--ssh-key-path "$HOME/.ssh/id_ed25519"` | SSH private key used to authenticate with GitHub |
| `--force-reset` | `--force-reset` | Discard local dotfiles changes and reset the checkout to `origin/main` |
| `-h`, `--help` | `--help` | Print script usage |

Use an SSH URL for `--dotfiles-repo`. HTTPS remotes prompt for credentials and are not the expected path.

`--force-reset` is destructive for the local dotfiles checkout. Use it only when you intentionally want to discard local dotfiles changes on the target machine.

## Environment Variables

| Variable | Default | Meaning |
|---|---|---|
| `GITHUB_USER` | none | Same value as `--github-user` |
| `DOTFILES_REPO` | inferred from `GITHUB_USER` when possible | Same value as `--dotfiles-repo` |
| `DOTFILES_DIR` | `$HOME/dotfiles` | Same value as `--dotfiles-dir` |
| `SSH_KEY_PATH` | `$HOME/.ssh/id_ed25519` | Same value as `--ssh-key-path` |

Command-line flags override environment defaults.

## Typical Invocation

```bash
bash bootstrap.sh \
  --github-user yourusername \
  --dotfiles-repo git@github.com:yourusername/dotfiles.git
```

## Expected Precondition

Before running the bootstrap:

- an SSH key exists on the target machine
- the public key is registered with GitHub
- `ssh -T git@github.com` authenticates
- the private dotfiles repo exists and has been pushed
- the dotfiles repo contains a Home Manager flake output matching the Linux username

## Expected Postcondition

After a successful run:

- dotfiles are cloned to `DOTFILES_DIR`
- when `DOTFILES_DIR` is not `~/dotfiles`, the script creates a `~/dotfiles` compatibility symlink for Home Manager templates and shell helpers
- Nix and Home Manager are installed
- the Home Manager profile has been applied
- Docker is installed
- helper symlinks are present
- Neovim starter files are staged if needed

Manual work remains for login-session changes, GitHub CLI browser auth, and Age key custody.

## Dotfiles Update Behavior

If `DOTFILES_DIR` does not exist, the script clones `DOTFILES_REPO`.

If `DOTFILES_DIR` already exists, the script requires it to be a clean git repository. Without `--force-reset`, it fetches `origin/main` and fast-forwards only. With `--force-reset`, it checks out `origin/main` and removes untracked files from the dotfiles checkout.

The generated templates expect `~/dotfiles` for Home Manager symlinks and the `hms` alias. For a non-default `DOTFILES_DIR`, `bootstrap.sh`, `init-dotfiles.sh`, and `setup-desktop.sh` create `~/dotfiles` as a compatibility symlink. If `~/dotfiles` already exists and points somewhere else, the scripts stop before applying changes.

## Verification

```bash
nix --version
home-manager --version
docker ps
gh auth status
sops --version
direnv --version
devenv --version
```
