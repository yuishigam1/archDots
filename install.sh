#!/usr/bin/env bash
set -euo pipefail

# --- paths ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DOTFILES_DIR="$SCRIPT_DIR"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%s)"
PKGLIST="$DOTFILES_DIR/packages/pkglist.txt"

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
    echo ">>> Backing up $rel"
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

enable_service() {
  local svc=$1
  if systemctl list-unit-files | grep -q "^${svc}"; then
    echo ">>> Enabling $svc"
    sudo systemctl enable --now "$svc"
  else
    echo ">>> Service $svc not found, skipping"
  fi
}

# --- ensure basic tools ---
need rsync
need git

# --- update system ---
echo ">>> Updating system..."
sudo pacman -Sy --noconfirm
sudo pacman -Su --noconfirm

# --- bootstrap yay ---
if ! command -v yay &>/dev/null; then
  echo ">>> Installing yay..."
  sudo pacman -S --needed --noconfirm base-devel git
  rm -rf /tmp/yay
  git clone https://aur.archlinux.org/yay.git /tmp/yay
  (cd /tmp/yay && makepkg -si --noconfirm)
  rm -rf /tmp/yay
fi

# --- dynamic package separation ---
PACMAN_PKGS=()
AUR_PKGS=()
if [[ -f "$PKGLIST" ]]; then
  while read -r pkg; do
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    if pacman -Si "$pkg" &>/dev/null; then
      PACMAN_PKGS+=("$pkg")
    else
      AUR_PKGS+=("$pkg")
    fi
  done <"$PKGLIST"
fi

remove_conflicts() {
  local pkg="$1"
  # Get conflicts from pacman -Si, remove commas, split by space
  local conflicts
  conflicts=$(pacman -Si "$pkg" 2>/dev/null | grep "Conflicts With" | cut -d: -f2 | tr ',' ' ')

  for c in $conflicts; do
    c=$(echo "$c" | xargs) # trim whitespace
    if pacman -Qi "$c" &>/dev/null; then
      echo ">>> Removing conflicting package $c"
      sudo pacman -R --noconfirm "$c" || true
    else
      echo ">>> Conflict $c not installed, skipping"
    fi
  done
}

# --- install pacman packages ---
if ((${#PACMAN_PKGS[@]})); then
  echo ">>> Installing pacman packages..."
  sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
fi

# --- install AUR packages ---
if ((${#AUR_PKGS[@]})); then
  echo ">>> Installing AUR packages..."
  yay -S --needed --noconfirm "${AUR_PKGS[@]}"
fi

# --- deploy .config directories ---
echo ">>> Deploying .config directories"
mkdir -p "$HOME/.config"
for dir in "$DOTFILES_DIR/.config"/*; do
  name="$(basename "$dir")"
  backup_path ".config/$name"
  safe_sync "$dir" "$HOME/.config/$name"
done

# --- deploy individual dotfiles (if any) in root ---
for file in "$DOTFILES_DIR"/.*; do
  name="$(basename "$file")"
  [[ "$name" == "." || "$name" == ".." || "$name" == ".config" ]] && continue
  backup_path "$name"
  safe_sync "$file" "$HOME/$name"
done

# --- deploy ~/.local/share/applications ---
if [ -d "$DOTFILES_DIR/.local/share/applications" ]; then
  mkdir -p "$HOME/.local/share/applications"
  for file in "$DOTFILES_DIR/.local/share/applications"/*; do
    name="$(basename "$file")"
    backup_path ".local/share/applications/$name"
    safe_sync "$file" "$HOME/.local/share/applications/$name"
  done
fi

# --- deploy ~/.local/share/bin ---
if [ -d "$DOTFILES_DIR/.local/share/bin" ]; then
  mkdir -p "$HOME/.local/share/bin"
  for file in "$DOTFILES_DIR/.local/share/bin"/*; do
    name="$(basename "$file")"
    backup_path ".local/share/bin/$name"
    safe_sync "$file" "$HOME/.local/share/bin/$name"
  done
fi

# --- deploy ~/myApps ---
if [ -d "$DOTFILES_DIR/myApps" ]; then
  backup_path "myApps"
  safe_sync "$DOTFILES_DIR/myApps" "$HOME/myApps"
  find "$HOME/myApps" -type f -name "*.sh" -exec chmod +x {} \;
  grep -qxF 'export PATH="$HOME/myApps:$PATH"' "$HOME/.zshrc" ||
    echo 'export PATH="$HOME/myApps:$PATH"' >>"$HOME/.zshrc"
fi

# --- deploy zsh plugins ---
if [ -d "$DOTFILES_DIR/.zsh_plugins" ]; then
  mkdir -p "$HOME/.oh-my-zsh/custom/plugins"
  for plugin in "$DOTFILES_DIR/.zsh_plugins"/*; do
    safe_sync "$plugin" "$HOME/.oh-my-zsh/custom/plugins/$(basename $plugin)"
  done
fi

# --- deploy hyde theme manually ---
THEME_DIR="$HOME/.config/hyde/themes/Ever Blushing"
mkdir -p "$THEME_DIR"
if [ -d "$DOTFILES_DIR/themes/Ever Blushing" ]; then
  safe_sync "$DOTFILES_DIR/themes/Ever Blushing" "$THEME_DIR"
fi

# --- enable system services ---
services=(sddm.service hyprland.service pipewire.service wireplumber.service swww.service qemu-guest-agent.service upower.service NetworkManager.service)
for svc in "${services[@]}"; do
  enable_service "$svc"
done

# --- setup SDDM theme ---
echo ">>> Setting up SDDM Astronaut theme..."
echo -e "1\n5" | sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"

echo "✅ Done. Backups at: $BACKUP_DIR"
echo ">>> System services enabled, packages installed, and dotfiles deployed."
