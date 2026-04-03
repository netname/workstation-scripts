#!/usr/bin/env bash
# bootstrap.sh
# Idempotent workstation setup script.
# Lives in: workstation-scripts/ (PUBLIC repo) – fetched via curl
# Run with: bash <(wget -qO- https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh)
#
# What this script does:
#   1. Installs system dependencies and sets zsh as the login shell
#   2. Verifies the SSH key is present and authenticated with GitHub
#   3. Clones your PRIVATE dotfiles repo via SSH
#   4. Installs Nix + Home Manager and builds your environment
#   5. Installs WezTerm, Docker, fonts, tmux plugins, Neovim, VS Code
#
# PREREQUISITE: Generate and register your SSH key on GitHub before running
# this script (Quick Start Step 3). The bootstrap runs fully automatically
# with no pauses once the key is in place.

set -euo pipefail

# — Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "${GREEN}▶ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }

# — Variables – substitute these two values before pushing
GITHUB_USER="netname"                                   # ← your GitHub username
DOTFILES_REPO="git@github.com:netname/dotfiles.git"    # ← your PRIVATE dotfiles SSH URL

DOTFILES_DIR="$HOME/dotfiles"
NERD_FONT_VERSION="v3.2.1"
NERD_FONT_NAME="JetBrainsMono"

echo -e "${GREEN}🚀 Starting workstation bootstrap...${NC}"

# — Pre-flight: Ensure all user-owned XDG directories exist before any sudo call.
# Some sudo-invoked tools (apt, gpg) can trigger git or XDG path resolution that
# implicitly creates ~/.config/ owned by root, causing "Permission denied" errors
# in later git config --global calls. Creating them here (as the current user)
# guarantees correct ownership for the entire script run.
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

# — Step 1: System dependencies
step "Installing system dependencies (git, curl, openssh-client, flatpak, zsh)"
sudo apt-get update -qq
sudo apt-get install -y git curl openssh-client flatpak xdg-desktop-portal-gtk zsh
ok "System dependencies installed"

# — Step 1b: Set zsh as login shell
step "Setting zsh as login shell"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    chsh -s /usr/bin/zsh
    ok "Login shell changed to zsh (takes effect on next login)"
else
    ok "Login shell already set to zsh – skipping"
fi

# — Step 2: Verify SSH key (prerequisite – see §Quick Start Step 3)
# The SSH key must be generated and registered on GitHub before running
# this script. See the Quick Start guide for instructions.
step "Verifying SSH key for GitHub"
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    echo -e "${RED}✗ SSH key not found at ~/.ssh/id_ed25519${NC}"
    echo ""
    echo "Generate and register an SSH key before running bootstrap:"
    echo "  ssh-keygen -t ed25519 -C \"${GITHUB_USER}@workstation\" -f ~/.ssh/id_ed25519 -N \"\""
    echo "  cat ~/.ssh/id_ed25519.pub"
    echo "Then paste the key at https://github.com/settings/keys and verify:"
    echo "  ssh -T git@github.com"
    exit 1
fi

# Note: ssh -T git@github.com always exits with code 1 (GitHub denies shell access),
# so we capture output separately to avoid pipefail treating it as a failure.
SSH_OUTPUT=$(ssh -T git@github.com 2>&1 || true)
if ! echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
    echo -e "${RED}✗ SSH authentication to GitHub failed${NC}"
    echo ""
    echo "Ensure your public key is registered at https://github.com/settings/keys"
    echo "then verify with: ssh -T git@github.com"
    exit 1
fi
ok "SSH key verified – GitHub authentication successful"

# — Step 3: Clone dotfiles
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

# — Step 3: Install Nix (Determinate Systems)
step "Installing Nix"
if ! command -v nix &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf -L \
        https://install.determinate.systems/nix \
        | sh -s -- install --no-confirm
    # Source Nix profile for the remainder of this script session
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        # shellcheck disable=SC1091
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    ok "Nix installed"
else
    ok "Nix already installed – skipping"
fi

# — Step 4: Apply Home Manager via Flake
step "Applying Home Manager configuration"
# Use the fully qualified GitHub URI to bypass local registry lookup failures
# on fresh machines that have not yet populated the Nix registry.
nix run github:nix-community/home-manager -- \
    switch --flake "$DOTFILES_DIR#${GITHUB_USER}"
