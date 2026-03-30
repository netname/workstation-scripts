#!/usr/bin/env bash
# setup-desktop.sh
# Installs XFCE4, LightDM, XRDP, Google Chrome, and polkit shutdown rule.
# Run as a regular sudo user after the Nix bootstrap is complete.
# Safe to re-run (idempotent).
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "${GREEN}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

# — XFCE4 ────────────────────────────────────────────────────────────────────
step "Installing XFCE4"
sudo apt install -y xfce4 xfce4-goodies xfce4-terminal
ok "XFCE4 installed"

# — LightDM ───────────────────────────────────────────────────────────────────
step "Installing LightDM"
DEBIAN_FRONTEND=noninteractive sudo apt install -y \
    lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings
sudo systemctl set-default graphical.target
echo "/usr/sbin/lightdm" | sudo tee /etc/X11/default-display-manager > /dev/null

# Lock greeter to prevent XRDP black screens on future upgrades
sudo bash -c 'cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
greeter-session=lightdm-gtk-greeter
EOF'
ok "LightDM installed and locked"

# — XRDP ──────────────────────────────────────────────────────────────────────
step "Installing XRDP"
sudo apt install -y xrdp
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

# — Polkit – shutdown/restart from XRDP sessions ──────────────────────────────
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

# — Google Chrome ──────────────────────────────────────────────────────────────
step "Installing Google Chrome"
if ! command -v google-chrome &>/dev/null; then
    wget -q -O /tmp/google-chrome.deb \
        https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt install -y /tmp/google-chrome.deb || sudo apt -f install -y
    rm -f /tmp/google-chrome.deb
    ok "Google Chrome installed"
else
    ok "Google Chrome already installed – skipping"
fi

echo ""
echo -e "${GREEN}✅ Desktop setup complete.${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot to activate the display manager: sudo reboot"
echo "  2. Connect via RDP from Windows (see §L.3 for connection settings)"
echo "  3. Configure window tiling shortcuts (§L.5)"
warn "Do not keep a local XFCE session open while an XRDP session is active."
