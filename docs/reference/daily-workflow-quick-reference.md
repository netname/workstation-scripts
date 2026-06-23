# Daily Workflow Quick Reference

This page is a command lookup for the normal development loop. For a guided workflow, see [Use Daily Development Workflow](../how-to/use-daily-development-workflow.md).

## Environment and Editor

```bash
# Project environment
direnv status
direnv allow
devenv shell

# Services
docker compose up -d
docker compose ps
docker compose logs -f <service>
docker compose down

# Workstation config
cd ~/dotfiles
hms
home-manager generations
```

## Orientation

```bash
git status --short
git branch --show-current
git remote -v
git log --oneline --graph --decorate --all --max-count=20
gh pr status
```

## Issues

```bash
gh issue create
gh issue list
gh issue view <number>
```

## Branches

```bash
git switch main
git pull --ff-only
git switch -c feature/descriptive-name
git branch --list
git branch --delete feature/descriptive-name
git branch -m old-name new-name
```

## Staging and Commits

```bash
git diff
git diff --staged
git add <files>
git add -p
git commit -m "feat: describe the outcome"
git commit --amend
```

## Sync Scenarios

Update local main:

```bash
git switch main
git pull --ff-only
```

Rebase an owned, unshared feature branch:

```bash
git fetch origin
git rebase origin/main
git push --force-with-lease --force-if-includes
```

Handle conflicts:

```bash
git status --short
# edit files and remove conflict markers
git add <resolved-files>
git rebase --continue
```

Abort a bad rebase:

```bash
git rebase --abort
```

## Pull Requests

```bash
git push -u origin HEAD
gh pr create
gh pr view --web
gh pr checks
gh pr diff
gh pr merge --squash --delete-branch
```

Review a PR:

```bash
gh pr checkout <number>
gh pr view <number>
gh pr diff <number>
gh pr review <number> --approve
```

## Undo and Recovery

```bash
git restore path/to/file
git restore --staged path/to/file
git revert <commit-sha>
git reflog --date=relative
git switch -c recover/lost-work <sha>
```

## Stash

```bash
git stash push -m "wip before switching tasks"
git stash list
git stash show --stat stash@{0}
git stash apply stash@{0}
git stash pop stash@{0}
git stash drop stash@{0}
```

## History Auditing

```bash
git log --oneline --graph --decorate --all
git log --stat
git log -- path/to/file
git blame path/to/file
git bisect start
```

## Releases

```bash
git tag --sort=-creatordate
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
gh release create v1.2.3 --generate-notes
gh release list
gh release view v1.2.3
```

## Decision Table

| Need | Command family |
|---|---|
| Start work | `git switch`, `git pull`, `git switch -c` |
| Inspect state | `git status`, `git diff`, `gh pr status` |
| Save focused changes | `git add -p`, `git commit` |
| Update owned branch | `git fetch`, `git rebase`, guarded force push |
| Preserve shared history | `git revert` |
| Recover local history | `git reflog` |
| Temporarily set work aside | `git stash` |
