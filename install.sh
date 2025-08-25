#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts/"

# Menu options
declare -A MODULES=(
  [1]="Packages (pacman + AUR)"
  [2]="Dotfiles & .config"
  [3]="myApps & myIcons"
  [4]="Zsh + Plugins + Nerd Fonts"
  [5]="Enable system services + SDDM theme"
  [6]="OCR4Linux"
  [7]="Neovim"
  [8]="All"
)

echo "Select what you want to run:"
for i in "${!MODULES[@]}"; do
  echo "  $i) ${MODULES[$i]}"
done

read -rp "Enter number (e.g. 1 or 9 for all) [grubsetup won't be included in all]: " choice

run_script() {
  local script="$SCRIPTS_DIR/$1.sh"
  if [[ -f "$script" ]]; then
    echo ">>> Running $1..."
    if [[ "$1" == "grubsetup" ]]; then
      sudo bash "$script"
    else
      bash "$script"
    fi
  else
    echo ">>> Script $1.sh not found, skipping..."
  fi
}

case "$choice" in
1) run_script "packages" ;;
2) run_script "dotfiles" ;;
3) run_script "apps" ;;
4) run_script "zsh" ;;
5) run_script "services" ;;
6) run_script "OCR4Linux" ;;
7) run_script "neovimsetup" ;;
8)
  run_script "packages"
  run_script "dotfiles"
  run_script "apps"
  run_script "zsh"
  run_script "services"
  run_script "OCR4Linux"
  run_script "neovimsetup"
  ;;
*)
  echo "Invalid choice"
  exit 1
  ;;
esac
