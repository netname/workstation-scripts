# Contributing Documentation

Use this guide when adding or changing documentation in this repository.

## Choose the Right Page Type

| Reader need | Put it in |
|---|---|
| Learn by following a guided path | `docs/tutorials/` |
| Complete a specific task | `docs/how-to/` |
| Look up facts, flags, files, or commands | `docs/reference/` |
| Understand why the system works this way | `docs/explanation/` |

## Rules for Tutorials

- Start with a clear outcome and success criteria.
- Keep the path linear.
- Avoid optional branches unless the user must choose.
- Link to reference for exact flags and to explanation for rationale.
- Include “What this tutorial does not do” when scope could be confused.

## Rules for How-To Guides

- Name the task in the title.
- Include prerequisites, steps, verification, and common failure notes.
- Do not teach the whole system.
- Keep commands copyable and avoid placeholder paths inside code blocks when a variable would work better.

## Rules for Reference

- Be complete and factual.
- Prefer tables for flags, files, generated paths, and expected values.
- Keep reference neutral: do not tell a story or teach concepts at length.
- When scripts or templates change, update reference in the same change.

## Rules for Explanation

- Explain tradeoffs, boundaries, and alternatives.
- Answer “why this way?” and “why not the obvious alternative?”
- Do not hide required commands here; link to tutorials or how-tos instead.

## Numbered Compatibility Pages

The old numbered files at the top of `docs/` are forwarding pages for compatibility. Do not add primary guidance there. Add or update content in the appropriate Diataxis directory, then update the forwarding page only if its routing list becomes stale.

## Checks

Before opening a PR, run:

```bash
bash -n scripts/bootstrap.sh scripts/init-dotfiles.sh scripts/setup-desktop.sh
bash -n scripts/check-consistency.sh templates/check-secrets.sh templates/sessionizer
shellcheck scripts/bootstrap.sh scripts/init-dotfiles.sh scripts/setup-desktop.sh scripts/check-consistency.sh templates/check-secrets.sh templates/sessionizer
bash scripts/check-consistency.sh
pwsh -NoProfile -File tools/check-markdown-links.ps1
```

CI also checks shell syntax, shellcheck, consistency rules, and Markdown links/anchors.
