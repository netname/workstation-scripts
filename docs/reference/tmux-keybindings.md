# tmux Keybindings

This reference documents the expected tmux interaction model for the workstation templates. The exact bindings live in the private dotfiles repo at `~/dotfiles/tmux/tmux.conf`.

## Reload

After editing tmux configuration:

```bash
tmux source-file ~/.config/tmux/tmux.conf
```

If the config defines a reload binding, use prefix then `r`.

## Sessions

```bash
tmux new -s work
tmux attach -t work
tmux list-sessions
tmux kill-session -t work
```

Common bindings:

| Action | Typical binding |
|---|---|
| Detach | prefix then `d` |
| New session | shell command `tmux new -s <name>` |
| Switch session | prefix then `s` |
| Rename session | prefix then `$` |

## Windows

| Action | Typical binding |
|---|---|
| New window | prefix then `c` |
| Rename window | prefix then `,` |
| Next window | prefix then `n` |
| Previous window | prefix then `p` |
| Choose window | prefix then `w` |
| Kill window | prefix then `&` |

## Panes

| Action | Typical binding |
|---|---|
| Split horizontally | prefix then `"` |
| Split vertically | prefix then `%` |
| Move between panes | prefix then arrow key, or configured Vim-style movement |
| Resize pane | prefix then hold arrow key, or configured resize keys |
| Zoom pane | prefix then `z` |
| Kill pane | prefix then `x` |

## Copy Mode

| Action | Typical binding |
|---|---|
| Enter copy mode | prefix then `[` |
| Search | `/` in copy mode |
| Copy selection | depends on config, commonly `Enter` |
| Paste buffer | prefix then `]` |

## Neovim Integration

If the dotfiles include `vim-tmux-navigator`, pane movement can cross between Neovim splits and tmux panes. When that stops working, check both sides:

```bash
tmux show-options -g | grep -i focus
nvim --headless "+Lazy! sync" +qa
```

Also verify that Neovim is reading the expected config:

```bash
nvim --version
```

## TPM Plugins

If tmux plugins are declared through TPM, install or refresh them from inside tmux with the configured TPM install binding, commonly prefix then `I`.

Plugin issues are usually caused by one of these:

- TPM is not installed.
- `tmux.conf` is not symlinked or loaded.
- The prefix key is different from what the user expects.
- The plugin manager binding has not been run in this tmux server.
