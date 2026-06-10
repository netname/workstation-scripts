#!/usr/bin/env bash
# Repository-specific documentation/script consistency checks.

set -euo pipefail

fail() {
    echo "consistency check failed: $1" >&2
    exit 1
}

command -v grep >/dev/null 2>&1 || fail "grep is required"

if grep -R "workstation-scripts/main/setup-desktop.sh" README.md docs scripts/bootstrap.sh scripts/setup-desktop.sh templates; then
    fail "raw setup-desktop.sh URLs must include /scripts/setup-desktop.sh"
fi

if grep -R -n -E '^[[:space:]]*(GITHUB_USER|DOTFILES_REPO|DOTFILES_DIR|SSH_KEY_PATH)=".*yourusername' scripts; then
    fail "live script configuration must not assign example placeholder values"
fi

if grep -R -n "git -C \"\$DOTFILES_DIR\" reset --hard origin/main" scripts/bootstrap.sh scripts/setup-desktop.sh; then
    fail "bootstrap must not hard-reset dotfiles without an explicit --force-reset path"
fi

if grep -R -n -E "three (runnable setup scripts|working scripts|scripts to populate)" README.md docs; then
    fail "workstation-scripts has two runnable setup scripts; docs must not claim three"
fi

if grep -R -n -E 'Edit `bootstrap\.sh`|^[[:space:]]*GITHUB_USER="yourusername"|^[[:space:]]*DOTFILES_REPO="git@github.com:yourusername/dotfiles\.git"' docs README.md; then
    fail "docs must not instruct users to hard-code personal values in bootstrap.sh"
fi

if grep -R -n -E "§3\.13|See §3\.4 for the full v15/v16|bootstrap step 13|Reference Files section below|annotated versions below are identical|§K\.3" docs templates scripts/bootstrap.sh scripts/setup-desktop.sh README.md; then
    fail "stale section references found"
fi

if grep -R -n -E 'replace every occurrence of `yourusername`|`flake\.nix` also contains `yourusername`' docs README.md; then
    fail "docs must refer to CHANGE_ME, not yourusername, for template placeholder replacement"
fi

echo "consistency checks passed"