ok "Home Manager applied"

# Source the new profile so subsequent steps find Home Manager-installed binaries
# shellcheck disable=SC1090
. "$HOME/.nix-profile/etc/profile.d/nix.sh" 2>/dev/null || true

# — Step 5: Install WezTerm via Flatpak
step "Installing WezTerm"
if ! command -v wezterm &>/dev/null && ! flatpak list --user 2>/dev/null | grep -q wezterm; then
    flatpak remote-add --user --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    flatpak install --user -y flathub org.wezfurlong.wezterm
    # Expose the Flatpak binary on PATH via a wrapper
    ln -sf "$HOME/.local/share/flatpak/exports/bin/org.wezfurlong.wezterm" \
        "$HOME/.local/bin/wezterm"
    ok "WezTerm installed via Flatpak (user install)"
else
    ok "WezTerm already installed – skipping"
fi

# — Step 6: Install JetBrainsMono Nerd Font
step "Installing JetBrainsMono Nerd Font"
FONT_DIR="$HOME/.local/share/fonts/NerdFonts"
if [ ! -d "$FONT_DIR" ] || [ -z "$(ls -A "$FONT_DIR" 2>/dev/null)" ]; then
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

# — Step 7: Install Docker Engine
step "Installing Docker Engine"
if ! command -v docker &>/dev/null; then
    # Add Docker's official apt repository
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

# — Step 8: Configure git identity, delta, and aliases
step "Configuring git"
if [ -z "$(git config --global user.name 2>/dev/null)" ]; then
    read -rp "  Git user.name: " GIT_NAME
    git config --global user.name "$GIT_NAME"
fi
if [ -z "$(git config --global user.email 2>/dev/null)" ]; then
    read -rp "  Git user.email: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
fi

# Delta as pager for git AND gh (two separate settings – both required)
if command -v delta &>/dev/null; then
    DELTA_BIN="$(command -v delta)"
    git config --global core.pager "$DELTA_BIN"
    git config --global delta.side-by-side true
    git config --global delta.line-numbers true
    git config --global delta.navigate true
    if command -v gh &>/dev/null || [ -f "$HOME/.nix-profile/bin/gh" ]; then
        "$HOME/.nix-profile/bin/gh" config set pager "$DELTA_BIN" 2>/dev/null || true
    fi
fi

# Standard git aliases used throughout Dev Workflows
git config --global alias.sw   "switch"
git config --global alias.co   "checkout -b"
git config --global alias.st   "status --short"
git config --global alias.pushf "push --force-with-lease"
git config --global alias.lg   "log --oneline --graph --decorate --all"
ok "Git configured"

# — Step 9: Verify GitHub CLI (installed by Home Manager; apt is fallback)
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

# — Step 10: Install Gemini CLI, Conductor, Context7 MCP
step "Installing Gemini CLI and extensions"
if ! command -v gemini &>/dev/null; then
    NPM_BIN="${HOME}/.nix-profile/bin/npm"
    if [ -x "$NPM_BIN" ]; then
        # Install to ~/.local so npm doesn't try to write into the read-only /nix/store
        NPM_PREFIX="$HOME/.local"
        mkdir -p "$NPM_PREFIX"
        "$NPM_BIN" install -g --prefix "$NPM_PREFIX" @google/gemini-cli
        export PATH="$NPM_PREFIX/bin:$PATH"
        if command -v gemini &>/dev/null; then
            gemini extension install conductor || true
            gemini mcp install context7 || true
        fi
        ok "Gemini CLI installed"
    else
        warn "npm not found – skipping Gemini CLI install"
        warn "Add pkgs.nodejs_22 (global npm provider) to home.nix packages and re-run bootstrap"
        warn "Note: pkgs.nodejs_24 in devenv.nix is project-scoped and does not provide a global npm"
    fi
else
    ok "Gemini CLI already installed – skipping"
fi

# — Step 11: Install tmux Plugin Manager and plugins headlessly
step "Installing tmux Plugin Manager (TPM) and plugins"
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    ok "TPM cloned"
else
    ok "TPM already installed – skipping clone"
