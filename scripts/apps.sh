#!/usr/bin/env bash
set -euo pipefail

# Absolute path to the repo root
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DOTFILES_DIR="$(realpath "$SCRIPT_DIR/../..")" # adjust depending on script location
echo $SCRIPT_DIR
echo $DOTFILES_DIR
# Directories to sync
for dir_name in myApps myIcons; do
  SRC="$DOTFILES_DIR/$dir_name"
  DEST="$HOME/$dir_name"
  echo $SRC
  echo $DEST
  if [ -d "$SRC" ]; then
    mkdir -p "$DEST"
    rsync -a --delete "$SRC/" "$DEST/"
    find "$DEST" -type f -name "*.sh" -exec chmod +x {} \;

    # Add to PATH in .zshrc if not already
    grep -qxF "export PATH=\"\$HOME/$dir_name:\$PATH\"" "$HOME/.zshrc" ||
      echo "export PATH=\"\$HOME/$dir_name:\$PATH\"" >>"$HOME/.zshrc"
  fi
done
