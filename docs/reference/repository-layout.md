# Repository Layout

```text
workstation-scripts/
  README.md
  docs/
  scripts/
  templates/
  tools/
  .github/workflows/
```

## Root

| Path | Purpose |
|---|---|
| `README.md` | Short repo landing page and routing table |
| `docs/` | Diataxis-organized documentation |
| `.github/workflows/ci.yml` | CI checks for scripts and consistency |
| `tools/` | Local validation helpers used by CI |

## `scripts/`

| Path | Purpose |
|---|---|
| `scripts/bootstrap.sh` | Headless workstation bootstrap |
| `scripts/init-dotfiles.sh` | Generates a private dotfiles repo from templates |
| `scripts/setup-desktop.sh` | Installs optional desktop layer |
| `scripts/check-consistency.sh` | Validates repo/documentation consistency |

See [Scripts](scripts.md) and [Bootstrap Options](bootstrap-options.md).

## `templates/`

Templates are copied into the private `dotfiles` repository. They are starting points, not the final source of truth after generation.

See [Templates](templates.md).

## `tools/`

| Path | Purpose |
|---|---|
| `tools/check-markdown-links.ps1` | Validates local Markdown links and heading anchors |

## `docs/`

| Directory | Purpose |
|---|---|
| `tutorials/` | Guided learning paths |
| `how-to/` | Goal-oriented task guides |
| `reference/` | Factual lookup |
| `explanation/` | Conceptual background and rationale |
| numbered files | compatibility forwarding pages for old links |
