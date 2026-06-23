#!/usr/bin/env bash
# init-dotfiles.sh
# Create a private dotfiles repository from workstation-scripts templates.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }
die() { echo -e "${RED}✗ $1${NC}" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE_DIR="$REPO_ROOT/templates"

TARGET_DIR="${TARGET_DIR:-$HOME/dotfiles}"
LINUX_USER="${LINUX_USER:-$(whoami)}"
GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"

usage() {
    cat <<'EOF'
Usage: init-dotfiles.sh [options]

Create a local private dotfiles project from workstation-scripts/templates.
This script does not create GitHub repositories, does not call gh, and does
not push anything. Create the private remote repository manually after review.

Options:
  --target-dir PATH     Destination path (default: ~/dotfiles)
  --linux-user USER     Linux login username (default: whoami)
  --git-name NAME       Git commit author name to write into modules/git.nix
  --git-email EMAIL     Git commit author email to write into modules/git.nix
  -h, --help            Show this help

Environment variables with the same names are also supported:
  TARGET_DIR, LINUX_USER, GIT_NAME, GIT_EMAIL
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --target-dir)
            [ "$#" -ge 2 ] || die "--target-dir requires a value"
            TARGET_DIR="$2"
            shift 2
            ;;
        --linux-user)
            [ "$#" -ge 2 ] || die "--linux-user requires a value"
            LINUX_USER="$2"
            shift 2
            ;;
        --git-name)
            [ "$#" -ge 2 ] || die "--git-name requires a value"
            GIT_NAME="$2"
            shift 2
            ;;
        --git-email)
            [ "$#" -ge 2 ] || die "--git-email requires a value"
            GIT_EMAIL="$2"
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

replace_in_file() {
    local file="$1"
    local search="$2"
    local replacement="$3"
    local escaped_replacement
    local tmp
    escaped_replacement="$(printf '%s' "$replacement" | sed 's/[&|\\]/\\&/g')"
    tmp="$(mktemp)"
    sed "s|$search|$escaped_replacement|g" "$file" > "$tmp"
    cat "$tmp" > "$file"
    rm -f "$tmp"
}

