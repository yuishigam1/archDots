#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Paths
# -----------------------------
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
PLUGINS_DIR="$ZSH_CUSTOM/plugins"
mkdir -p "$PLUGINS_DIR"

# -----------------------------
# Detect AUR helper
# -----------------------------
if command -v yay &>/dev/null; then
  AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
  AUR_HELPER="paru"
else
  echo "No AUR helper found (yay or paru required). Exiting."
  exit 1
fi

# -----------------------------
# Zsh plugins (correct GitHub URLs)
# -----------------------------
declare -A ZSH_PLUGINS=(
  ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
  ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
  ["zsh-256color"]="https://github.com/chrissicool/zsh-256color"
)

for plugin in "${!ZSH_PLUGINS[@]}"; do
  DEST="$PLUGINS_DIR/$plugin"
  if [[ ! -d "$DEST" ]]; then
    echo ">>> Installing ZSH plugin: $plugin"
    git clone "${ZSH_PLUGINS[$plugin]}" "$DEST"
  else
    echo ">>> Updating ZSH plugin: $plugin"
    git -C "$DEST" pull --ff-only
  fi
done

# -----------------------------
# Nerd Fonts installation
# -----------------------------
FONTS_AUR=("ttf-jetbrains-mono-nerd" "ttf-caskaydia-cove-nerd-font")
for font in "${FONTS_AUR[@]}"; do
  FONT_NAME=$(echo "$font" | sed 's/ttf-//;s/-/ /g')
  if ! fc-list | grep -iq "$FONT_NAME"; then
    echo ">>> Installing Nerd Font: $font"
    $AUR_HELPER -S --needed --noconfirm "$font"
  else
    echo ">>> Font $font already installed"
  fi
done
fc-cache -fv

echo ">>> ZSH environment setup complete!"
