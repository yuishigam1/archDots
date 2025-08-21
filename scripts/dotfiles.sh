#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/../../"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%s)"

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

echo ">>> Deploying .config folders..."
# Deploy .config
mkdir -p "$HOME/.config"
for dir in "$DOTFILES_DIR/.config"/*; do
  name="$(basename "$dir")"
  backup_path ".config/$name"
  safe_sync "$dir" "$HOME/.config/$name"
done

echo ">>> Deploying individual dotfiles..."
# Deploy individual dotfiles
for file in "$DOTFILES_DIR"/.*; do
  name="$(basename "$file")"
  [[ "$name" == "." || "$name" == ".." || "$name" == ".config" ]] && continue
  backup_path "$name"
  safe_sync "$file" "$HOME/$name"
done

echo ">>> Setting GTK & Hyprland environment variables..."
# Ensure env variables for GTK/Qt apps and Hyprland
PROFILE_FILE="$HOME/.zprofile"
grep -qxF 'export XDG_CURRENT_DESKTOP=Hyprland' "$PROFILE_FILE" || echo 'export XDG_CURRENT_DESKTOP=Hyprland' >>"$PROFILE_FILE"
grep -qxF 'export GTK_THEME=Ever-Blush:dark' "$PROFILE_FILE" || echo 'export GTK_THEME=Ever-Blush:dark' >>"$PROFILE_FILE"
grep -qxF 'export QT_QPA_PLATFORMTHEME=gtk3' "$PROFILE_FILE" || echo 'export QT_QPA_PLATFORMTHEME=gtk3' >>"$PROFILE_FILE"

echo ">>> Ensuring polkit agent is running..."
# Polkit agent autostart for Hyprland
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
POLKIT_DESKTOP_FILE="$AUTOSTART_DIR/polkit-gnome-authentication-agent.desktop"

cat >"$POLKIT_DESKTOP_FILE" <<'EOF'
[Desktop Entry]
Type=Application
Name=Polkit Authentication Agent
Exec=/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

echo ">>> Dotfiles deployed and GTK/Polkit configured. Please restart your session for changes to take effect."