fi
# Run headless plugin install – no interactive tmux session required
if [ -f "$DOTFILES_DIR/tmux/tmux.conf" ]; then
    TMUX_PLUGIN_MANAGER_PATH="${HOME}/.tmux/plugins" \
        "$TPM_DIR/scripts/install_plugins.sh" >/dev/null 2>&1 || true
    ok "TPM plugins installed headlessly"
else
    warn "tmux/tmux.conf not found in dotfiles – skipping TPM plugin install"
    warn "Populate tmux/tmux.conf and re-run bootstrap, or press prefix+I in tmux"
fi

# — Step 12: Stage LazyVim starter into dotfiles
step "Staging LazyVim starter"
NVIM_DIR="$DOTFILES_DIR/nvim"
if [ ! -f "$NVIM_DIR/init.lua" ] || [ ! -s "$NVIM_DIR/init.lua" ]; then
    git clone --depth 1 https://github.com/LazyVim/starter /tmp/lazyvim-starter
    mkdir -p "$NVIM_DIR"
    cp -r /tmp/lazyvim-starter/. "$NVIM_DIR/"
    rm -rf "$NVIM_DIR/.git" /tmp/lazyvim-starter
    ok "LazyVim starter staged into dotfiles/nvim/"
else
    ok "LazyVim already staged – skipping"
fi

# — Step 13: Run LazyVim headless plugin sync
step "Running LazyVim headless plugin sync"
NVIM_BIN="${HOME}/.nix-profile/bin/nvim"
if [ -x "$NVIM_BIN" ]; then
    "$NVIM_BIN" --headless "+Lazy! sync" +qa 2>/dev/null || true
    ok "LazyVim plugins synced headlessly"
else
    warn "Neovim not found in Nix profile – skipping headless sync"
    warn "Run ':Lazy sync' manually on first Neovim open"
fi

# — Step 14: Install VS Code via apt repository
step "Installing VS Code"
if ! command -v code &>/dev/null; then
    # apt repository – NOT snap (snap blocks /nix/store access)
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

# — Step 15: Install VS Code extensions
step "Installing VS Code extensions"
EXTENSIONS_FILE="$DOTFILES_DIR/vscode/extensions.txt"
if [ -f "$EXTENSIONS_FILE" ] && command -v code &>/dev/null; then
    while IFS= read -r ext || [ -n "$ext" ]; do
        [[ -z "$ext" ]] || [[ "$ext" == \#* ]] && continue
        code --install-extension "$ext" --force >/dev/null 2>&1 || \
            warn "Failed to install extension: $ext"
    done < "$EXTENSIONS_FILE"
    ok "VS Code extensions installed"
else
    warn "vscode/extensions.txt not found or code not on PATH – skipping extensions"
fi

# — Step 16: Symlink user-managed dotfiles
step "Symlinking user-managed dotfiles"
# Directories were pre-created in the pre-flight block above.

# WezTerm config
ln -sf "$DOTFILES_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"

# tmux config
ln -sf "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"

# Sessionizer script
if [ -f "$DOTFILES_DIR/scripts/sessionizer" ]; then
    chmod +x "$DOTFILES_DIR/scripts/sessionizer"
    ln -sf "$DOTFILES_DIR/scripts/sessionizer" "$HOME/.local/bin/sessionizer"
fi

ok "Dotfiles symlinked"

# — Complete
echo ""
echo -e "${GREEN}✔ Bootstrap complete!${NC}"
echo ""
echo -e "${YELLOW}Manual steps required before first use:${NC}"
echo "  1. Log out and back in (activates Docker group membership)"
echo "  2. gh auth login (requires browser OAuth)"
echo "  3. gemini auth login (requires browser OAuth)"
echo "  4. Verify SSH remote: cd ~/dotfiles && git remote -v"
echo "     (should show: git@github.com:${GITHUB_USER}/dotfiles.git)"
echo ""
echo -e "${GREEN}The SSH key generated during the bootstrap is at:${NC}"
echo "  ~/.ssh/id_ed25519.pub"
echo ""
echo "Back up your SSH private key (~/.ssh/id_ed25519) to a secure location."
echo "It cannot be regenerated from the dotfiles repository."
echo ""
echo "Then verify the installation with the checklist in §2.6"
