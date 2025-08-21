#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/../../"

for dir_name in myApps myIcons; do
  DIR="$DOTFILES_DIR/$dir_name"
  if [ -d "$DIR" ]; then
    mkdir -p "$HOME/$dir_name"
    rsync -a "$DIR/" "$HOME/$dir_name/"
    find "$HOME/$dir_name" -type f -name "*.sh" -exec chmod +x {} \;
    grep -qxF "export PATH=\"\$HOME/$dir_name:\$PATH\"" "$HOME/.zshrc" ||
      echo "export PATH=\"\$HOME/$dir_name:\$PATH\"" >>"$HOME/.zshrc"
  fi
done
