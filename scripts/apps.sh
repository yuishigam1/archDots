#!/usr/bin/env bash
set -euo pipefail

# Path to the dotfiles repo (assume this script is inside the repo)
DOTFILES_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/../../ >/dev/null 2>&1 && pwd)"
echo $DOTFILES_DIR
# List of directories to sync directly to ~/
for dir_name in myApps myIcons; do
  SRC="$DOTFILES_DIR/$dir_name"
  DEST="$HOME/$dir_name"
  echo $SRC
  echo $DEST
  if [ -d "$SRC" ]; then
    # Create target directory
    mkdir -p "$DEST"
    # Directly sync files from repo to home
    rsync -a --delete "$SRC/" "$DEST/"
    # Make all .sh files executable
    find "$DEST" -type f -name "*.sh" -exec chmod +x {} \;

    # Add to PATH if not already in .zshrc
    grep -qxF "export PATH=\"\$HOME/$dir_name:\$PATH\"" "$HOME/.zshrc" ||
      echo "export PATH=\"\$HOME/$dir_name:\$PATH\"" >>"$HOME/.zshrc"
  fi
done
