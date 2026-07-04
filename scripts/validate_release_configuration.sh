#!/bin/sh
set -eu

if [ "${CONFIGURATION:-}" = "Release" ] && [ -z "${SPARKLE_PUBLIC_ED_KEY:-}" ]; then
    echo "error: SPARKLE_PUBLIC_ED_KEY is empty. Run Sparkle's generate_keys and add the printed public key before archiving a Release build."
    exit 1
fi
