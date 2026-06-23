# Review Pull Requests

Use this guide when reviewing someone else's pull request from the command line and browser.

## Check Out the Pull Request

```bash
gh pr list
gh pr checkout <number>
```

Read the PR metadata:

```bash
gh pr view <number>
gh pr checks <number>
```

Inspect the diff with your configured pager:

```bash
gh pr diff <number>
```

## Build Context Before Commenting

Ask four questions before leaving feedback:

1. What problem does the PR claim to solve?
2. Does the diff solve that problem with the expected scope?
3. Are tests, docs, migrations, or operational notes missing?
4. Is the code safe to maintain after merge?

Run the relevant local checks if the project supports them:

```bash
just check
# or project-specific equivalents:
just test
just lint
```

## Leave Feedback

Use GitHub's browser review UI for line comments, suggestions, and multi-comment reviews. Use the CLI for quick status checks and summary comments:

```bash
gh pr comment <number> --body "I left review notes. Main concern: ..."
```

Good review comments are specific, actionable, and tied to behavior:

- Prefer "This can fail when the config file is absent; can we handle that case?" over "This is brittle."
- Mark blocking correctness issues clearly.
- Separate required changes from optional taste.

## Approve or Request Changes

Approve only after the implementation, tests, and docs are ready enough to merge:

```bash
gh pr review <number> --approve --body "Looks good after local check."
```

Request changes when merging would introduce a bug, break a documented contract, or leave a required workflow incomplete:

```bash
gh pr review <number> --request-changes --body "Blocking on the failing migration case noted inline."
```

Use comments, not request-changes, for non-blocking improvements.

## After Review

Return to your own branch:

```bash
git switch main
git pull --ff-only
```

Delete the temporary PR branch if it remains locally:

```bash
git branch --delete <branch-name>
```
