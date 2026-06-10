> **Development Workstation** · [Overview](0-Overview.md) · [Stack](1-Stack.md) · [Installation](2-Installation.md) · [Terminal](3-Terminal.md) · [Projects](4-Projects.md) · [Editors](5-Editors.md) · [Desktop](6-Desktop.md) · **Troubleshooting** · [Workflows](8-DevWorkflows.md)

## Troubleshooting

Each entry below states the symptom, explains the likely cause, and gives the fix commands. Entries are grouped by the phase of the journey where you are most likely to encounter them.

### Installation

### Nix Installation Fails

**Symptom:** `curl: (6) Could not resolve host: install.determinate.systems` **Cause:** Network connectivity issue. **Resolution:** Verify internet access (`ping google.com`). If behind a proxy, configure `https_proxy` before running the installer.

**Symptom:** `error: the user 'nobody' does not exist` **Cause:** Rare on Ubuntu minimal installs — the `nobody` system user is missing. **Resolution:**

```bash
sudo useradd -r nobody
# Then re-run the bootstrap from step 3
```

---

### `hms` (`home-manager switch`) Errors

**Symptom:** `error: attribute 'yourusername' missing` **Cause:** The username string after `#` in the switch command does not match the `homeConfigurations` key in `flake.nix`. **Resolution:** Confirm `whoami` matches the key in `flake.nix` and `home.nix`:

```bash
whoami
grep "homeConfigurations" ~/dotfiles/flake.nix
```

**Symptom:** `error: undefined variable 'pkgs'` or Nix syntax error with a line number **Cause:** Syntax error in `home.nix`. **Resolution:** Open `home.nix`, go to the reported line, fix the syntax. Common mistakes: missing semicolons in Nix expressions, unclosed braces, wrong attribute path.

**Symptom:** `error: package 'xyz' not found` **Cause:** A package name in `home.packages` does not exist in nixpkgs. **Resolution:** Search the correct attribute name at `search.nixos.org/packages`. Nix package names are not always the same as the tool's binary name.

**Symptom:** Step hangs for more than 30 minutes without output **Cause:** Slow or stalled package download from `cache.nixos.org`. **Resolution:** Press `Ctrl-C` to abort. Check internet connectivity. Re-run the bootstrap — Nix downloads are resumable and will pick up where they left off.

---

### Terminal Workspace

### WezTerm Shows Boxes instead of Icons

**Symptom:** Powerline separators in the tmux status bar appear as `□` or `?`. File icons in Neovim's file explorer are missing. **Cause:** Either the Nerd Font is not installed, WezTerm is configured with the wrong font name, or Flatpak's sandbox is blocking access to Nix-managed fonts.

**Diagnosis — check if font is installed:**

```bash
fc-list | grep JetBrains
```

If this returns nothing: the bootstrap font installation failed. Re-run manually:

```bash
mkdir -p ~/.local/share/fonts/JetBrainsMono
cd /tmp && curl -fLo JetBrainsMono.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.zip
unzip JetBrainsMono.zip -d ~/.local/share/fonts/JetBrainsMono/
fc-cache -fv
```

If `fc-list | grep JetBrains` returns output but WezTerm still shows the _"Unable to load a font"_ warning: WezTerm is installed via Flatpak and its sandbox cannot follow the symlink `~/.nix-profile/share/fonts → /nix/store/...`. Fix by granting Flatpak read access to the Nix store:

```bash
flatpak override --user --filesystem=/nix:ro org.wezfurlong.wezterm
```

Then restart WezTerm. This is now applied automatically by `setup-desktop.sh`.

If the font is installed and Flatpak access is granted but boxes persist: the family name in `wezterm.lua` is wrong. Use the exact name from `fc-list` output:

```bash
fc-list | grep JetBrains | head -3
# The family name is the second field: "JetBrainsMono Nerd Font"
```

---

### Tmux Colours Look Wrong in Neovim

**Symptom:** Neovim's colour scheme uses muted, incorrect colours instead of the expected vibrant ones. **Cause:** The two required tmux true-colour lines are missing or one is incorrect. **Diagnosis:**

```vim
:checkhealth
" Look for a termguicolors warning
```

**Resolution:** Verify both lines are present in `tmux.conf` and that the `terminal-overrides` value matches your WezTerm `term` setting ([3-Terminal.md §4.4](3-Terminal.md); the WezTerm `term` tradeoff is in [3-Terminal.md §3.3](3-Terminal.md)):

```bash
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",wezterm:Tc"        # if wezterm.lua: term = "wezterm"
# set -ga terminal-overrides ",xterm-256color:Tc" # if wezterm.lua: term = "xterm-256color"
```

Reload with `prefix r`.

---

### Escape in Neovim Feels Laggy

**Symptom:** Pressing Escape to leave insert mode has a noticeable half-second delay. **Cause:** `escape-time` is not set to 0 in `tmux.conf`. **Resolution:** Add or verify in `tmux.conf`:

```bash
set -sg escape-time 0
```

Reload with `prefix r`. Verify: `tmux show-options -g escape-time` must output `0`.

---

### Direnv not Activating in New Tmux Panes

