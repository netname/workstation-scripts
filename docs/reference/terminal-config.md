# Terminal Config

The terminal layer includes WezTerm, tmux, sessionizer, fonts, and shell helpers.

## Ownership

| Area | Owner | Apply |
|---|---|---|
| WezTerm config | user-managed dotfile | `SUPER+SHIFT+R` |
| tmux config | user-managed dotfile | `prefix r` |
| sessionizer | user-managed script | next invocation |
| zsh, PATH, starship, direnv hook | Home Manager | `hms` and new shell |
| fonts | Home Manager or desktop setup | new app session |

## Key Checks

```bash
echo "$SHELL"
tmux -V
tmux show-options -g escape-time
fc-list | grep JetBrains
direnv status
zoxide query .
fzf --version
```

## Common Boundaries

- tmux panes depend on shell initialization order.
- direnv must load before project tools are expected in panes.
- WezTerm font rendering depends on the configured font name and desktop font access.
- `sessionizer` is re-executed on each use, so edits do not need a rebuild.
- zoxide must initialize after the `cd` alias if `cd` should route through zoxide.
- Starship should initialize last because it wraps the prompt.

## Expected Files

| File | Expected after initialization |
|---|---|
| `~/dotfiles/wezterm/wezterm.lua` | user-managed WezTerm config |
| `~/dotfiles/tmux/tmux.conf` | user-managed tmux config |
| `~/dotfiles/scripts/sessionizer` | executable project picker |
| `~/.config/tmux/tmux.conf` | symlink to dotfiles through Home Manager |
| `~/.local/bin/sessionizer` | symlink created by bootstrap |

## Shell Initialization Order

The generated shell template intentionally orders startup like this:

1. Add `~/.local/bin` and the Nix profile to `PATH`.
2. Source the Nix profile script when available.
3. Initialize direnv early.
4. Alias `cd` to `z`.
5. Initialize zoxide.
6. Let Home Manager source fzf integration.
7. Initialize Starship last.

This order keeps project tools visible in tmux panes and avoids prompt corruption.

## Sessionizer

`sessionizer` is a user-managed executable helper. The bootstrap links it into `~/.local/bin/sessionizer`.

The template scans each directory in `SEARCH_ROOTS` one level deep and adds each directory in `PINNED_PATHS` directly. By default, this offers projects under `~/projects/` and the `~/dotfiles` repo itself.

Check it with:

```bash
command -v sessionizer
readlink ~/.local/bin/sessionizer
sessionizer
```

If the script is missing, confirm `~/dotfiles/scripts/sessionizer` exists and rerun the bootstrap or recreate the symlink.

## tmux

Use [tmux Keybindings](tmux-keybindings.md) for the command and binding reference.

Key checks:

```bash
tmux list-sessions
tmux source-file ~/.config/tmux/tmux.conf
readlink ~/.config/tmux/tmux.conf
```

## Common Failure States

| Symptom | First check |
|---|---|
| Icons render as boxes | `fc-list | grep JetBrains` |
| WezTerm cannot load fonts | `flatpak info --show-permissions org.wezfurlong.wezterm` |
| New tmux panes miss project tools | confirm direnv hook order in `modules/shell.nix` |
| `sessionizer` is not found | `readlink ~/.local/bin/sessionizer` |
| prompt looks broken | confirm Starship initializes after other shell hooks |
