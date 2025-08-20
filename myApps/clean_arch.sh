#!/bin/bash

echo "Updating system..."
sudo pacman -Syu --noconfirm
if command -v yay &>/dev/null; then
  yay -Syu --noconfirm
fi

echo "Cleaning package cache..."
sudo pacman -Sc --noconfirm
if command -v yay &>/dev/null; then
  yay -Yc --noconfirm
fi

echo "Removing orphaned packages..."
orphans=$(pacman -Qdtq)
if [ -n "$orphans" ]; then
  sudo pacman -Rns --noconfirm $orphans
else
  echo "No orphaned packages found."
fi

echo "System cleanup complete!"