validate_config() {
    require_command cp
    require_command find
    require_command git
    require_command grep
    require_command mkdir
    require_command sed

    [ -d "$TEMPLATE_DIR" ] || die "Template directory not found: $TEMPLATE_DIR"
    [ -n "$TARGET_DIR" ] || die "TARGET_DIR cannot be empty"
    case "$TARGET_DIR" in
        /*) ;;
        *) die "TARGET_DIR must be an absolute path" ;;
    esac
    [ "$TARGET_DIR" != "/" ] || die "TARGET_DIR cannot be /"
    [ ! -e "$TARGET_DIR" ] || die "$TARGET_DIR already exists; refusing to modify it"
    [ -n "$LINUX_USER" ] || die "LINUX_USER cannot be empty"
    case "$LINUX_USER" in
        *[!A-Za-z0-9._-]*|"."|"..")
            die "LINUX_USER contains unsupported characters: $LINUX_USER"
            ;;
    esac
}

copy_templates() {
    mkdir -p "$TARGET_DIR"

    cp "$TEMPLATE_DIR/flake.nix" "$TARGET_DIR/flake.nix"
    cp "$TEMPLATE_DIR/home.nix" "$TARGET_DIR/home.nix"
    cp "$TEMPLATE_DIR/.sops.yaml" "$TARGET_DIR/.sops.yaml"
    cp "$TEMPLATE_DIR/sessionizer" "$TARGET_DIR/scripts.sessionizer.tmp"
    cp "$TEMPLATE_DIR/check-secrets.sh" "$TARGET_DIR/scripts.check-secrets.tmp"
    cp -R "$TEMPLATE_DIR/homes" "$TARGET_DIR/homes"
    cp -R "$TEMPLATE_DIR/hosts" "$TARGET_DIR/hosts"
    cp -R "$TEMPLATE_DIR/modules" "$TARGET_DIR/modules"
    cp -R "$TEMPLATE_DIR/secrets" "$TARGET_DIR/secrets"

    mkdir -p \
        "$TARGET_DIR/wezterm" \
        "$TARGET_DIR/tmux" \
        "$TARGET_DIR/nvim/lua/config" \
        "$TARGET_DIR/nvim/lua/plugins" \
        "$TARGET_DIR/vscode" \
        "$TARGET_DIR/scripts" \
        "$TARGET_DIR/xfce4" \
        "$TARGET_DIR/secrets"

    mv "$TARGET_DIR/scripts.sessionizer.tmp" "$TARGET_DIR/scripts/sessionizer"
    mv "$TARGET_DIR/scripts.check-secrets.tmp" "$TARGET_DIR/scripts/check-secrets.sh"
    chmod +x "$TARGET_DIR/scripts/sessionizer"
    chmod +x "$TARGET_DIR/scripts/check-secrets.sh"

    cat > "$TARGET_DIR/wezterm/wezterm.lua" <<'EOF'
-- User-managed WezTerm config.
-- Apply changes with SUPER+SHIFT+R in WezTerm.
-- See workstation-scripts/docs/reference/terminal-config.md.
return {}
EOF
    cat > "$TARGET_DIR/tmux/tmux.conf" <<'EOF'
# User-managed tmux config.
# Apply changes with prefix r after adding a reload binding.
# See workstation-scripts/docs/reference/terminal-config.md.
EOF
    : > "$TARGET_DIR/nvim/init.lua"
    cat > "$TARGET_DIR/nvim/README.md" <<'EOF'
# Neovim Config

`init.lua` is intentionally empty after `init-dotfiles.sh`.

`bootstrap.sh` stages the LazyVim starter into this directory only when `init.lua` is empty. After bootstrap runs, this directory becomes your user-managed Neovim configuration.
EOF
    cat > "$TARGET_DIR/vscode/extensions.json" <<'EOF'
{
  "recommendations": []
}
EOF
    cat > "$TARGET_DIR/.gitignore" <<'EOF'
# Local secrets - never commit
.env
.env.*

# SOPS-encrypted files under secrets/ are safe to commit.
# Do not ignore secrets/*.yaml or secrets/*.env unless they are plaintext.

# macOS metadata
.DS_Store

# Nix build artefacts
result
result-*
EOF
}

apply_placeholders() {
    find "$TARGET_DIR" -name '*.nix' -type f -exec sed -i "s/CHANGE_ME/$LINUX_USER/g" {} +
    if [ -f "$TARGET_DIR/homes/CHANGE_ME.nix" ]; then
        mv "$TARGET_DIR/homes/CHANGE_ME.nix" "$TARGET_DIR/homes/$LINUX_USER.nix"
    fi

    if [ -n "$GIT_NAME" ]; then
        replace_in_file "$TARGET_DIR/modules/git.nix" "YOUR_FULL_NAME" "$GIT_NAME"
    fi
    if [ -n "$GIT_EMAIL" ]; then
        replace_in_file "$TARGET_DIR/modules/git.nix" "YOUR_EMAIL" "$GIT_EMAIL"
    fi
}

init_git() {
    git -C "$TARGET_DIR" init
    git -C "$TARGET_DIR" branch -M main

    if grep -R -n -E 'CHANGE_ME|YOUR_FULL_NAME|YOUR_EMAIL' \
        --include='*.nix' "$TARGET_DIR" >/dev/null; then
        warn "Dotfiles generated, but git name/email placeholders remain."
        warn "Edit $TARGET_DIR/modules/git.nix, then commit manually."
        return 0
    fi

    git -C "$TARGET_DIR" config user.name "$GIT_NAME"
    git -C "$TARGET_DIR" config user.email "$GIT_EMAIL"
    git -C "$TARGET_DIR" add .
    git -C "$TARGET_DIR" commit -m "chore: initial dotfiles structure"
    ok "Initial git commit created"
}

ensure_dotfiles_compat_link() {
    local default_dir="$HOME/dotfiles"
    local target_real
    local default_real

    [ "$TARGET_DIR" != "$default_dir" ] || return 0

    target_real="$(cd "$TARGET_DIR" && pwd -P)"

    if [ -e "$default_dir" ] || [ -L "$default_dir" ]; then
        [ -d "$default_dir" ] || die "$default_dir exists but is not a directory or symlink to a directory"
        default_real="$(cd "$default_dir" && pwd -P)"
        [ "$default_real" = "$target_real" ] || die "$default_dir already points to a different directory. Move it or use --target-dir $default_dir."
        ok "$default_dir already points to $TARGET_DIR"
    else
        ln -s "$TARGET_DIR" "$default_dir"
        ok "Created compatibility symlink: $default_dir -> $TARGET_DIR"
    fi
}

print_next_steps() {
    echo ""
    ok "Private dotfiles project created at $TARGET_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Review generated files:"
    echo "     cd \"$TARGET_DIR\" && git status --short"
    echo "  2. Create a PRIVATE GitHub repository named dotfiles."
    echo "  3. Add the SSH remote and push:"
    echo "     git remote add origin git@github.com:YOUR_GITHUB_USER/dotfiles.git"
    echo "     git push -u origin main"
    echo "  4. Use that private repo with bootstrap.sh:"
    echo "     bash bootstrap.sh --github-user YOUR_GITHUB_USER --dotfiles-repo git@github.com:YOUR_GITHUB_USER/dotfiles.git"
    echo ""
    echo "SOPS note:"
    echo "  .sops.yaml still contains an Age recipient placeholder. Generate and"
    echo "  paste the real recipient after bootstrap creates your Age key."
    echo "  Before creating secrets, verify it with: bash scripts/check-secrets.sh"
}

validate_config
copy_templates
apply_placeholders
init_git
ensure_dotfiles_compat_link
print_next_steps
