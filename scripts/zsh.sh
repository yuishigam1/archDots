#!/usr/bin/env bash
set -euo pipefail

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGINS=(
  zsh-users/zsh-autosuggestions
  zsh-users/zsh-syntax-highlighting
  jeffreytse/zsh-256color
)

# Create plugins directory if it doesn't exist
mkdir -p "$ZSH_CUSTOM/plugins"

# Clone or update plugins
for plugin in "${PLUGINS[@]}"; do
  plugin_dir="$ZSH_CUSTOM/plugins/$(basename "$plugin")"
  if [ ! -d "$plugin_dir" ]; then
    echo "Cloning $plugin..."
    git clone "https://github.com/$plugin" "$plugin_dir"
  else
    echo "Updating $plugin..."
    git -C "$plugin_dir" pull
  fi
done

# Install Nerd Fonts if not already installed
FONTS_AUR=("ttf-jetbrains-mono-nerd" "ttf-caskaydia-cove-nerd-font")
for font in "${FONTS_AUR[@]}"; do
  if ! fc-list | grep -i "$(echo $font | sed 's/ttf-//;s/-/ /g')" &>/dev/null; then
    echo "Installing $font..."
    yay -S --needed --noconfirm "$font"
  fi
done

# Rebuild font cache
fc-cache -fv
