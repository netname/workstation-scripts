#!/usr/bin/env bash
# bootstrap.sh
# Idempotent workstation setup script.
# Lives in: workstation-scripts/ (PUBLIC repo) – fetched via curl
# Run with: wget -qO bootstrap.sh https://raw.githubusercontent.com/netname/workstation-scripts/main/bootstrap.sh && bash bootstrap.sh
#
# What this script does:
#   1.  Installs system dependencies and sets zsh as the login shell
#   2.  Verifies the SSH key is present and authenticated with GitHub
#   3.  Clones your PRIVATE dotfiles repo via SSH
#   4.  Installs Nix (Determinate Systems installer)
#   5.  Applies Home Manager from your flake (owns git identity + config)
#   6.  Installs WezTerm via Flatpak
#   7.  Installs JetBrainsMono Nerd Font
#   8.  Installs Docker Engine
#   9.  Verifies GitHub CLI (installed by Home Manager; apt fallback)
#   10. Configures gh pager (delta – not manageable via Home Manager)
#   11. Installs Gemini CLI + Conductor + Context7 MCP
#   12. Symlinks user-managed dotfiles (WezTerm, tmux, sessionizer)
#         ↑ Must precede TPM and LazyVim: both need symlinks in place
#           before their headless installs can locate the config files.
#   13. Installs tmux Plugin Manager and plugins headlessly
#   14. Stages LazyVim starter into dotfiles
#   15. Runs LazyVim headless plugin sync
#   16. Installs VS Code via apt repository
#   17. Installs VS Code extensions (from dotfiles/vscode/extensions.txt)
#
# NOTE: git identity (user.name, user.email), delta pager, and aliases are
# managed entirely by Home Manager via programs.git in home.nix. The bootstrap
# script does NOT write any git config.
#
# PREREQUISITE: Generate and register your SSH key on GitHub before running
# this script. The bootstrap runs fully automatically with no pauses once the
# key is in place.

set -euo pipefail

# Cache sudo credentials up front so subsequent sudo calls don't need a TTY.
sudo -v

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "${GREEN}▶ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $1${NC}"; }
ok()    { echo -e "${GREEN}✓ $1${NC}"; }

# ── Variables ─────────────────────────────────────────────────────────────────
GITHUB_USER="netname"
DOTFILES_REPO="git@github.com:netname/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"
NERD_FONT_VERSION="v3.2.1"
NERD_FONT_NAME="JetBrainsMono"

echo -e "${GREEN}🚀 Starting workstation bootstrap...${NC}"

# ── Pre-flight: create user-owned XDG directories ────────────────────────────
# Must run before any sudo call. Some sudo-invoked tools (apt, gpg) implicitly
# create ~/.config/ owned by root, which causes "Permission denied" errors in
# any later user-space write to that tree.
step "Pre-creating user-owned directories"
mkdir -p \
    "$HOME/.config/git" \
    "$HOME/.config/wezterm" \
    "$HOME/.config/tmux" \
    "$HOME/.local/bin" \
    "$HOME/.local/share/fonts/NerdFonts" \
    "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ok "User directories ready"

# ── Step 1: System dependencies ──────────────────────────────────────────────
step "Installing system dependencies (git, curl, openssh-client, flatpak, zsh)"
sudo apt-get update -qq
sudo apt-get install -y git curl openssh-client flatpak xdg-desktop-portal-gtk zsh
ok "System dependencies installed"

# ── Step 2: Set zsh as login shell ───────────────────────────────────────────
step "Setting zsh as login shell"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    sudo usermod -s /usr/bin/zsh "$USER"
    ok "Login shell changed to zsh (takes effect on next login)"
else
    ok "Login shell already set to zsh – skipping"
fi

# ── Step 3: Verify SSH key ────────────────────────────────────────────────────
# The key must exist and be registered on GitHub before this script is run.
step "Verifying SSH key for GitHub"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo -e "${RED}✗ SSH key not found at ~/.ssh/id_ed25519${NC}"
    echo ""
    echo "Generate and register an SSH key before running bootstrap:"
    echo "  ssh-keygen -t ed25519 -C \"${GITHUB_USER}@workstation\" -f ~/.ssh/id_ed25519 -N \"\""
    echo "  cat ~/.ssh/id_ed25519.pub"
    echo "Paste the key at https://github.com/settings/keys, then verify:"
    echo "  ssh-keyscan github.com >> ~/.ssh/known_hosts"
    echo "  ssh -T git@github.com"
    exit 1
fi

# Pre-seed known_hosts so ssh never prompts interactively (idempotent).
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

# ssh -T always exits 1 (GitHub denies shell access); capture stderr too.
SSH_OUTPUT=$(ssh -T git@github.com 2>&1 || true)
if ! echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
    echo -e "${RED}✗ SSH authentication to GitHub failed${NC}"
    echo ""
    echo "Ensure your public key is registered at https://github.com/settings/keys"
    echo "then verify with: ssh -T git@github.com"
    exit 1
