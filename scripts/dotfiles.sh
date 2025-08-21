#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/../"

safe_sync() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  rsync -a "$src" "$dest"
}

echo $SCRIPT_DIR+" "$DOTFILES_DIR
echo ">>> Deploying icon theme"
mkdir -p "$HOME/.icons"
safe_sync "$DOTFILES_DIR/.icons/Papirus-Everblush" "$HOME/.icons/Papirus-Everblush"

echo ">>> Deploying .config"
mkdir -p "$HOME/.config"
for dir in "$DOTFILES_DIR/.config"/*; do
  name="$(basename "$dir")"
  safe_sync "$dir" "$HOME/.config/$name"
done

echo ">>> Deploying individual dotfiles"
for file in "$DOTFILES_DIR"/.*; do
  name="$(basename "$file")"
  echo "$file"
  [[ "$name" == "." || "$name" == ".." || "$name" == ".config" || "$name" == ".git" || "$name" == ".cache" || "$name" == ".local" ]] && continue
  safe_sync "$file" "$HOME/$name"
done

echo ">>> Deploying Nerd Fonts"
mkdir -p "$HOME/.local/share/fonts"
safe_sync "$DOTFILES_DIR/.local/share/fonts" "$HOME/.local/share/fonts"

echo ">>> Deploying .themes"
mkdir -p "$HOME/.themes"
safe_sync "$DOTFILES_DIR/.themes" "$HOME/"

echo ">>> Deploying OCR4Linux"
git clone https://github.com/moheladwy/OCR4Linux ~/

echo ">>> Updating font cache"
fc-cache -fv

echo ">>> Dotfiles deployment complete!"
