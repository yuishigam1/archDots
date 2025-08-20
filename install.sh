#!/usr/bin/env bash
set -e

DOTFILES_DIR="/usr/share/fastsetup"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%s)"

echo ">>> Backing up old configs to $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

backup() {
  if [ -e "$1" ]; then
    echo "Backing up $1"
    mv "$1" "$BACKUP_DIR/"
  fi
}

# Backup configs
backup "$HOME/.zshrc"
backup "$HOME/.config"
backup "$HOME/.local/share/applications"

echo ">>> Installing packages"

# Install pacman packages
if [ -f "$DOTFILES_DIR/packages/pkglist_native.txt" ]; then
  sudo pacman -Syu --needed - <"$DOTFILES_DIR/packages/pkglist_native.txt"
fi

# Install AUR packages (requires yay)
if [ -f "$DOTFILES_DIR/packages/pkglist_aur.txt" ]; then
  if ! command -v yay >/dev/null 2>&1; then
    echo "yay not found, installing..."
    sudo pacman -S --needed --noconfirm base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
    cd "$DOTFILES_DIR"
  fi
  yay -Syu --needed --noconfirm - <"$DOTFILES_DIR/packages/pkglist_aur.txt"
fi

echo ">>> Copying dotfiles"

# Copy configs
cp -r "$DOTFILES_DIR/.config" "$HOME/"
cp -r "$DOTFILES_DIR/.local" "$HOME/"
cp "$DOTFILES_DIR/.zshrc" "$HOME/"

echo ">>> Done! 🎉"
echo "Backup saved at: $BACKUP_DIR"
