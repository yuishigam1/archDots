#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PKGLIST="$SCRIPT_DIR/../packages/pkglist.txt"

PACMAN_PKGS=()
AUR_PKGS=()

# Separate packages into pacman vs AUR
while read -r pkg; do
  [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
  if pacman -Si "$pkg" &>/dev/null; then
    PACMAN_PKGS+=("$pkg")
  else
    AUR_PKGS+=("$pkg")
  fi
done <"$PKGLIST"

# Function for conflict-safe pacman install
install_pacman_pkg() {
  local pkg="$1"
  echo ">>> Installing $pkg..."
  if ! sudo pacman -S --needed --noconfirm "$pkg"; then
    conflicts=$(pacman -Si "$pkg" 2>/dev/null | awk -F: '/Conflicts With/ {print $2}' | tr ',' ' ')
    for c in $conflicts; do
      c=$(echo "$c" | xargs)
      if pacman -Qi "$c" &>/dev/null; then
        echo ">>> Removing conflicting package $c (force)"
        sudo pacman -Rdd --noconfirm "$c" || true
      fi
    done
    sudo pacman -S --needed --noconfirm "$pkg"
  fi
}

for pkg in "${PACMAN_PKGS[@]}"; do
  install_pacman_pkg "$pkg"
done

if ((${#AUR_PKGS[@]})); then
  echo ">>> Installing AUR packages..."
  yay -S --needed --noconfirm "${AUR_PKGS[@]}"
fi
