#!/usr/bin/env bash
# bootstrap.sh
# Idempotent workstation setup script.
# Lives in: workstation-scripts/ (PUBLIC repo) – fetched via curl
# Run with: wget -qO bootstrap.sh https://raw.githubusercontent.com/yourusername/workstation-scripts/main/bootstrap.sh && bash bootstrap.sh
#
# What this script does (headless-safe — no display required):
#   1.  Installs system dependencies and sets zsh as the login shell
#   2.  Verifies the SSH key is present and authenticated with GitHub
#   3.  Clones your PRIVATE dotfiles repo via SSH
#   4.  Installs Nix (Determinate Systems installer)
#   5.  Applies Home Manager from your flake (owns git config, tmux plugins,
#         Nerd Font, and all CLI packages declared in home.nix)
#   6.  Installs Docker Engine
#   7.  Verifies GitHub CLI (installed by Home Manager; apt fallback)
#   8.  Configures gh pager (delta – not manageable via Home Manager)
#   9.  Installs Gemini CLI + Conductor + Context7 MCP
#   10. Symlinks user-managed dotfiles (sessionizer)
#   11. Stages LazyVim starter into dotfiles
#   12. Runs LazyVim headless plugin sync
#
# GUI-only tools (WezTerm, VS Code, Chrome, ksnip) are installed by setup-desktop.sh.
# Run setup-desktop.sh after this script if you want a graphical environment.
#
# NOTE: git identity, delta pager, aliases, tmux plugins, and JetBrainsMono
# Nerd Font are managed entirely by Home Manager via home.nix. The bootstrap
# script does NOT write any git config or install fonts/tmux plugins manually.
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
# !! EDIT THESE two lines to your GitHub username before running !!
GITHUB_USER="yourusername"
DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

echo -e "${GREEN}🚀 Starting workstation bootstrap...${NC}"

# ── Pre-flight: create user-owned XDG directories ────────────────────────────
# Must run before any sudo call. Some sudo-invoked tools (apt, gpg) implicitly
# create ~/.config/ owned by root, which causes "Permission denied" errors in
# any later user-space write to that tree.
step "Pre-creating user-owned directories"
mkdir -p \
    "$HOME/.config/git" \
    "$HOME/.config/tmux" \
    "$HOME/.local/bin" \
    "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ok "User directories ready"

# ── Step 1: System dependencies ──────────────────────────────────────────────
step "Installing system dependencies (git, curl, openssh-client, zsh)"
sudo apt-get update -qq
sudo apt-get install -y git curl openssh-client zsh
ok "System dependencies installed"

# Set zsh as login shell ─────────────────────────────────────────────────────
step "Setting zsh as login shell"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "/usr/bin/zsh" ]; then
    sudo usermod -s /usr/bin/zsh "$USER"
    ok "Login shell changed to zsh (takes effect on next login)"
else
    ok "Login shell already set to zsh – skipping"
fi

# ── Step 2: Verify SSH key ────────────────────────────────────────────────────
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

# ── Step 3: Clone dotfiles ────────────────────────────────────────────────────
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

# ── Step 4: Install Nix (Determinate Systems) ────────────────────────────────
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

# ── Step 5: Apply Home Manager via Flake ──────────────────────────────────────
# Home Manager owns: git identity, delta config, git aliases, zsh, starship,
# direnv, fzf, and all CLI packages declared in home.nix.
# Do NOT write git config anywhere else in this script.
step "Applying Home Manager configuration"
# Fully qualified GitHub URI bypasses local registry lookup failures on fresh
# machines that have not yet populated the Nix registry.
nix run github:nix-community/home-manager -- \
    switch --flake "$DOTFILES_DIR#${GITHUB_USER}"
ok "Home Manager applied"

# Verify that Home Manager actually succeeded by checking for a key binary.
if ! command -v zsh &>/dev/null && [ ! -x "$HOME/.nix-profile/bin/zsh" ]; then
    warn "zsh not found after Home Manager apply – HM may have failed"
    warn "Re-run manually: nix run github:nix-community/home-manager -- switch --flake $DOTFILES_DIR#${GITHUB_USER}"
fi

# Source the new profile so subsequent steps find HM-installed binaries.
# shellcheck disable=SC1090
if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
else
    warn "Nix profile script not found – HM-installed binaries may not be on PATH"
    warn "Expected: $HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# ── Step 6: Install Docker Engine ────────────────────────────────────────────
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

# ── Step 7: Verify GitHub CLI ─────────────────────────────────────────────────
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

