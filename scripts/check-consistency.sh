#!/usr/bin/env bash
# Repository-specific documentation/script consistency checks.

set -euo pipefail

fail() {
    echo "consistency check failed: $1" >&2
    exit 1
}

command -v grep >/dev/null 2>&1 || fail "grep is required"

require_file_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"
    grep -q -E "$pattern" "$file" || fail "$message"
}

if grep -R "workstation-scripts/main/setup-desktop.sh" README.md docs scripts/bootstrap.sh scripts/setup-desktop.sh templates; then
    fail "raw setup-desktop.sh URLs must include /scripts/setup-desktop.sh"
fi

if grep -R -n -E '^[[:space:]]*(GITHUB_USER|DOTFILES_REPO|DOTFILES_DIR|SSH_KEY_PATH)=".*yourusername' scripts; then
    fail "live script configuration must not assign example placeholder values"
fi

if grep -R -n "git -C \"\$DOTFILES_DIR\" reset --hard origin/main" scripts/bootstrap.sh scripts/setup-desktop.sh; then
    fail "bootstrap must not hard-reset dotfiles without an explicit --force-reset path"
fi

ACTIVE_DOC_PATHS=(README.md docs/*.md docs/tutorials docs/how-to docs/reference docs/explanation)

require_file_contains README.md 'tools/' "README must document the tools directory"
require_file_contains README.md 'tools/check-markdown-links\.ps1' "README must document the Markdown link checker"
require_file_contains docs/reference/repository-layout.md 'tools/check-markdown-links\.ps1' "repository layout reference must document the Markdown link checker"
require_file_contains docs/contributing-docs.md 'tools/check-markdown-links\.ps1' "contributing docs must include the Markdown link checker"

if grep -R -n -E "two (runnable setup scripts|working scripts|scripts to populate)" "${ACTIVE_DOC_PATHS[@]}"; then
    fail "workstation-scripts has three runnable scripts; docs must not claim two"
fi

if grep -R -n -E 'nvim home\.nix|git add home\.nix|`~/dotfiles/home\.nix` or modules' docs/tutorials docs/how-to docs/reference; then
    fail "docs should direct workstation edits to concrete module files, not the home.nix compatibility wrapper"
fi

if grep -R -n -E 'packages declared in home\.nix|home\.nix packages|home\.nix.*nerd-fonts|alias defined in home\.nix' scripts templates docs; then
    fail "Home Manager package and alias references should name modules/host files, not home.nix"
fi

if grep -R -n 'tmux source-file ~/.tmux.conf' "${ACTIVE_DOC_PATHS[@]}" templates; then
    fail "tmux reload examples must use ~/.config/tmux/tmux.conf"
fi

if grep -n -E '^[[:space:]]*# [A-Z0-9_]+ = ".*\$\{[A-Z0-9_]+(:-|})' templates/devenv.nix; then
    fail "devenv.nix env attrset examples must not use shell interpolation syntax inside Nix strings"
fi

if grep -R -n -E 'Edit `bootstrap\.sh`|^[[:space:]]*GITHUB_USER="yourusername"|^[[:space:]]*DOTFILES_REPO="git@github.com:yourusername/dotfiles\.git"' "${ACTIVE_DOC_PATHS[@]}"; then
    fail "docs must not instruct users to hard-code personal values in bootstrap.sh"
fi

if grep -R -n -E "docs/[0-9]-|§[0-9A-Z]|§3\.13|See §3\.4 for the full v15/v16|bootstrap step 13|Reference Files section below|annotated versions below are identical|§K\.3" "${ACTIVE_DOC_PATHS[@]}" templates scripts/bootstrap.sh scripts/setup-desktop.sh; then
    fail "stale section references found"
fi

if grep -R -n -E 'replace every occurrence of `yourusername`|`flake\.nix` also contains `yourusername`' "${ACTIVE_DOC_PATHS[@]}"; then
    fail "docs must refer to CHANGE_ME, not yourusername, for template placeholder replacement"
fi

if grep -R -n -E 'requires? (a )?public dotfiles|public dotfiles (repo|repository) (is|required)' "${ACTIVE_DOC_PATHS[@]}" scripts templates; then
    fail "docs must not make public dotfiles mandatory"
fi

if grep -R -n "ssh-keyscan github.com" scripts/bootstrap.sh scripts/setup-desktop.sh "${ACTIVE_DOC_PATHS[@]}" templates; then
    fail "do not trust live ssh-keyscan output for github.com; use published GitHub host keys"
fi

if grep -R -n -E '"[0-9]+:[0-9]+"' templates/docker-compose.yml "${ACTIVE_DOC_PATHS[@]}"; then
    fail "Docker Compose examples must bind development ports to 127.0.0.1"
fi

if grep -R -n -E 'MYSQL_ROOT_PASSWORD: "123"|MARIADB_ROOT_PASSWORD: root|MARIADB_PASSWORD: mypassword' templates/docker-compose.yml "${ACTIVE_DOC_PATHS[@]}"; then
    fail "Docker Compose examples must not contain trivial database passwords"
fi

if grep -R -n "ubuntu-latest" .github/workflows; then
    fail "repo CI must pin a specific Ubuntu runner image"
fi

if grep -R -n "actions/checkout@v[0-9]" .github/workflows; then
    fail "repo CI must pin actions/checkout to a full commit SHA"
fi

echo "consistency checks passed"
