#!/usr/bin/env bash
# setup-desktop.sh
# Installs the graphical desktop layer on top of the Nix bootstrap.
# Run as a regular sudo user AFTER bootstrap.sh has completed.
# Safe to re-run (idempotent).
#
# What this script installs:
#   1.  XFCE4 + LightDM (desktop environment + display manager)
#   2.  XRDP (remote desktop via Windows RDP client)
#   3.  Polkit shutdown rule (power off / reboot from XRDP sessions)
#   4.  Google Chrome
#   5.  Noto fonts (glyph fallback for WezTerm — covers U+23F5 and similar)
#   7.  WezTerm via Flatpak (terminal emulator)
#   8.  wezterm.lua symlink (from ~/dotfiles)
#   9.  VS Code via apt (NOT snap — snap blocks /nix/store access)
#   10. ksnip (screenshot + annotation tool)
#   11. Set WezTerm as XFCE default terminal + Ctrl+Alt+T shortcut
#
# VS Code extensions are NOT installed by this script — install them manually
# after first login (see §11.3 of the guide):
#   grep -v '^#\|^$' ~/dotfiles/vscode/extensions.txt | xargs -I{} code --install-extension {}
#
# JetBrainsMono Nerd Font is installed by Home Manager (home.nix → nerd-fonts.jetbrains-mono).
# No manual font download is required here.
#
# After this script: reboot, then connect via RDP (see §Installation Step 6).
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "${GREEN}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

# !! EDIT THIS to your GitHub username before running !!
GITHUB_USER="yourusername"
DOTFILES_DIR="$HOME/dotfiles"

# ── 1. XFCE4 ─────────────────────────────────────────────────────────────────
step "Installing XFCE4"
sudo apt-get install -y xfce4 xfce4-goodies xfce4-terminal
ok "XFCE4 installed"

# ── 2. LightDM ────────────────────────────────────────────────────────────────
step "Installing LightDM"
DEBIAN_FRONTEND=noninteractive sudo apt-get install -y \
    lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
sudo systemctl set-default graphical.target
echo "/usr/sbin/lightdm" | sudo tee /etc/X11/default-display-manager > /dev/null

# Lock greeter to prevent XRDP black screens on future upgrades
sudo bash -c 'cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
greeter-session=lightdm-gtk-greeter
EOF'
ok "LightDM installed and locked"

# ── 3. XRDP ───────────────────────────────────────────────────────────────────
step "Installing XRDP"
sudo apt-get install -y xrdp
sudo systemctl enable xrdp
sudo adduser xrdp ssl-cert

# XFCE session files – tell XRDP which desktop to launch
echo "startxfce4" > ~/.xsession
{
    echo "export DESKTOP_SESSION=xfce"
    echo "export XDG_SESSION_DESKTOP=xfce"
} >> ~/.xsessionrc

sudo systemctl restart xrdp
ok "XRDP installed and configured"

# ── 4. Polkit – shutdown/restart from XRDP sessions ──────────────────────────
step "Configuring polkit shutdown rule"
sudo tee /etc/polkit-1/rules.d/85-shutdown.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.login1.power-off" ||
         action.id == "org.freedesktop.login1.reboot") &&
         subject.isInGroup("sudo") && subject.active) {
        return polkit.Result.YES;
    }
});
EOF
sudo systemctl restart polkit
ok "Polkit shutdown rule applied"

# ── 5. Google Chrome ──────────────────────────────────────────────────────────
step "Installing Google Chrome"
if ! command -v google-chrome &>/dev/null; then
    wget -q -O /tmp/google-chrome.deb \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt-get install -y /tmp/google-chrome.deb || sudo apt-get -f install -y
    rm -f /tmp/google-chrome.deb
    ok "Google Chrome installed"
else
    ok "Google Chrome already installed – skipping"
fi

# ── 6. Noto fonts (glyph fallback) ───────────────────────────────────────────
# Provides Noto Sans Symbols 2 which covers U+23F5 (⏵) and the full
# Miscellaneous Technical Unicode block. JetBrainsMono Nerd Font v3.2.1 omits
# these codepoints; WezTerm uses Noto as a fallback (configured in wezterm.lua).
step "Installing Noto fonts (glyph fallback for WezTerm)"
sudo apt-get install -y fonts-noto fonts-noto-core
fc-cache -fv >/dev/null 2>&1
ok "Noto fonts installed"

