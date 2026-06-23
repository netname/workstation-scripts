# Manage Home Manager Generations

Use this guide when a workstation configuration change works incorrectly and you need to inspect, roll back, or re-apply a Home Manager generation.

## What a Generation Is

Each successful `home-manager switch` creates a generation. A generation records the exact Home Manager output that produced your user environment at that point in time.

In this repo's templates, `hms` is the convenience alias for:

```bash
home-manager switch --flake ~/dotfiles#YOUR_USER@workstation
```

## List Generations

```bash
home-manager generations
```

The output includes store paths similar to:

```text
/nix/store/...-home-manager-generation
```

Copy the store path for the generation you want to inspect or activate.

## Roll Back to a Previous Generation

Activate the previous generation by running its `activate` script:

```bash
/nix/store/<generation-path>/activate
```

Then open a new shell and verify the affected behavior:

```bash
zsh -l
git config --global --list
type hms
```

Rollback changes the active user environment, but it does not edit your `~/dotfiles` repository. If the bad configuration is still committed or still present in the worktree, fix it before running `hms` again.

## Rebuild After a Fix

Edit the source in `~/dotfiles`, then rebuild:

```bash
cd ~/dotfiles
git status --short
hms
```

Open a new shell after changing shell configuration:

```bash
exec zsh -l
```

## What Home Manager Owns

Home Manager owns generated files such as:

- `~/.zshrc`
- Git global configuration
- shell aliases declared in the Home Manager modules
- Starship, direnv, fzf, zoxide, and global CLI packages
- symlinks declared with `home.file`

Do not edit generated files directly. Edit the corresponding source under `~/dotfiles`, run `hms`, then verify.

## What It Does Not Own

The templates keep frequently tuned tool config outside the generated-file boundary:

- `~/dotfiles/wezterm/wezterm.lua`
- `~/dotfiles/tmux/tmux.conf`
- `~/dotfiles/nvim/`
- custom helper scripts such as `~/.local/bin/sessionizer`

These files are either symlinked or read directly by the tool. Save the file, then reload the tool:

| Tool | Reload |
|---|---|
| WezTerm | `SUPER+SHIFT+R` |
| tmux | prefix then `r`, if configured |
| sessionizer | rerun the command |
| Neovim | restart Neovim or reload the relevant Lua module |

For the conceptual boundary, see [Nix and Home Manager Boundary](../explanation/nix-home-manager-boundary.md).
