#!/usr/bin/env bash
set -euo pipefail

# --- paths ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%s)"

echo ">>> Backups -> $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# --- helpers ---
need() { command -v "$1" >/dev/null 2>&1 || {
  echo ">>> Installing $1..."
  sudo pacman -S --needed --noconfirm "$1"
}; }

backup_path() {
  # $1 is path relative to $HOME (e.g. '.zshrc' or '.config/kitty')
  local rel="$1"
  local src="$HOME/$rel"
  if [ -e "$src" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    echo ">>> Backup $rel"
    cp -a "$src" "$BACKUP_DIR/$rel"
  fi
}

safe_sync() {
  # $1=source (in repo), $2=dest (in $HOME)
  local src="$1" dest="$2"
  if [ -d "$src" ]; then
    mkdir -p "$dest"
    rsync -a "$src"/ "$dest"/
  else
    mkdir -p "$(dirname "$dest")"
    rsync -a "$src" "$dest"
  fi
}

# --- ensure tools ---
need rsync
need git

# --- packages ---
echo ">>> Installing packages"
if [ -f "$DOTFILES_DIR/packages/pkglist_native.txt" ]; then
  sudo pacman -Syu --needed - <"$DOTFILES_DIR/packages/pkglist_native.txt"
fi

if [ -f "$DOTFILES_DIR/packages/pkglist_aur.txt" ]; then
  if ! command -v yay >/dev/null 2>&1; then
    echo ">>> yay not found, bootstrapping..."
    sudo pacman -S --needed --noconfirm base-devel git
    rm -rf /tmp/yay
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
  fi
  yay -Syu --needed --noconfirm - <"$DOTFILES_DIR/packages/pkglist_aur.txt"
fi

# --- deploy dotfiles (merge + backup only what we touch) ---
echo ">>> Deploying dotfiles (merge mode)"

# zshrc
backup_path ".zshrc"
safe_sync "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

# ~/.config/*
mkdir -p "$HOME/.config"
if [ -d "$DOTFILES_DIR/.config" ]; then
  for item in "$DOTFILES_DIR/.config"/*; do
    name="$(basename "$item")"
    backup_path ".config/$name"
    safe_sync "$item" "$HOME/.config/$name"
  done
fi

# ~/.local/share/applications/*
mkdir -p "$HOME/.local/share/applications"
if [ -d "$DOTFILES_DIR/.local/share/applications" ]; then
  for file in "$DOTFILES_DIR/.local/share/applications"/*; do
    name="$(basename "$file")"
    backup_path ".local/share/applications/$name"
    safe_sync "$file" "$HOME/.local/share/applications/$name"
  done
fi

# ~/myApps (your custom launch scripts)
if [ -d "$DOTFILES_DIR/myApps" ]; then
  backup_path "myApps"
  safe_sync "$DOTFILES_DIR/myApps" "$HOME/myApps"
  # ensure scripts are executable
  find "$HOME/myApps" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
  # add to PATH if not already
  if ! grep -q 'export PATH="$HOME/myApps:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/myApps:$PATH"' >>"$HOME/.zshrc"
    echo '>>> Appended to .zshrc: export PATH="$HOME/myApps:$PATH"'
  fi
fi

echo "✅ Done. Backups at: $BACKUP_DIR"
