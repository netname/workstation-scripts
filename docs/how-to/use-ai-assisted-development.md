# Use AI-Assisted Development

Use this guide when working with an AI coding assistant such as Codex, Claude Code, or another local agent.

## Start from a Clean Context

Before starting an assistant session:

```bash
git status --short
git branch --show-current
git pull --ff-only
```

If you have unrelated local work, commit or stash it first:

```bash
git stash push -m "wip before ai session"
```

## Give the Assistant Good Context

Useful starting context:

- The task outcome, not only the file to edit.
- Any constraints, such as "docs only" or "do not change scripts."
- The relevant commands for verification.
- Links to existing docs, issue numbers, or failing test output.

Example prompt:

```text
Update the documentation for bootstrap.sh after the new --host flag.
This is a docs-only change. Keep the Diataxis structure. Run the Markdown link checker.
```

## Keep Git as the Boundary

Treat the assistant as a collaborator inside your working tree:

```bash
git diff
git status --short
```

Review changes before committing:

```bash
git diff -- docs scripts templates
```

Ask for a summary and verification results before you commit.

## Verify Locally

Use the same checks you would use for human-authored changes:

```bash
bash scripts/check-consistency.sh
pwsh -NoProfile -File tools/check-markdown-links.ps1
```

For project code, use the project's own `just`, test, lint, or build commands.

## Commit Deliberately

Stage only intended files:

```bash
git add -p
git status --short
git commit -m "docs: update workstation setup guide"
```

Do not commit assistant-generated changes that you cannot explain.

## Review Checklist

- The change solves the requested task.
- No unrelated files were rewritten.
- Commands in docs are copyable and current.
- Script and template references point to live source files.
- No secrets, local paths, or machine-specific values were introduced.
- Verification commands passed or failures are recorded.
