# Git Workflow Model

The git workflow favors a clean main branch, small reviewable changes, and recoverable local history.

## Branches

Start work from updated `main`, create a feature branch, and keep unrelated changes separate.

## Commits

Commits should tell the story of the change. Prefer small commits that each make sense on their own.

## Rebasing

Rebase unshared feature branches onto updated `main` to keep history easy to review.

Do not rewrite published/shared history without coordination. `--force-with-lease --force-if-includes` is for feature branches you own, not protected shared branches.

## Pull Requests

PRs should explain what changed, why it changed, and how it was tested.

## Recovery

Use `git status`, `git reflog`, `git stash`, and small commits as safety tools. Local mistakes are usually recoverable when history is inspected before destructive actions.