fi
ok "SSH key verified – GitHub authentication successful"

# ── Step 4: Clone dotfiles ────────────────────────────────────────────────────
step "Cloning private dotfiles repository"
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    ok "Dotfiles cloned to $DOTFILES_DIR"
else
    git -C "$DOTFILES_DIR" fetch origin main
    git -C "$DOTFILES_DIR" reset --hard origin/main
    ok "Dotfiles already present – reset to origin/main"
fi
cd "$DOTFILES_DIR"

# ── Step 5: Install Nix (Determinate Systems) ────────────────────────────────
step "Installing Nix"
if ! command -v nix &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf -L \
        https://install.determinate.systems/nix \
        | sh -s -- install --no-confirm
    # Source Nix profile for the remainder of this script session.
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        # shellcheck disable=SC1091
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    ok "Nix installed"
else
    ok "Nix already installed – skipping"
fi

# ── Step 6: Apply Home Manager via Flake ─────────────────────────────────────
# Home Manager owns: git identity, delta config, git aliases, zsh, starship,
# direnv, fzf, and all CLI packages declared in home.nix.
# Do NOT write git config anywhere else in this script.
step "Applying Home Manager configuration"
# Fully qualified GitHub URI bypasses local registry lookup failures on fresh
# machines that have not yet populated the Nix registry.
nix run github:nix-community/home-manager -- \
    switch --flake "$DOTFILES_DIR#${GITHUB_USER}"
ok "Home Manager applied"

# Source the new profile so subsequent steps find HM-installed binaries.
# shellcheck disable=SC1090
. "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true

# ── Step 7: Install WezTerm via Flatpak ──────────────────────────────────────
step "Installing WezTerm"
if ! command -v wezterm &>/dev/null && ! flatpak list --user 2>/dev/null | grep -q wezterm; then
    flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub org.wezfurlong.wezterm
    ln -sf "$HOME/.local/share/flatpak/exports/bin/org.wezfurlong.wezterm" \
        "$HOME/.local/bin/wezterm"
    ok "WezTerm installed via Flatpak (user install)"
else
    ok "WezTerm already installed – skipping"
fi

# ── Step 8: Install JetBrainsMono Nerd Font ──────────────────────────────────
step "Installing JetBrainsMono Nerd Font"
FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
if [ -z "$(ls -A "$FONT_DIR" 2>/dev/null)" ]; then
    FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/${NERD_FONT_NAME}.zip"
    FONT_ZIP="/tmp/${NERD_FONT_NAME}.zip"
    curl -fsSL "$FONT_URL" -o "$FONT_ZIP"
    unzip -o "$FONT_ZIP" -d "$FONT_DIR"
    rm -f "$FONT_ZIP"
    fc-cache -fv >/dev/null 2>&1
    ok "JetBrainsMono Nerd Font installed"
else
    ok "Nerd Font already installed – skipping"
fi

# ── Step 9: Install Docker Engine ────────────────────────────────────────────
step "Installing Docker Engine"
if ! command -v docker &>/dev/null; then
    sudo apt-get install -y ca-certificates gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"
    ok "Docker Engine installed"
else
    ok "Docker already installed – skipping"
fi

# ── Step 10: Verify GitHub CLI ────────────────────────────────────────────────
# gh is declared in home.nix packages; apt is a fallback for first-run timing
# issues where HM hasn't sourced yet.
step "Verifying GitHub CLI"
if ! command -v gh &>/dev/null && [ ! -f "$HOME/.nix-profile/bin/gh" ]; then
    warn "gh not found – installing via apt as fallback"
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y gh
fi
ok "GitHub CLI available"

# ── Step 11: Configure gh pager ──────────────────────────────────────────────
# git pager (delta) is managed by Home Manager via programs.git.settings.
# The gh pager is a separate setting not exposed by Home Manager – set it here.
step "Configuring gh pager"
GH_BIN="${HOME}/.nix-profile/bin/gh"
DELTA_BIN="${HOME}/.nix-profile/bin/delta"
if [ -x "$GH_BIN" ] && [ -x "$DELTA_BIN" ]; then
    "$GH_BIN" config set pager "$DELTA_BIN" 2>/dev/null || true
    ok "gh pager set to delta"
else
    ok "gh or delta not in Nix profile yet – skipping gh pager config"
fi

# ── Step 12: Install Gemini CLI + extensions ──────────────────────────────────
step "Installing Gemini CLI and extensions"
if ! command -v gemini &>/dev/null; then
    NPM_BIN="${HOME}/.nix-profile/bin/npm"
    if [ -x "$NPM_BIN" ]; then
        # Install to ~/.local so npm doesn't write into the read-only /nix/store.
        NPM_PREFIX="$HOME/.local"
        "$NPM_BIN" install -g --prefix "$NPM_PREFIX" @google/gemini-cli
        export PATH="$NPM_PREFIX/bin:$PATH"
        if command -v gemini &>/dev/null; then
            gemini extension install conductor || true
            gemini mcp install context7 || true
        fi
        ok "Gemini CLI installed"
    else
        warn "npm not found – skipping Gemini CLI install"
        warn "Ensure pkgs.nodejs_22 is in home.nix packages and re-run bootstrap"
    fi
