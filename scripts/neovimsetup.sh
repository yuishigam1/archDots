#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Variables (change these if needed)
# -----------------------------
CUSTOM_NVIM_PATH="${HOME}/archDots/.config/nvim" # your custom nvim config
LAZYVIM_PATH="${HOME}/.config/nvim"              # where nvim will be installed

# -----------------------------
# Backup existing Neovim configs
# -----------------------------
echo "Backing up existing Neovim configs..."
mv "${LAZYVIM_PATH}"{,.bak} 2>/dev/null || true
mv ~/.local/share/nvim{,.bak} 2>/dev/null || true
mv ~/.local/state/nvim{,.bak} 2>/dev/null || true
mv ~/.cache/nvim{,.bak} 2>/dev/null || true

# -----------------------------
# Install LazyVim starter
# -----------------------------
echo "Cloning LazyVim starter into ${LAZYVIM_PATH}..."
git clone https://github.com/LazyVim/starter "${LAZYVIM_PATH}"
rm -rf "${LAZYVIM_PATH}/.git"

# -----------------------------
# Overlay custom config
# -----------------------------
echo "Copying custom Neovim config from ${CUSTOM_NVIM_PATH}..."
cp -r "${CUSTOM_NVIM_PATH}/"* "${LAZYVIM_PATH}/"

echo "Neovim setup complete!"
