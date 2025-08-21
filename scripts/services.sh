#!/usr/bin/env bash
set -euo pipefail

enable_service() {
  local svc=$1
  if systemctl list-unit-files | grep -q "^${svc}"; then
    echo ">>> Enabling $svc"
    sudo systemctl enable "$svc"
    sudo systemctl start "$svc"
  else
    echo ">>> Service $svc not found, skipping"
  fi
}

services=(sddm.service hyprland.service pipewire.service wireplumber.service swww.service qemu-guest-agent.service upower.service NetworkManager.service bluetooth.service)
for svc in "${services[@]}"; do
  enable_service "$svc"
done

read -rp "Do you want to setup sddm theme? [yes/no] : " choice
if [[ "$choice" == "yes" ]]; then
  echo ">>> Setting up SDDM Astronaut theme..."
  echo -e "1\n5" | sh -c "$(curl -fsSL https://raw.githubusercontent.com/keyitdev/sddm-astronaut-theme/master/setup.sh)"
else
  echo ">>> Skipping SDDM theme setup"
fi