else
    ok "Gemini CLI already installed – skipping"
fi

# ── Step 13: Symlink user-managed dotfiles ───────────────────────────────────
# Must run BEFORE Step 13 (TPM) and Step 15 (LazyVim headless sync).
# TPM's headless install_plugins.sh reads TMUX_CONF to find the plugin list;
# that path must resolve to an actual file before the script runs.
# Directories were pre-created in the pre-flight block above.
step "Symlinking user-managed dotfiles"
ln -sf "$DOTFILES_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
ln -sf "$DOTFILES_DIR/tmux/tmux.conf"      "$HOME/.config/tmux/tmux.conf"
if [ -f "$DOTFILES_DIR/scripts/sessionizer" ]; then
    chmod +x "$DOTFILES_DIR/scripts/sessionizer"
    ln -sf "$DOTFILES_DIR/scripts/sessionizer" "$HOME/.local/bin/sessionizer"
fi
ok "Dotfiles symlinked"

# ── Step 14: Install tmux Plugin Manager and plugins ─────────────────────────
step "Installing tmux Plugin Manager (TPM) and plugins"
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    ok "TPM cloned"
else
    ok "TPM already installed – skipping clone"
fi
# TMUX_CONF must point to the symlinked config (XDG location, not ~/.tmux.conf)
# so TPM can find the plugin list during the headless install.
if [ -f "$HOME/.config/tmux/tmux.conf" ]; then
    TMUX_CONF="$HOME/.config/tmux/tmux.conf" \
    TMUX_PLUGIN_MANAGER_PATH="${HOME}/.tmux/plugins" \
        "$TPM_DIR/scripts/install_plugins.sh" >/dev/null 2>&1 || true
    ok "TPM plugins installed headlessly"
else
    warn "~/.config/tmux/tmux.conf not found – skipping TPM plugin install"
    warn "Re-run bootstrap or press prefix+I inside tmux to install plugins"
fi

# ── Step 15: Stage LazyVim starter into dotfiles ──────────────────────────────
step "Staging LazyVim starter"
NVIM_DIR="$DOTFILES_DIR/nvim"
if [ ! -s "$NVIM_DIR/init.lua" ]; then
    git clone --depth 1 https://github.com/LazyVim/starter /tmp/lazyvim-starter
    mkdir -p "$NVIM_DIR"
    cp -r /tmp/lazyvim-starter/. "$NVIM_DIR/"
    rm -rf "$NVIM_DIR/.git" /tmp/lazyvim-starter
    ok "LazyVim starter staged into dotfiles/nvim/"
else
    ok "LazyVim already staged – skipping"
fi

# ── Step 16: Run LazyVim headless plugin sync ─────────────────────────────────
step "Running LazyVim headless plugin sync"
NVIM_BIN="${HOME}/.nix-profile/bin/nvim"
if [ -x "$NVIM_BIN" ]; then
    "$NVIM_BIN" --headless "+Lazy! sync" +qa 2>/dev/null || true
    ok "LazyVim plugins synced headlessly"
else
    warn "Neovim not found in Nix profile – skipping headless sync"
    warn "Run ':Lazy sync' manually on first Neovim open"
fi

# ── Step 17: Install VS Code via apt repository ───────────────────────────────
# apt repository – NOT snap (snap blocks /nix/store access).
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

# ── Step 18: Install VS Code extensions ──────────────────────────────────────
step "Installing VS Code extensions"
EXTENSIONS_FILE="$DOTFILES_DIR/vscode/extensions.txt"
if [ -f "$EXTENSIONS_FILE" ] && command -v code &>/dev/null; then
    while IFS= read -r ext || [ -n "$ext" ]; do
        [[ -z "$ext" || "$ext" == \#* ]] && continue
        code --install-extension "$ext" --force >/dev/null 2>&1 || \
            warn "Failed to install extension: $ext"
    done < "$EXTENSIONS_FILE"
    ok "VS Code extensions installed"
else
    warn "vscode/extensions.txt not found or code not on PATH – skipping extensions"
fi

# ── Complete ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}✔ Bootstrap complete!${NC}"
echo ""
echo -e "${YELLOW}Manual steps required before first use:${NC}"
echo "  1. Log out and back in (activates Docker group membership and zsh)"
echo "  2. gh auth login   (requires browser OAuth)"
echo "  3. gemini auth login (requires browser OAuth)"
echo "  4. Verify SSH remote: cd ~/dotfiles && git remote -v"
echo "     (should show: git@github.com:${GITHUB_USER}/dotfiles.git)"
echo ""
echo "Back up your SSH private key to a secure location:"
echo "  ~/.ssh/id_ed25519  (cannot be regenerated from dotfiles)"
echo ""
echo "Then verify the installation with the checklist in §2.6"
