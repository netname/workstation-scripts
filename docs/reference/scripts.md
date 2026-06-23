# Scripts

## `scripts/bootstrap.sh`

Headless bootstrap for a fresh Ubuntu workstation.

It:

1. installs system prerequisites
2. verifies SSH access to GitHub
3. clones or updates the private dotfiles repo
4. installs Nix
5. applies Home Manager
6. installs Docker
7. configures GitHub CLI defaults where possible
8. links user-managed helper files
9. stages LazyVim into dotfiles when needed
10. runs a headless Neovim plugin sync when possible

Use it from [First Workstation](../tutorials/first-workstation.md) or [Add Another Machine](../how-to/add-another-machine.md).

## `scripts/init-dotfiles.sh`

Generates a private `dotfiles` repository from `templates/`.

It accepts identity and target-path inputs, creates the expected Home Manager structure, stages user-managed config placeholders, and initializes git.

If the target path is not `~/dotfiles`, it creates `~/dotfiles` as a compatibility symlink because the generated Home Manager templates and `hms` alias intentionally use that stable path.

Use it from [Create Private Dotfiles](../how-to/create-private-dotfiles.md).

## `scripts/setup-desktop.sh`

Installs the optional graphical desktop layer after the headless bootstrap has succeeded.

It is intentionally separate from `bootstrap.sh` so headless servers, VMs, and SSH-only workstations do not get GUI packages by default.

Use it from [Add Graphical Desktop](../how-to/add-graphical-desktop.md).

## `scripts/check-consistency.sh`

Checks assumptions that should remain true across scripts, docs, and templates. Run it before pushing documentation or script changes:

```bash
bash scripts/check-consistency.sh
```
