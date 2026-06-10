#!/usr/bin/env bash
# bootstrap.sh
# Idempotent workstation setup script.
# Lives in: workstation-scripts/scripts/ (PUBLIC repo) – fetched via curl
# Run with:
#   wget -qO bootstrap.sh https://raw.githubusercontent.com/yourusername/workstation-scripts/main/scripts/bootstrap.sh
#   bash bootstrap.sh --github-user yourusername --dotfiles-repo git@github.com:yourusername/dotfiles.git
#
# What this script does (headless-safe — no display required):
#   1.  Installs system dependencies and sets zsh as the login shell
#   2.  Verifies the SSH key is present and authenticated with GitHub
#   3.  Clones your PRIVATE dotfiles repo via SSH
#   4.  Installs Nix (Determinate Systems installer)
#   5.  Applies Home Manager from your flake (owns git identity, delta config,
#         git aliases, zsh, starship, direnv, fzf, JetBrainsMono
#         Nerd Font, and all CLI packages declared in home.nix)
#   6.  Installs Docker Engine
#   7.  Verifies GitHub CLI (installed by Home Manager; apt fallback)
#   8.  Configures gh pager (delta – not manageable via Home Manager)
#   9.  Symlinks user-managed dotfiles (sessionizer)
#   10. Stages LazyVim starter into dotfiles
#   11. Runs LazyVim headless plugin sync when Neovim is available
#
# GUI-only tools (WezTerm, VS Code, Chrome, ksnip) are installed by scripts/setup-desktop.sh.
# Run setup-desktop.sh after this script if you want a graphical environment.
#
# NOTE: git identity, delta pager, aliases, and JetBrainsMono
# Nerd Font are managed entirely by Home Manager via home.nix. The bootstrap
# script does NOT write any git config or install fonts manually. Tmux plugins
# are declared in tmux.conf and installed by TPM when tmux loads that config.
#
# PREREQUISITE: Generate and register your SSH key on GitHub before running
# this script. The bootstrap runs fully automatically with no pauses once the
# key is in place.

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

step() { echo -e "${GREEN}▶ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠ $1${NC}"; }
ok()    { echo -e "${GREEN}✓ $1${NC}"; }
die()   { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

# ── Variables ─────────────────────────────────────────────────────────────────
# Example values:
#   GITHUB_USER="yourusername"
#   DOTFILES_REPO="git@github.com:yourusername/dotfiles.git"
#
# Prefer environment variables or flags over editing this script:
#   GITHUB_USER=octocat DOTFILES_REPO=git@github.com:octocat/dotfiles.git bash bootstrap.sh
GITHUB_USER="${GITHUB_USER:-}"
DOTFILES_REPO="${DOTFILES_REPO:-}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
SSH_KEY_PATH="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"
FORCE_RESET=false
# Linux login name — must match the homeConfigurations key in flake.nix.
# Usually your Linux username (whoami), which may differ from GITHUB_USER.
LINUX_USER="$(whoami)"

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [options]

Options:
  --github-user USER       GitHub username used for URLs and SSH hints
  --dotfiles-repo URL      Private dotfiles SSH URL (git@github.com:USER/dotfiles.git)
  --dotfiles-dir PATH      Local dotfiles checkout path (default: ~/dotfiles)
  --ssh-key-path PATH      SSH private key path (default: ~/.ssh/id_ed25519)
  --force-reset            Discard local dotfiles changes and reset to origin/main
  -h, --help               Show this help

Environment variables with the same names are also supported:
  GITHUB_USER, DOTFILES_REPO, DOTFILES_DIR, SSH_KEY_PATH
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --github-user)
            [ "$#" -ge 2 ] || die "--github-user requires a value"
            GITHUB_USER="$2"
            shift 2
            ;;
        --dotfiles-repo)
            [ "$#" -ge 2 ] || die "--dotfiles-repo requires a value"
            DOTFILES_REPO="$2"
            shift 2
            ;;
        --dotfiles-dir)
            [ "$#" -ge 2 ] || die "--dotfiles-dir requires a value"
            DOTFILES_DIR="$2"
            shift 2
            ;;
        --ssh-key-path)
            [ "$#" -ge 2 ] || die "--ssh-key-path requires a value"
            SSH_KEY_PATH="$2"
            shift 2
            ;;
        --force-reset)
            FORCE_RESET=true
            shift
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

