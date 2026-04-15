#!/bin/sh
# shellcheck shell=dash

set -eu

INSTALL_URL="https://raw.githubusercontent.com/wester11/podpodkop/main/podkop-fork/install.sh"

# One-command installer wrapper compatible with OpenWrt ash.
if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$INSTALL_URL" | sh -s -- "$@"
else
    wget -O - "$INSTALL_URL" | sh -s -- "$@"
fi
