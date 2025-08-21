#!/usr/bin/env bash
set -euo pipefail

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

mkdir -p "$ZSH_CUSTOM/plugins"

# zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" || true
git clone https://github.com/jeffreytse/zsh-256color "$ZSH_CUSTOM/plugins/zsh-256color" || true

# Nerd Fonts
FONTS_AUR=("ttf-jetbrains-mono-nerd" "ttf-caskaydia-cove-nerd-font")
for font in "${FONTS_AUR[@]}"; do
  if ! fc-list | grep -i "$(echo $font | sed 's/ttf-//;s/-/ /g')" &>/dev/null; then
    yay -S --needed --noconfirm "$font"
  fi
done
fc-cache -fv