**Symptom:** Opening a new tmux pane in a project directory does not activate the devenv environment. The existing session has it active but new panes do not. **Cause:** The direnv hook is initialised too late in `.zshrc` — tmux fires the initial window command before the hook is loaded. **Resolution:** In `home.nix` `programs.zsh.initContent`, move `eval "$(direnv hook zsh)"` to position 3 — after PATH and Nix sourcing, before zoxide and fzf. The correct full load order is in [3-Terminal.md §7.4](3-Terminal.md).

---

### LazyVim Shows Errors on First Open

**Symptom:** Neovim opens with red error messages about missing plugins or modules. **Cause:** The headless plugin sync in bootstrap step 11 failed or timed out. **Resolution:** Run the sync interactively:

```vim
:Lazy sync
```

Wait 1–3 minutes for all plugins to install. Restart Neovim.

---

### Project Environments

### Direnv not Activating on `cd`

**Symptom:** Entering a project directory does not activate the devenv environment. `which python` shows a system path.

**Cause 1:** `direnv allow` has not been run in this directory. **Resolution:** `direnv allow` (run once per developer per repo).

**Cause 2:** The direnv hook is initialised too late in `.zshrc`. **Symptom detail:** This specifically affects the first pane in new tmux sessions — tmux fires the initial window command before `.zshrc` finishes. **Resolution:** In `home.nix` `programs.zsh.initContent`, move `eval "$(direnv hook zsh)"` to position 3 in the load order (after PATH and Nix profile, before zoxide and fzf). See [3-Terminal.md §7.4](3-Terminal.md).

**Cause 3:** nix-direnv is not enabled in `home.nix`. **Resolution:** Verify `programs.direnv.nix-direnv.enable = true` in `home.nix` and run `hms`.

---

### Devenv Binary not Found after `devenv init`

**Symptom:** `devenv: command not found` after the bootstrap. **Cause:** The Nix profile PATH is not active in the current shell session. **Resolution:**

```bash
. "$HOME/.nix-profile/etc/profile.d/nix.sh"
devenv --version
```

If this works, the issue is the shell load order — the Nix profile sourcing line in `home.nix` `initContent` must run before any command that depends on Nix-installed binaries. Open a new terminal to get the fully-loaded shell.

---

### `docker ps` Returns Permission Denied

**Symptom:** `permission denied while trying to connect to the Docker daemon socket` **Cause:** The Docker group membership added by the bootstrap has not taken effect — it requires a session boundary. **Resolution:** Log out of the Ubuntu desktop session and log back in. Then:

```bash
docker ps
# Should return empty container list, no error
```

Temporary workaround for the current terminal session only:

```bash
newgrp docker
```

---

### Editors

### VS Code Cannot Find Python Interpreter or Uses Wrong Binary Version

**Symptom:** VS Code shows "Python interpreter not found" or the Ruff extension uses a different version than the terminal. **Cause:** `mkhl.direnv` extension is not installed or not active. VS Code is using the system `$PATH` instead of devenv's. **Resolution:**

1. Confirm `direnv allow` has been run in the project directory:

```bash
direnv status
```

2. Confirm `mkhl.direnv` is installed in VS Code:

```
View → Extensions → search "direnv"
```

3. If installed but not active, reload the VS Code window:

```
Ctrl+Shift+P → "Developer: Reload Window"
```

4. Verify in Output panel: `View → Output → select "Ruff"` — binary path must start with `/nix/store/`.

See [4-Projects.md §8.5](4-Projects.md) for the full `$PATH` flow diagram.

---

### Neovim LSP not Attaching

**Symptom:** `:LspInfo` shows no attached servers, or the server shows a Mason binary path instead of `/nix/store/`.

**Cause 1:** `mason = false` is not set for the server in `lua/plugins/lsp.lua`. **Resolution:** Add `mason = false` to the server's entry in `lsp.lua`. Restart Neovim.

**Cause 2:** The devenv environment is not active — Neovim was opened outside the project directory or before `direnv allow` was run. **Resolution:**

```bash
cd ~/projects/my-project
direnv allow   # if not already done
which pyright-langserver   # must show /nix/store/...
nvim app/main.py
```

**Cause 3:** The LazyExtra for this language is not enabled. **Resolution:** Run `:LazyExtras` in Neovim, find the language extra, enable it with `x`.

---

### Neovim Clipboard not Working

**Symptom:** `yy` in Neovim does not paste in the browser. `p` in Neovim does not paste from the browser. **Cause:** Either `vim.opt.clipboard = "unnamedplus"` is not set, or the clipboard provider is missing. **Resolution:**

1. Confirm the setting in `~/dotfiles/nvim/lua/config/options.lua`:

```lua
vim.opt.clipboard = "unnamedplus"
```

2. Confirm the clipboard provider is installed:

```bash
echo $XDG_SESSION_TYPE    # x11 or wayland
which xclip               # for X11
which wl-copy             # for Wayland
```

If missing, add `pkgs.xclip` or `pkgs.wl-clipboard` to `home.nix` packages and run `hms`.

---
*This is the last document in the series. Return to [Overview](0-Overview.md) to navigate.*
