# Update Workstation Config

Use this guide when changing packages, shell config, terminal config, editor config, or user-managed dotfiles.

## 1. Identify the Owner

| Change | Edit | Apply |
|---|---|---|
| Global packages | `~/dotfiles/modules/cli-tools.nix` | `hms` |
| Shell aliases, PATH, starship, direnv | `~/dotfiles/modules/shell.nix` | `hms` and a new shell |
| Git identity, aliases, pager defaults | `~/dotfiles/modules/git.nix` | `hms` |
| Host-specific imports or aliases | `~/dotfiles/hosts/workstation.nix` | `hms` |
| WezTerm | `~/dotfiles/wezterm/wezterm.lua` | `SUPER+SHIFT+R` |
| tmux | `~/dotfiles/tmux/tmux.conf` | `prefix r` |
| sessionizer | `~/dotfiles/scripts/sessionizer` | next invocation |
| Neovim | `~/dotfiles/nvim/` | restart Neovim or sync plugins |
| VS Code recommendations | `~/dotfiles/vscode/extensions.json` | install or refresh extensions |

If ownership is unclear, see [Nix and Home Manager Boundary](../explanation/nix-home-manager-boundary.md).

## 2. Make One Change

```bash
cd ~/dotfiles
nvim modules/cli-tools.nix
```

Keep the change small enough to verify directly.

## 3. Apply

For Home Manager:

```bash
hms
```

For user-managed configs, use the apply action from the table above.

## 4. Verify

Examples:

```bash
which tool-name
tool-name --version
tmux show-options -g escape-time
gh auth status
```

Use the application itself for visual checks such as fonts, colors, or editor behavior.

## 5. Commit

```bash
git status --short
git add <changed-files>
git commit -m "chore: describe the workstation change"
git push
```

Every durable workstation change should be committed to `dotfiles`.