# ── Step 8: Configure gh pager ───────────────────────────────────────────────
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

# ── Step 9: Install Gemini CLI + extensions ──────────────────────────────────
step "Installing Gemini CLI and extensions"
if ! command -v gemini &>/dev/null; then
    NPM_BIN="${HOME}/.nix-profile/bin/npm"
    if [ -x "$NPM_BIN" ]; then
        # Install to ~/.local so npm doesn't write into the read-only /nix/store.
        NPM_PREFIX="$HOME/.local"
        "$NPM_BIN" install -g --prefix "$NPM_PREFIX" @google/gemini-cli
        export PATH="$NPM_PREFIX/bin:$PATH"
        if command -v gemini &>/dev/null; then
            if gemini extension install conductor; then
                ok "Gemini Conductor extension installed"
            else
                warn "Gemini Conductor extension install failed – install manually later"
            fi
            if gemini mcp install context7; then
                ok "Gemini Context7 MCP installed"
            else
                warn "Gemini Context7 MCP install failed – install manually later"
            fi
        fi
        ok "Gemini CLI installed"
    else
        warn "npm not found – skipping Gemini CLI install"
        warn "Ensure pkgs.nodejs_22 is in home.nix packages and re-run bootstrap"
    fi
else
    ok "Gemini CLI already installed – skipping"
fi

# ── Step 10: Symlink user-managed dotfiles ───────────────────────────────────
# sessionizer is a custom script not managed by Home Manager.
# tmux.conf is generated by Home Manager (programs.tmux.extraConfig) — no symlink needed.
# wezterm.lua is symlinked by setup-desktop.sh (WezTerm is desktop-only).
step "Symlinking user-managed dotfiles"
if [ -f "$DOTFILES_DIR/scripts/sessionizer" ]; then
    chmod +x "$DOTFILES_DIR/scripts/sessionizer"
    ln -sf "$DOTFILES_DIR/scripts/sessionizer" "$HOME/.local/bin/sessionizer"
    ok "sessionizer symlinked to ~/.local/bin/sessionizer"
else
    warn "scripts/sessionizer not found in dotfiles – symlink skipped"
    warn "Add scripts/sessionizer to your dotfiles repo and re-run bootstrap, or symlink manually"
fi
ok "Dotfile symlinks complete (tmux managed by HM, wezterm by setup-desktop.sh)"

# ── Step 11: Stage LazyVim starter into dotfiles ─────────────────────────────
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

# ── Step 12: Run LazyVim headless plugin sync ────────────────────────────────
step "Running LazyVim headless plugin sync"
NVIM_BIN="${HOME}/.nix-profile/bin/nvim"
if [ -x "$NVIM_BIN" ]; then
    LAZY_LOG="$(mktemp /tmp/lazyvim-sync.XXXXXX.log)"
    if timeout 300 "$NVIM_BIN" --headless "+Lazy! sync" +qa >"$LAZY_LOG" 2>&1; then
        ok "LazyVim plugins synced headlessly"
    else
        warn "LazyVim headless sync exited non-zero or timed out after 300s"
        warn "Log saved to: $LAZY_LOG"
        warn "Run ':Lazy sync' manually on first Neovim open"
    fi
else
    warn "Neovim not found in Nix profile – skipping headless sync"
    warn "Run ':Lazy sync' manually on first Neovim open"
fi

# ── Complete ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}✔ Bootstrap complete!${NC}"
echo ""
echo -e "${YELLOW}Manual steps required before first use:${NC}"
echo "  1. Log out and back in (activates Docker group membership and zsh)"
echo "  2. gh auth login     (device flow — prints a code; open the URL on any browser)"
echo "  3. gemini auth login (device flow — prints a code; open the URL on any browser)"
echo "  4. Verify SSH remote: cd ~/dotfiles && git remote -v"
echo "     (should show: git@github.com:${GITHUB_USER}/dotfiles.git)"
echo ""
echo "To add a graphical desktop (XFCE4 + XRDP + WezTerm + VS Code):"
echo "  wget -O setup-desktop.sh https://raw.githubusercontent.com/${GITHUB_USER}/workstation-scripts/main/setup-desktop.sh"
echo "  chmod +x setup-desktop.sh && ./setup-desktop.sh"
echo ""
echo "Back up your SSH private key to a secure location:"
echo "  ~/.ssh/id_ed25519  (cannot be regenerated from dotfiles)"
echo ""
echo "Then verify the installation with the checklist in §2.6"
