#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Detect dotfiles repo dynamically
# -----------------------------
# Look for "archDots" or ".archDots" in home directory
DOTFILES_PATH=""
for dir in "$HOME"/archDots "$HOME"/.archDots; do
  if [ -d "$dir" ]; then
    DOTFILES_PATH="$dir"
    break
  fi
done

if [ -z "$DOTFILES_PATH" ]; then
  echo "No dotfiles repo found in home directory (archDots or .archDots). Exiting."
  exit 1
fi

CUSTOM_NVIM_PATH="$DOTFILES_PATH/.config/nvim"
LAZYVIM_PATH="$HOME/.config/nvim"

# -----------------------------
# Backup existing Neovim configs
# -----------------------------
echo "Backing up existing Neovim configs..."
mv "$LAZYVIM_PATH"{,.bak} 2>/dev/null || true
mv ~/.local/share/nvim{,.bak} 2>/dev/null || true
mv ~/.local/state/nvim{,.bak} 2>/dev/null || true
mv ~/.cache/nvim{,.bak} 2>/dev/null || true

# -----------------------------
# Install LazyVim starter
# -----------------------------
rm -rf $LAZYVIM_PATH
echo "Cloning LazyVim starter into $LAZYVIM_PATH..."
git clone https://github.com/LazyVim/starter "$LAZYVIM_PATH"
rm -rf "$LAZYVIM_PATH/.git"

# -----------------------------
# Overlay custom config if exists
# -----------------------------
if [ -d "$CUSTOM_NVIM_PATH" ] && [ "$(ls -A "$CUSTOM_NVIM_PATH")" ]; then
  echo "Copying custom Neovim config from $CUSTOM_NVIM_PATH..."
  cp -r "$CUSTOM_NVIM_PATH/"* "$LAZYVIM_PATH/"
else
  echo "No custom Neovim config found at $CUSTOM_NVIM_PATH, skipping overlay."
fi

echo "Neovim setup complete!"
