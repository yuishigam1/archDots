#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/../../"
BACKUP_DIR="$HOME/.dotfiles_backup"

# Clear previous backup
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

backup_path() {
  local rel="$1"
  local src="$HOME/$rel"
  if [ -e "$src" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    echo ">>> Backing up $rel"
    cp -a "$src" "$BACKUP_DIR/$rel"
  fi
}

safe_sync() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  rsync -a "$src" "$dest"
}

echo ">>> Deploying .config"
mkdir -p "$HOME/.config"
for dir in "$DOTFILES_DIR/.config"/*; do
  name="$(basename "$dir")"
  # backup_path ".config/$name"
  safe_sync "$dir" "$HOME/.config/$name"
done

# Deploy individual dotfiles
for file in "$DOTFILES_DIR"/.*; do
  name="$(basename "$file")"
  [[ "$name" == "." || "$name" == ".." || "$name" == ".config" || "$name" == ".dotfiles_backup" ]] && continue
  # backup_path "$name"
  safe_sync "$file" "$HOME/$name"
done

# Install icon theme
echo ">>> Deploying icon theme"
mkdir -p "$HOME/.icons"
safe_sync "$DOTFILES_DIR/.icons/Papirus-Everblush" "$HOME/.icons/Papirus-Everblush"

# Install Nerd Fonts
echo ">>> Deploying Nerd Fonts"
mkdir -p "$HOME/.local/share/fonts"
safe_sync "$DOTFILES_DIR/.local/share/fonts" "$HOME/.local/share/fonts"

# Update font cache
fc-cache -fv
echo ">>> Font cache updated"

echo ">>> Dotfiles deployment complete!"
