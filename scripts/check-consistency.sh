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

echo "consistency checks passed"
