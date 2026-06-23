# Use Daily Development Workflow

Use this guide for the normal branch, commit, PR, review, and merge loop.

## 1. Start from Updated `main`

```bash
git switch main
git pull --ff-only
git status --short
```

The working tree should be clean before starting new work.

## 2. Create a Feature Branch

```bash
git switch -c feature/descriptive-name
```

## 3. Work in Small Commits

```bash
git status --short
git diff
git add <files>
git commit -m "feat: describe the change"
```

Commit messages should describe the outcome, not just the files touched.

## 4. Keep the Branch Current

For an unshared branch:

```bash
git fetch origin
git rebase origin/main
git push --force-with-lease --force-if-includes
```

For a shared branch, prefer merging or coordinate before rewriting history.

## 5. Open a Pull Request

```bash
git push -u origin HEAD
gh pr create
```

Use a PR body that explains what changed, why, and how it was tested.

## 6. Respond to Review

Make fixes, commit them, and push. Use fixup commits or clean history before merge if that is the repository convention.

If CI fails, inspect the failed job before changing code:

```bash
gh pr checks
gh run list --limit 5
```

After fixing the failure:

```bash
git add <files>
git commit -m "fix: address failing check"
git push
```

If review asks for a small correction, make a normal follow-up commit. If review asks for a larger rethink, tell reviewers you are reworking the branch before pushing a substantially different version.

## 7. Resolve Conflicts

When a rebase or merge reports conflicts:

```bash
git status --short
```

Open each conflicted file, remove conflict markers, keep the intended final content, then continue:

```bash
git add <resolved-files>
git rebase --continue
```

If the rebase is going in the wrong direction:

```bash
git rebase --abort
```

## 8. Merge and Clean Up

```bash
gh pr status
gh pr merge --squash --delete-branch
git switch main
git pull --ff-only
```

Delete any stale local branch if GitHub did not already remove it:

```bash
git branch --delete feature/descriptive-name
```

## 9. Recover from Common Mistakes

Use `git reflog` to find recent branch and HEAD movements:

```bash
git reflog --date=relative
```

Use `git stash` before switching context with unfinished local edits:

```bash
git stash push -m "wip before switching tasks"
git stash list
git stash show --stat stash@{0}
```

The design rationale is in [Git Workflow Model](../explanation/git-workflow-model.md). Command facts are in [Git and GitHub Reference](../reference/git-and-gh-reference.md).
