#!/usr/bin/env bash
# Fail if SOPS configuration still contains template placeholders.

set -euo pipefail

if grep -R -n "age1replace_with_your_age_public_key" .sops.yaml secrets 2>/dev/null; then
    echo "SOPS Age recipient placeholder is still present." >&2
    echo "Generate your recipient with:" >&2
    echo "  age-keygen -y ~/.config/sops/age/keys.txt" >&2
    echo "Then replace age1replace_with_your_age_public_key in .sops.yaml." >&2
    exit 1
fi

echo "SOPS placeholder check passed"