# ── 7. WezTerm via Flatpak ────────────────────────────────────────────────────
step "Installing WezTerm"
sudo apt-get install -y flatpak xdg-desktop-portal-gtk
if ! command -v wezterm &>/dev/null && ! flatpak list --user 2>/dev/null | grep -q wezterm; then
    flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub org.wezfurlong.wezterm
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.local/share/flatpak/exports/bin/org.wezfurlong.wezterm" \
        "$HOME/.local/bin/wezterm"
    ok "WezTerm installed via Flatpak (user install)"
else
    ok "WezTerm already installed – skipping"
fi

# Grant WezTerm's Flatpak sandbox read access to the Nix store.
# Home Manager installs JetBrainsMono Nerd Font into /nix/store and exposes it
# via ~/.nix-profile/share/fonts. Flatpak's bubblewrap sandbox does not mount
# /nix by default, so WezTerm cannot follow the symlink chain to the actual
# font files — producing the "Unable to load font" warning on startup.
flatpak override --user --filesystem=/nix:ro org.wezfurlong.wezterm
ok "Flatpak /nix access granted (Nix-managed fonts now visible to WezTerm)"

# ── 8. wezterm.lua symlink ────────────────────────────────────────────────────
step "Symlinking wezterm.lua"
mkdir -p "$HOME/.config/wezterm"
if [ -f "$DOTFILES_DIR/wezterm/wezterm.lua" ]; then
    ln -sf "$DOTFILES_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
    ok "wezterm.lua symlinked"
else
    warn "~/dotfiles/wezterm/wezterm.lua not found – skipping symlink"
fi

# ── 9. VS Code ───────────────────────────────────────────────────────────────
# apt repository – NOT snap (snap sandboxing blocks /nix/store access,
# breaking the mkhl.direnv extension and devenv PATH resolution).
step "Installing VS Code"
if ! command -v code &>/dev/null; then
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor \
        | sudo dd of=/etc/apt/keyrings/packages.microsoft.gpg >/dev/null 2>&1
    echo "deb [arch=amd64,arm64,armhf \
signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y code
    ok "VS Code installed via apt"
else
    ok "VS Code already installed – skipping"
fi

# ── 10. ksnip ────────────────────────────────────────────────────────────────
step "Installing ksnip"
if ! command -v ksnip &>/dev/null; then
    sudo apt-get install -y ksnip
    ok "ksnip installed"
else
    ok "ksnip already installed – skipping"
fi

# ── 11. Set WezTerm as default terminal ─────────────────────────────────────
# xfconf-query sets XFCE4 configuration values without opening the GUI.
# These take effect immediately for new sessions; no reboot required for this step.
step "Configuring WezTerm as default terminal"

# XFCE preferred terminal emulator — used by "Open Terminal Here", exo-open, etc.
xfconf-query -c xfce4-mime-helpers -p "/TerminalEmulator" \
    --create -t string -s "wezterm" 2>/dev/null || \
xfconf-query -c xfce4-mime-helpers -p "/TerminalEmulator" \
    -s "wezterm" 2>/dev/null || \
warn "Could not set XFCE preferred terminal via xfconf-query (safe to set manually via Settings → Preferred Applications)"

# Ctrl+Alt+T keyboard shortcut → WezTerm
xfconf-query -c xfce4-keyboard-shortcuts \
    -p "/commands/custom/<Primary><Alt>t" \
    --create -t string -s "wezterm start" 2>/dev/null || \
xfconf-query -c xfce4-keyboard-shortcuts \
    -p "/commands/custom/<Primary><Alt>t" \
    -s "wezterm start" 2>/dev/null || \
warn "Could not set Ctrl+Alt+T shortcut (safe to set manually via Settings → Keyboard → Application Shortcuts)"

ok "WezTerm set as default terminal (Ctrl+Alt+T)"

echo ""
echo -e "${GREEN}✅ Desktop setup complete.${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot to activate the display manager: sudo reboot"
echo "  2. Connect via RDP from Windows (see §Installation Step 6 for settings)"
echo "  3. Ctrl+Alt+T opens WezTerm; configure tiling shortcuts via §Installation Step 6"
warn "Do not keep a local XFCE session open while an XRDP session is active."
