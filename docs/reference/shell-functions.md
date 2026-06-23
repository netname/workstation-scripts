# Shell Functions

Shell functions and aliases belong in the private `dotfiles` repo, usually inside the Home Manager zsh configuration.

The template provides a small default alias set. Larger helper functions are optional. Recommended helpers include a consolidated repository status command, a fuzzy PR checkout command, and a cleanup command for merged local branches.

## Apply Changes

```bash
cd ~/dotfiles
hms
exec zsh
```

Some functions can be reloaded in the current shell by sourcing the generated shell config, but a fresh shell is the cleanest verification path.

## Checks

```bash
type hms
type sessionizer
type lg
echo "$PATH"
```

## Template Aliases

The generated shell module defines these aliases:

| Alias | Expands to | Purpose |
|---|---|---|
| `ls` | `eza --icons` | icon-aware listing |
| `ll` | `eza -l --icons --git` | long listing with git status |
| `la` | `eza -la --icons --git` | all files, long listing |
| `lt` | `eza --tree --icons` | tree listing |
| `cat` | `bat` | syntax-highlighted file display |
| `n` | `nvim` | quick editor launch |
| `g` | `git` | git shortcut |
| `lg` | `lazygit` | lazygit shortcut |

The host module also defines:

| Alias | Purpose |
|---|---|
| `hms` | apply the Home Manager flake for the workstation host |

## Placement

- Put durable shell functions in Home Manager-managed zsh config.
- Put standalone executable helpers in `~/dotfiles/scripts/`.
- Keep project-specific commands in the project repository.
- Avoid putting project runtimes in shell startup.

## Optional Helper: `repo-status`

Purpose: show the current branch, worktree state, upstream status, recent commits, and PR state in one command.

Minimal implementation:

```bash
repo-status() {
  git status --short --branch
  echo
  git log --oneline --decorate --max-count=8
  echo
  gh pr status 2>/dev/null || true
}
```

Use it at the start of a work session:

```bash
repo-status
```

## Optional Helper: `gpr`

Purpose: choose and check out a GitHub pull request without copying branch names.

Minimal implementation:

```bash
gpr() {
  local pr
  pr="$(gh pr list --limit 50 --json number,title,headRefName \
    --template '{{range .}}{{.number}}{{"\t"}}{{.headRefName}}{{"\t"}}{{.title}}{{"\n"}}{{end}}' |
    fzf --prompt='PR> ' | awk '{print $1}')"

  [ -n "$pr" ] && gh pr checkout "$pr"
}
```

Dependencies: `gh`, `fzf`, and `awk`.

## Optional Helper: `gh-poi`

Purpose: prune local branches whose remote pull requests have already merged.

Conservative implementation:

```bash
gh-poi() {
  git fetch --prune
  git branch --merged main |
    sed 's/^[* ]*//' |
    grep -Ev '^(main|master|develop)$' |
    while read -r branch; do
      [ -n "$branch" ] && git branch --delete "$branch"
    done
}
```

Run it from an up-to-date `main`:

```bash
git switch main
git pull --ff-only
gh-poi
```

This helper deletes local branches only. It does not delete remote branches or open pull requests.
