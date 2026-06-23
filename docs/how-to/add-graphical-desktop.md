# Add Graphical Desktop

Use this guide after the headless bootstrap succeeds and you want an XFCE + XRDP desktop with WezTerm, VS Code, and graphical helper tools.

## Prerequisites

- Completed [First Workstation](../tutorials/first-workstation.md) or [Add Another Machine](add-another-machine.md)
- A working `~/dotfiles` checkout
- Network access and `sudo`

## 1. Fetch the Desktop Script

```bash
wget -qO setup-desktop.sh \
  https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/setup-desktop.sh
chmod +x setup-desktop.sh
```

## 2. Run the Desktop Setup

```bash
./setup-desktop.sh --dotfiles-dir "$HOME/dotfiles"
```

The script installs the graphical layer and wires desktop-specific files that are intentionally outside the headless bootstrap.

## 3. Verify Local Desktop Tools

```bash
flatpak list
systemctl status xrdp --no-pager
code --version
readlink ~/.config/wezterm/wezterm.lua
```

Open WezTerm and confirm:

- the configured font renders icons correctly
- tmux starts or attaches as expected
- terminal colors look correct

## 4. Install VS Code Extensions

The desktop script installs VS Code but does not install extensions. If your dotfiles repo has extension recommendations, install them after VS Code is available:

```bash
jq -r '.recommendations[]' ~/dotfiles/vscode/extensions.json |
  xargs -r -I{} code --install-extension {}
```

Reload VS Code after installing extensions. Project-aware tooling depends on the direnv extension and an already-allowed project directory.

## 5. Verify Remote Desktop

From another machine, connect to the Ubuntu machine with an RDP client using its LAN or VM IP address.

If RDP cannot connect, confirm the machine is reachable, `xrdp` is running, and firewall rules allow RDP.

```bash
hostname -I
systemctl status xrdp --no-pager
sudo ss -tulpn | grep ':3389'
```

Do not keep a local XFCE session open while an XRDP session is active for the same user. XFCE session state can conflict between local display and remote desktop sessions.

## 6. Common Follow-Ups

If WezTerm shows boxes instead of icons, verify the font is installed and that Flatpak can read `/nix`:

```bash
fc-list | grep JetBrains
flatpak info --show-permissions org.wezfurlong.wezterm | grep /nix
```

If RDP opens a black screen, restart `xrdp` and confirm XFCE is installed:

```bash
sudo systemctl restart xrdp
dpkg -l | grep xfce4
```

If VS Code extensions cannot find project tools, open the project after `direnv allow` and reload the VS Code window.
