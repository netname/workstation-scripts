# Git and GitHub Reference

Git configuration is managed through the private dotfiles repo and applied with Home Manager.

## Checks

```bash
git config --global --list
gh auth status
gh config get git_protocol
gh config get pager
delta --version
```

## Expected Defaults

| Area | Expected value |
|---|---|
| Git identity | declared in dotfiles |
| GitHub protocol | SSH |
| GitHub auth | browser login through `gh auth login` |
| Pager | delta when installed |
| Feature branch update | rebase for unshared branches |
| Force push | `--force-with-lease --force-if-includes` for owned feature branches only |

## Template Git Aliases

The generated `modules/git.nix` defines:

| Alias | Expands to |
|---|---|
| `git lg` | `log --oneline --graph --decorate --all` |
| `git st` | `status --short` |
| `git sw` | `switch` |
| `git co` | `checkout -b` |
| `git pushf` | `push --force-with-lease --force-if-includes` |
| `git psu` | `push --set-upstream origin HEAD` |

## Common Commands

```bash
git status --short
git fetch origin
git rebase origin/main
git push --force-with-lease --force-if-includes
gh pr create
gh pr status
gh pr checks
gh pr merge --squash --delete-branch
```

## Branch Rules

| Branch situation | Recommended action |
|---|---|
| Starting new work | update `main`, then create a feature branch |
| Owned branch, not shared | rebase onto `origin/main` |
| Shared branch | coordinate before rewriting, or merge main |
| Published mistake | use `git revert` |
| Local mistake | use restore, amend, reset, or reflog as appropriate |

## GitHub CLI Checks

```bash
gh auth status
gh config get git_protocol
gh config get pager
gh repo view
gh pr status
```

For daily usage, see [Use Daily Development Workflow](../how-to/use-daily-development-workflow.md). For rationale, see [Git Workflow Model](../explanation/git-workflow-model.md).
