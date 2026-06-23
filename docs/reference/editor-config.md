# Editor Config

The editor layer supports Neovim with LazyVim and VS Code.

## Neovim

Neovim config lives in the private `dotfiles` repo and is linked into the user config directory.

Checks:

```bash
nvim --version
nvim
```

Inside Neovim:

```vim
:checkhealth
:LspInfo
:Lazy sync
:Mason
```

Project language tools should usually come from `devenv.nix`, not from editor-global installers.

Headless plugin sync:

```bash
nvim --headless "+Lazy! sync" +qa
```

## VS Code

VS Code should use the project environment through the `mkhl.direnv` extension.

Checks:

- confirm the extension is installed
- reload the VS Code window after changing env files
- inspect extension output logs when language tools resolve incorrectly

Recommended extension categories:

| Extension type | Purpose |
|---|---|
| direnv integration | make VS Code inherit project environment |
| language support | syntax, LSP, formatter integration |
| Docker | inspect project services |
| GitHub Pull Requests | review and PR workflow |
| Nix | edit `.nix` files |

## Debuggers

Debuggers often need special treatment because they attach to running processes and may need packages inside a project virtualenv rather than only in `devenv.nix`.

Python debugging commonly needs `debugpy` available in the environment that runs the code. If the adapter starts but breakpoints do not bind, verify both the editor adapter and the project's Python environment:

```bash
which python
python -c "import debugpy; print(debugpy.__version__)"
```

## Expected Files

| File | Purpose |
|---|---|
| `~/dotfiles/nvim/` | user-managed Neovim config |
| `~/.config/nvim` | symlink to `~/dotfiles/nvim` |
| `~/dotfiles/vscode/extensions.json` | VS Code extension recommendations |

## Common Failure States

| Symptom | First check |
|---|---|
| LSP does not attach in Neovim | `:LspInfo` and `which <language-server>` from project shell |
| VS Code finds the wrong formatter | confirm `mkhl.direnv` is installed and reload the window |
| LazyVim plugin errors on first open | run `:Lazy sync` |
| Clipboard does not work | confirm `xclip` or `wl-copy` exists for the session type |
| Neovim and tmux navigation stops at pane boundary | check tmux config and Neovim plugin state |

See [Editor Environment Model](../explanation/editor-environment-model.md).
