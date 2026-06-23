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
#   6.  WezTerm via Flatpak (terminal emulator)
#   7.  wezterm.lua symlink (from ~/dotfiles)
#   8.  VS Code via apt (NOT snap — snap blocks /nix/store access)
#   9.  ksnip (screenshot + annotation tool)
#   10. Set WezTerm as XFCE default terminal + Ctrl+Alt+T shortcut
#
# VS Code extensions are NOT installed by this script — install them manually
# after first login (see docs/how-to/add-graphical-desktop.md):
#   jq -r '.recommendations[]' ~/dotfiles/vscode/extensions.json | xargs -I{} code --install-extension {}
#
# JetBrainsMono Nerd Font is installed by Home Manager (modules/cli-tools.nix -> nerd-fonts.jetbrains-mono).
# No manual font download is required here.
#
# After this script: reboot, then connect via RDP.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "${GREEN}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
die()  { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

usage() {
    cat <<'EOF'
Usage: setup-desktop.sh [options]

Options:
  --dotfiles-dir PATH      Local dotfiles checkout path (default: ~/dotfiles)
  -h, --help               Show this help

Environment variable with the same name is also supported:
  DOTFILES_DIR
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dotfiles-dir)
            [ "$#" -ge 2 ] || die "--dotfiles-dir requires a value"
            DOTFILES_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            die "Unknown option: $1 (run --help)"
            ;;
    esac
done

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_config() {
    [ -n "$DOTFILES_DIR" ] || die "DOTFILES_DIR cannot be empty"
    case "$DOTFILES_DIR" in
        /*) ;;
        *) die "DOTFILES_DIR must be an absolute path" ;;
    esac
    [ "$DOTFILES_DIR" != "/" ] || die "DOTFILES_DIR cannot be /"
    [ -d "$DOTFILES_DIR" ] || die "$DOTFILES_DIR does not exist. Run bootstrap.sh first."
    [ -d "$DOTFILES_DIR/.git" ] || die "$DOTFILES_DIR exists but is not a git repository"
    [ -f "$DOTFILES_DIR/flake.nix" ] || die "$DOTFILES_DIR/flake.nix not found. Run bootstrap.sh first."
    [ -f "$DOTFILES_DIR/home.nix" ] || die "$DOTFILES_DIR/home.nix not found. Run bootstrap.sh first."
}

validate_host() {
    require_command apt-get
    require_command systemctl
    require_command getent

    [ -r /etc/os-release ] || die "/etc/os-release not found; this script supports Ubuntu 22.04, 24.04, and 26.04"
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "${ID:-}" = "ubuntu" ] || die "Unsupported OS: ${PRETTY_NAME:-unknown}. Use Ubuntu 22.04, 24.04, or 26.04."
    case "${VERSION_ID:-}" in
        22.04|24.04|26.04) ;;
        *) die "Unsupported Ubuntu version: ${VERSION_ID:-unknown}. Use Ubuntu 22.04, 24.04, or 26.04." ;;
    esac

    case "$(uname -m)" in
        x86_64) ;;
        *) die "Unsupported architecture: $(uname -m). This desktop script installs amd64 GUI packages." ;;
    esac

    [ -d /run/systemd/system ] || die "systemd does not appear to be running"
    getent hosts github.com >/dev/null || die "Cannot resolve github.com; check internet/DNS before desktop setup"
}

print_config() {
    echo "Resolved configuration:"
    echo "  Dotfiles dir: $DOTFILES_DIR"
    echo ""
}

ensure_dotfiles_compat_link() {
    local default_dir="$HOME/dotfiles"
    local target_real
    local default_real

    [ "$DOTFILES_DIR" != "$default_dir" ] || return 0

    target_real="$(cd "$DOTFILES_DIR" && pwd -P)"

    if [ -e "$default_dir" ] || [ -L "$default_dir" ]; then
        [ -d "$default_dir" ] || die "$default_dir exists but is not a directory or symlink to a directory"
        default_real="$(cd "$default_dir" && pwd -P)"
        [ "$default_real" = "$target_real" ] || die "$default_dir already points to a different directory. Move it or use --dotfiles-dir $default_dir."
        ok "$default_dir already points to $DOTFILES_DIR"
    else
        ln -s "$DOTFILES_DIR" "$default_dir"
        ok "Created compatibility symlink: $default_dir -> $DOTFILES_DIR"
    fi
}

echo -e "${GREEN}Starting desktop setup...${NC}"
step "Running preflight checks"
validate_config
validate_host
print_config
ensure_dotfiles_compat_link
sudo -v
ok "Preflight checks passed"

if [ ! -f "$DOTFILES_DIR/wezterm/wezterm.lua" ]; then
    warn "$DOTFILES_DIR/wezterm/wezterm.lua not found; WezTerm will use defaults until you add it"
fi

step "Updating apt metadata"
sudo apt-get update -qq
ok "apt metadata updated"

# ── 1. XFCE4 ─────────────────────────────────────────────────────────────────
step "Installing XFCE4"
sudo apt-get install -y xfce4 xfce4-goodies xfce4-terminal
ok "XFCE4 installed"

# ── 2. LightDM ────────────────────────────────────────────────────────────────
step "Installing LightDM"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
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
echo "startxfce4" > "$HOME/.xsession"
cat > "$HOME/.xsessionrc" <<'EOF'
export DESKTOP_SESSION=xfce
export XDG_SESSION_DESKTOP=xfce
EOF

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
    (
        CHROME_DEB="$(mktemp /tmp/google-chrome.XXXXXX.deb)"
        trap 'rm -f "$CHROME_DEB"' EXIT
        wget -q -O "$CHROME_DEB" \
            https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt-get install -y "$CHROME_DEB" || sudo apt-get -f install -y
    )
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
if ! command -v wezterm &>/dev/null && ! flatpak info --user org.wezfurlong.wezterm >/dev/null 2>&1; then
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

if flatpak info --user org.wezfurlong.wezterm >/dev/null 2>&1; then
    # Grant WezTerm's Flatpak sandbox read access to the Nix store.
    # Home Manager installs JetBrainsMono Nerd Font into /nix/store and exposes it
    # via ~/.nix-profile/share/fonts. Flatpak's bubblewrap sandbox does not mount
    # /nix by default, so WezTerm cannot follow the symlink chain to the actual
    # font files — producing the "Unable to load font" warning on startup.
    flatpak override --user --filesystem=/nix:ro org.wezfurlong.wezterm
    ok "Flatpak /nix access granted (Nix-managed fonts now visible to WezTerm)"
else
    warn "WezTerm Flatpak not installed for this user; skipping Flatpak /nix override"
fi

# ── 8. wezterm.lua symlink ────────────────────────────────────────────────────
step "Symlinking wezterm.lua"
mkdir -p "$HOME/.config/wezterm"
if [ -f "$DOTFILES_DIR/wezterm/wezterm.lua" ]; then
    ln -sf "$DOTFILES_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
    ok "wezterm.lua symlinked"
else
    warn "$DOTFILES_DIR/wezterm/wezterm.lua not found – skipping symlink"
fi

# ── 9. VS Code ───────────────────────────────────────────────────────────────
# apt repository – NOT snap (snap sandboxing blocks /nix/store access,
# breaking the mkhl.direnv extension and devenv PATH resolution).
step "Installing VS Code"
if ! command -v code &>/dev/null; then
    sudo install -m 0755 -d /etc/apt/keyrings
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --batch --yes --dearmor \
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
# Always force-set: XFCE pre-populates this key with "exo-open --launch TerminalEmulator",
# so --create fails (key exists) and the fallback without --create overwrites it correctly.
# Using a single unconditional reset avoids the create/update ambiguity entirely.
xfconf-query -c xfce4-keyboard-shortcuts \
    -p "/commands/custom/<Primary><Alt>t" \
    --reset 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts \
    -p "/commands/custom/<Primary><Alt>t" \
    --create -t string -s "wezterm start" 2>/dev/null || \
warn "Could not set Ctrl+Alt+T shortcut (safe to set manually via Settings → Keyboard → Application Shortcuts)"

ok "WezTerm set as default terminal (Ctrl+Alt+T)"

echo ""
echo -e "${GREEN}✅ Desktop setup complete.${NC}"
echo ""
echo "Next steps:"
echo "  1. Reboot to activate the display manager: sudo reboot"
echo "  2. Connect via RDP from Windows (see docs/how-to/add-graphical-desktop.md)"
echo "  3. Ctrl+Alt+T opens WezTerm"
echo "  4. Verify the desktop with docs/how-to/add-graphical-desktop.md#3-verify-local-desktop-tools"
echo ""
echo "Verification commands after reboot:"
echo "  systemctl status xrdp --no-pager"
echo "  flatpak list --user | grep wezterm"
echo "  code --version"
echo "  readlink ~/.config/wezterm/wezterm.lua"
warn "Do not keep a local XFCE session open while an XRDP session is active."
