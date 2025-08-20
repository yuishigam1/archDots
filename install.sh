#!/usr/bin/env bash
set -euo pipefail

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
  local rel="$1"
  local src="$HOME/$rel"
  if [ -e "$src" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    echo ">>> Backup $rel"
    cp -a "$src" "$BACKUP_DIR/$rel"
  fi
}

safe_sync() {
  local src="$1" dest="$2"
  if [ -d "$src" ]; then
    mkdir -p "$dest"
    rsync -a "$src"/ "$dest"/
  else
    mkdir -p "$(dirname "$dest")"
    rsync -a "$src" "$dest"
  fi
}

# --- ensure basic tools ---
need rsync
need git

# --- update system first ---
echo ">>> Updating system..."
sudo pacman -Syu --noconfirm

# --- bootstrap yay ---
if ! command -v yay &>/dev/null; then
  echo ">>> Installing yay..."
  sudo pacman -S --needed --noconfirm base-devel git
  rm -rf /tmp/yay
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
fi

# --- install packages ---
PACMAN_PKGS=()
AUR_PKGS=()

while read -r pkg; do
  # skip empty lines and comments
  [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

  # check if pacman knows it
  if pacman -Si "$pkg" &>/dev/null; then
    PACMAN_PKGS+=("$pkg")
  else
    AUR_PKGS+=("$pkg")
  fi
done <"$DOTFILES_DIR/packages/pkglist.txt"

# install pacman packages
if ((${#PACMAN_PKGS[@]})); then
  echo ">>> Installing pacman packages..."
  sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
fi

# install AUR packages
if ((${#AUR_PKGS[@]})); then
  echo ">>> Installing AUR packages..."
  yay -S --needed --noconfirm "${AUR_PKGS[@]}"
fi

# --- deploy dotfiles (merge + backup) ---
echo ">>> Deploying dotfiles (merge mode)"

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

# ~/myApps
if [ -d "$DOTFILES_DIR/myApps" ]; then
  backup_path "myApps"
  safe_sync "$DOTFILES_DIR/myApps" "$HOME/myApps"
  find "$HOME/myApps" -type f -name "*.sh" -exec chmod +x {} \;
  if ! grep -q 'export PATH="$HOME/myApps:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/myApps:$PATH"' >>"$HOME/.zshrc"
  fi
fi

echo "✅ Done. Backups at: $BACKUP_DIR"
