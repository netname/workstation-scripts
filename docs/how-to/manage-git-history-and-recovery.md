# Manage Git History and Recovery

Use this guide when you need to stash work, undo a local mistake, recover lost commits, cherry-pick a fix, or audit history.

## Stash Work in Progress

Use a named stash before switching tasks with unfinished local edits:

```bash
git stash push -m "wip before switching tasks"
git stash list
git stash show --stat stash@{0}
```

Inspect the full diff before applying:

```bash
git stash show -p stash@{0}
```

Apply without deleting the stash:

```bash
git stash apply stash@{0}
```

Apply and remove it from the stash list:

```bash
git stash pop stash@{0}
```

Delete one stash:

```bash
git stash drop stash@{0}
```

Delete all stashes only when you are certain they are disposable:

```bash
git stash clear
```

## Undo Local Changes

Discard unstaged changes in one file:

```bash
git restore path/to/file
```

Unstage a file but keep the content:

```bash
git restore --staged path/to/file
```

Amend the most recent local commit:

```bash
git add <files>
git commit --amend
```

Do not amend or reset commits that other people may already have based work on unless the team explicitly agrees.

## Undo Published Changes

Use `revert` for published history:

```bash
git log --oneline
git revert <commit-sha>
git push
```

Revert creates a new commit that undoes the target commit. It preserves shared history.

To re-apply a reverted change, revert the revert commit:

```bash
git revert <revert-commit-sha>
```

## Recover with Reflog

Use reflog when a reset, rebase, branch switch, or amend moved `HEAD` and you need to find the old commit:

```bash
git reflog --date=relative
```

Create a recovery branch before experimenting:

```bash
git switch -c recover/lost-work <sha-from-reflog>
```

Common recovery pattern:

```bash
git reflog
git switch -c recover/before-reset HEAD@{1}
```

## Cherry-Pick a Commit

Apply one commit from another branch:

```bash
git log --oneline --all --decorate
git cherry-pick <commit-sha>
```

If conflicts occur:

```bash
git status --short
# edit files and remove conflict markers
git add <resolved-files>
git cherry-pick --continue
```

Abort if the cherry-pick is wrong:

```bash
git cherry-pick --abort
```

## Audit History

Useful history queries:

```bash
git log --oneline --graph --decorate --all
git log --stat
git log -- path/to/file
git log --author="Name"
git log --since="2 weeks ago"
git blame path/to/file
```

Find commits that changed a function, with Git 2.34 or newer:

```bash
git log -L :function_name:path/to/file
```

Use bisect to find the commit that introduced a regression:

```bash
git bisect start
git bisect bad
git bisect good <known-good-sha>
# test each checked-out revision, then run:
git bisect good
# or:
git bisect bad
git bisect reset
```

## Decision Table

| Situation | Prefer |
|---|---|
| Uncommitted local edit is wrong | `git restore` |
| Commit is local and unpushed | `git commit --amend`, interactive rebase, or reset with care |
| Commit is pushed or shared | `git revert` |
| You lost a local commit | `git reflog` then recovery branch |
| You need one fix from another branch | `git cherry-pick` |
| You need to switch tasks temporarily | `git stash push -m "..."` |

For the normal branch and PR loop, see [Use Daily Development Workflow](use-daily-development-workflow.md).