if [ -n "$GITHUB_USER" ] && [ -z "$DOTFILES_REPO" ]; then
    DOTFILES_REPO="git@github.com:${GITHUB_USER}/dotfiles.git"
fi

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

validate_config() {
    [ -n "$GITHUB_USER" ] || die "Set GITHUB_USER via environment or --github-user"
    [ "$GITHUB_USER" != "yourusername" ] || die "Replace the example GITHUB_USER value"
    [ -n "$DOTFILES_REPO" ] || die "Set DOTFILES_REPO via environment or --dotfiles-repo"
    case "$DOTFILES_REPO" in
        *yourusername*) die "Replace the example DOTFILES_REPO value" ;;
        git@github.com:*) ;;
        *) die "DOTFILES_REPO must be an SSH URL like git@github.com:${GITHUB_USER}/dotfiles.git" ;;
    esac
    [ -n "$DOTFILES_DIR" ] || die "DOTFILES_DIR cannot be empty"
    case "$DOTFILES_DIR" in
        /*) ;;
        *) die "DOTFILES_DIR must be an absolute path" ;;
    esac
    [ "$DOTFILES_DIR" != "/" ] || die "DOTFILES_DIR cannot be /"
    [ -n "$SSH_KEY_PATH" ] || die "SSH_KEY_PATH cannot be empty"
    case "$SSH_KEY_PATH" in
        /*) ;;
        *) die "SSH_KEY_PATH must be an absolute path" ;;
    esac
}

validate_host() {
    require_command apt-get
    require_command systemctl
    require_command getent

    [ -r /etc/os-release ] || die "/etc/os-release not found; this script supports Ubuntu 22.04 and 24.04"
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "${ID:-}" = "ubuntu" ] || die "Unsupported OS: ${PRETTY_NAME:-unknown}. Use Ubuntu 22.04 or 24.04."
    case "${VERSION_ID:-}" in
        22.04|24.04) ;;
        *) die "Unsupported Ubuntu version: ${VERSION_ID:-unknown}. Use Ubuntu 22.04 or 24.04." ;;
    esac

    case "$(uname -m)" in
        x86_64) ;;
        *) die "Unsupported architecture: $(uname -m). This reference flake targets x86_64-linux." ;;
    esac

    [ -d /run/systemd/system ] || die "systemd does not appear to be running"
    getent hosts github.com >/dev/null || die "Cannot resolve github.com; check internet/DNS before bootstrapping"
}

print_config() {
    echo "Resolved configuration:"
    echo "  Linux user:     $LINUX_USER"
    echo "  GitHub user:    $GITHUB_USER"
    echo "  Dotfiles repo:  $DOTFILES_REPO"
    echo "  Dotfiles dir:   $DOTFILES_DIR"
    echo "  SSH key path:   $SSH_KEY_PATH"
    echo "  Force reset:    $FORCE_RESET"
    echo ""
}

echo -e "${GREEN}🚀 Starting workstation bootstrap...${NC}"

step "Running preflight checks"
validate_config
validate_host
print_config

# Cache sudo credentials up front so subsequent sudo calls don't need a TTY.
sudo -v
ok "Preflight checks passed"

# ── Pre-flight: create user-owned XDG directories ────────────────────────────
# Must run before any sudo call. Some sudo-invoked tools (apt, gpg) implicitly
# create ~/.config/ owned by root, which causes "Permission denied" errors in
# any later user-space write to that tree.
step "Pre-creating user-owned directories"
mkdir -p \
    "$HOME/.config/git" \
    "$HOME/.config/tmux" \
    "$HOME/.local/bin" \
    "$HOME/.ssh" \
    "$(dirname "$SSH_KEY_PATH")"
chmod 700 "$HOME/.ssh" "$(dirname "$SSH_KEY_PATH")"
ok "User directories ready"

# ── Step 1: System dependencies ──────────────────────────────────────────────
step "Installing system dependencies"
sudo apt-get update -qq
sudo apt-get install -y git curl wget openssh-client zsh build-essential xz-utils
ok "System dependencies installed"

# Set zsh as login shell ─────────────────────────────────────────────────────
step "Setting zsh as login shell"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [ "$current_shell" != "/usr/bin/zsh" ]; then
    sudo usermod -s /usr/bin/zsh "$USER"
    ok "Login shell changed to zsh (takes effect on next login)"
else
    ok "Login shell already set to zsh – skipping"
fi

# ── Step 2: Verify SSH key ────────────────────────────────────────────────────
# The key must exist and be registered on GitHub before this script is run.
step "Verifying SSH key for GitHub"
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo -e "${RED}✗ SSH key not found at $SSH_KEY_PATH${NC}"
    echo ""
    echo "Generate and register an SSH key before running bootstrap:"
    echo "  ssh-keygen -t ed25519 -C \"${GITHUB_USER}@workstation\" -f \"$SSH_KEY_PATH\" -N \"\""
    echo "  cat \"${SSH_KEY_PATH}.pub\""
    echo "Paste the key at https://github.com/settings/keys, then verify:"
    echo "  ssh-keyscan github.com >> ~/.ssh/known_hosts"
    echo "  ssh -i \"$SSH_KEY_PATH\" -o IdentitiesOnly=yes -T git@github.com"
    exit 1
fi

# Pre-seed known_hosts so ssh never prompts interactively (idempotent).
ssh-keyscan github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

# ssh -T always exits 1 (GitHub denies shell access); capture stderr too.
SSH_OUTPUT=$(ssh -i "$SSH_KEY_PATH" -o IdentitiesOnly=yes -T git@github.com 2>&1 || true)
if ! echo "$SSH_OUTPUT" | grep -q "successfully authenticated"; then
    echo -e "${RED}✗ SSH authentication to GitHub failed${NC}"
    echo ""
    echo "Ensure your public key is registered at https://github.com/settings/keys"
    echo "then verify with: ssh -i \"$SSH_KEY_PATH\" -o IdentitiesOnly=yes -T git@github.com"
    exit 1
fi
ok "SSH key verified – GitHub authentication successful"

export GIT_SSH_COMMAND="ssh -i $SSH_KEY_PATH -o IdentitiesOnly=yes"

# ── Step 3: Clone dotfiles ────────────────────────────────────────────────────
step "Cloning private dotfiles repository"
if [ ! -d "$DOTFILES_DIR" ]; then
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    ok "Dotfiles cloned to $DOTFILES_DIR"
else
    [ -d "$DOTFILES_DIR/.git" ] || die "$DOTFILES_DIR exists but is not a git repository"
    dotfiles_status="$(git -C "$DOTFILES_DIR" status --porcelain)"
    if [ -n "$dotfiles_status" ] && [ "$FORCE_RESET" != true ]; then
        echo -e "${RED}✗ Dotfiles repository has local changes${NC}"
        echo ""
        echo "Refusing to overwrite local edits in: $DOTFILES_DIR"
        echo "Review them first:"
        echo "  git -C \"$DOTFILES_DIR\" status --short"
        echo "  git -C \"$DOTFILES_DIR\" diff"
        echo ""
        echo "Then either commit/stash them and re-run, or intentionally discard them with:"
        echo "  bash bootstrap.sh --github-user \"$GITHUB_USER\" --dotfiles-repo \"$DOTFILES_REPO\" --force-reset"
        exit 1
    fi
    git -C "$DOTFILES_DIR" fetch origin main
    if [ "$FORCE_RESET" = true ]; then
        git -C "$DOTFILES_DIR" checkout -B main origin/main
        git -C "$DOTFILES_DIR" clean -fd
        ok "Dotfiles reset to origin/main (--force-reset)"
    else
        current_branch="$(git -C "$DOTFILES_DIR" rev-parse --abbrev-ref HEAD)"
        [ "$current_branch" = "main" ] || die "Dotfiles checkout is on '$current_branch', not 'main'. Switch branches or re-run with --force-reset."
        if git -C "$DOTFILES_DIR" merge --ff-only origin/main; then
            ok "Dotfiles fast-forwarded to origin/main"
        else
            die "Dotfiles cannot fast-forward to origin/main. Resolve divergence manually or re-run with --force-reset."
        fi
    fi
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
    switch --flake "$DOTFILES_DIR#${LINUX_USER}"
ok "Home Manager applied"

# Verify that Home Manager actually succeeded by checking for a key binary.
if ! command -v zsh &>/dev/null && [ ! -x "$HOME/.nix-profile/bin/zsh" ]; then
    warn "zsh not found after Home Manager apply – HM may have failed"
    warn "Re-run manually: nix run github:nix-community/home-manager -- switch --flake $DOTFILES_DIR#${LINUX_USER}"
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
        | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu \
${VERSION_CODENAME} stable" \
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
step "Configuring gh (pager + git protocol)"
GH_BIN="$(command -v gh || true)"
DELTA_BIN="$(command -v delta || true)"
if [ -n "$GH_BIN" ]; then
    # Always use SSH so 'gh repo clone' produces SSH remotes (not HTTPS).
    # HTTPS remotes prompt for token credentials on every push.
    "$GH_BIN" config set git_protocol ssh 2>/dev/null || true
    ok "gh git_protocol set to ssh"
    if [ -n "$DELTA_BIN" ]; then
        "$GH_BIN" config set pager "$DELTA_BIN" 2>/dev/null || true
        ok "gh pager set to delta"
    fi
else
    ok "gh not in Nix profile yet – skipping gh config"
fi

# ── Step 9: Symlink user-managed dotfiles ────────────────────────────────────
# sessionizer is a custom script not managed by Home Manager.
# tmux.conf is symlinked by Home Manager (home.file.mkOutOfStoreSymlink) — no manual symlink needed.
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

# ── Step 10: Stage LazyVim starter into dotfiles ─────────────────────────────
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

# ── Step 11: Run LazyVim headless plugin sync ────────────────────────────────
step "Running LazyVim headless plugin sync"
NVIM_BIN="$(command -v nvim || true)"
LAZY_LOG="$(mktemp /tmp/lazyvim-headless-sync.XXXXXX.log)"
if [ -n "$NVIM_BIN" ]; then
    if timeout 300 "$NVIM_BIN" --headless "+Lazy! sync" +qa >"$LAZY_LOG" 2>&1; then
        ok "LazyVim plugins synced headlessly"
        rm -f "$LAZY_LOG"
    else
        warn "LazyVim headless sync exited non-zero or timed out after 300s"
        warn "Open Neovim and run :Lazy sync manually, or inspect: $LAZY_LOG"
    fi
else
    warn "Neovim not found in PATH – skipping headless sync"
fi

# ── Complete ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}✔ Headless bootstrap complete.${NC}"
echo ""
echo -e "${YELLOW}Manual steps required before first use:${NC}"
echo "  1. Log out and back in (activates Docker group membership and zsh)"
echo "  2. gh auth login  (device flow — prints a code; open the URL on any browser)"
echo "  3. Verify SSH remote: cd ~/dotfiles && git remote -v"
echo "     (should show: git@github.com:${GITHUB_USER}/dotfiles.git)"
echo "  4. Commit generated lock/state files if present:"
echo "     cd ~/dotfiles && git status --short"
echo "     git add flake.lock nvim/lazy-lock.json && git commit -m \"chore: record initial generated locks\""
echo ""
echo "Verification commands:"
echo "  nix --version"
echo "  home-manager --version"
echo "  echo \$SHELL"
echo "  docker ps"
echo "  gh auth status"
echo "  direnv --version && devenv --version && nvim --version"
echo ""
echo "Optional desktop next step (XFCE4 + XRDP + WezTerm + VS Code):"
echo "  wget -O setup-desktop.sh https://raw.githubusercontent.com/${GITHUB_USER}/workstation-scripts/main/scripts/setup-desktop.sh"
echo "  chmod +x setup-desktop.sh && ./setup-desktop.sh --dotfiles-dir \"$DOTFILES_DIR\""
echo ""
echo "Back up keys that dotfiles cannot recover:"
echo "  $SSH_KEY_PATH"
echo "  ~/.config/sops/age/keys.txt  (if you later adopt SOPS + Age)"
echo ""
echo "Then verify the installation with the checklist in §2.6"
