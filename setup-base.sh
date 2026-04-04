#!/usr/bin/env bash
# setup-base.sh
# Installs base system packages needed before the Nix bootstrap.
# Works on any Ubuntu 22.04/24.04 machine – bare metal, VM, or cloud.
# Safe to re-run (idempotent).
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
step() { echo -e "${GREEN}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}✓ $1${NC}"; }

step "Updating package index"
sudo apt update && sudo apt upgrade -y
ok "Package index updated"

step "Installing base packages"
sudo apt install -y \
    curl wget git openssh-client build-essential ca-certificates gnupg unzip zip xz-utils
ok "Base packages installed"

echo ""
echo -e "${GREEN}✔ Base setup complete.${NC}"
echo ""
echo "Next steps:"
echo "  - Generate your SSH key and register it on GitHub"
echo "  - Run bootstrap.sh"
echo ""
