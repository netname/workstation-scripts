# Templates

Workstation templates are copied into the private `dotfiles` repository by `scripts/init-dotfiles.sh`. Project starter templates are copied manually into project repositories when starting a project.

## Home Manager Entrypoints

| Template | Destination | Purpose |
|---|---|---|
| `templates/flake.nix` | `flake.nix` | Home Manager flake entry point |
| `templates/home.nix` | `home.nix` | Compatibility wrapper that imports the workstation host profile |
| `templates/homes/` | `homes/` | User identity modules |
| `templates/hosts/` | `hosts/` | Machine profile modules |
| `templates/modules/` | `modules/` | Shared Home Manager modules |

## Secret Management

| Template | Destination | Purpose |
|---|---|---|
| `templates/.sops.yaml` | `.sops.yaml` | SOPS creation rules |
| `templates/secrets/` | `secrets/` | Encrypted secret file location |
| `templates/check-secrets.sh` | `scripts/check-secrets.sh` | Placeholder guardrail |

## Project Starters

These templates are not copied by `scripts/init-dotfiles.sh`. Copy them into each project repository that needs them.

| Template | Destination | Purpose |
|---|---|---|
| `templates/devenv.nix` | project root | Project-local tools |
| `templates/docker-compose.yml` | project root | Local stateful services |
| `templates/.env.example` | project root | Example environment values |

## User-Managed Helpers

| Template | Destination | Purpose |
|---|---|---|
| `templates/sessionizer` | `scripts/sessionizer` | tmux project switcher |

## Generated Placeholders

`scripts/init-dotfiles.sh` also creates these files and directories in the private `dotfiles` repo:

| Generated path | Purpose |
|---|---|
| `wezterm/wezterm.lua` | User-managed WezTerm config placeholder |
| `tmux/tmux.conf` | User-managed tmux config placeholder |
| `nvim/init.lua` | Initial Neovim config placeholder before LazyVim is staged |
| `nvim/lua/config/` | Neovim config directory |
| `nvim/lua/plugins/` | Neovim plugin directory |
| `vscode/extensions.json` | VS Code extension recommendations |
| `scripts/sessionizer` | Executable sessionizer helper |
| `scripts/check-secrets.sh` | Executable SOPS placeholder check |
| `xfce4/` | Desktop configuration location for later use |
| `.gitignore` | Ignores plaintext local env files and local build outputs |

## Placeholder Replacement

The initializer replaces `CHANGE_ME` in Nix files with the Linux username passed through `--linux-user`. If `--git-name` and `--git-email` are provided, it also replaces `YOUR_FULL_NAME` and `YOUR_EMAIL` in `modules/git.nix`.

If any Nix placeholders remain, the initializer leaves the generated repo uncommitted so you can edit the values before making the first commit.

After generation, the private `dotfiles` repo is the source of truth. Changes made there are not automatically copied back into `templates/`.
