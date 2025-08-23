#!/usr/bin/env bash
set -euo pipefail

# Arch Linux one-shot Secure Boot setup (shim + GRUB + sbctl).
# Robust: safe to re-run, detects if already enabled.

# ---------------- Safety ----------------
if [[ $EUID -ne 0 ]]; then
  SCRIPT_PATH="$(realpath "$0")"
  exec sudo bash "$SCRIPT_PATH" "$@"
fi
[[ -f /etc/arch-release ]] || {
  echo "This is for Arch Linux only."
  exit 1
}

# ---------------- Packages ----------------
pacman -Sy --needed --noconfirm grub efibootmgr os-prober sbctl shim-signed git

# ---------------- Check if Secure Boot already configured ----------------
if sbctl status | grep -q "Secure Boot enabled: true"; then
  echo "=============================================================="
  echo "✅ Secure Boot already enabled and configured on this system."
  echo "Nothing to do for signing."
  echo "=============================================================="
else
  echo "=============================================================="
  echo "⚙️  Configuring Secure Boot with shim + sbctl..."
  echo "=============================================================="

  # Ensure ESP is mounted
  ESP="$(bootctl --print-esp-path || true)"
  [[ -z "$ESP" ]] && ESP="/boot/efi"
  [[ -d "$ESP" ]] || {
    echo "ERROR: ESP not mounted at /boot/efi"
    exit 1
  }
  echo "ESP: $ESP"

  # Initialize keys if missing
  if [[ ! -d /etc/secureboot/keys ]]; then
    echo "Generating Secure Boot keys with sbctl..."
    sbctl create-keys
  fi

  # Install GRUB to EFI with shim
  grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB

  # Copy shim + MokManager
  SHIM_DIR="/usr/share/shim-signed"
  mkdir -p "$ESP/EFI/GRUB"
  cp -f "$SHIM_DIR/shimx64.efi" "$ESP/EFI/GRUB/shimx64.efi"
  cp -f "$SHIM_DIR/MokManager.efi" "$ESP/EFI/GRUB/MokManager.efi"

  # Make sure fallback boot path exists
  mkdir -p "$ESP/EFI/Boot"
  cp -f "$ESP/EFI/GRUB/shimx64.efi" "$ESP/EFI/Boot/bootx64.efi"

  # Sign all EFI + kernel files
  echo "Signing EFI + kernel binaries..."
  sbctl sign -s "$ESP/EFI/GRUB/grubx64.efi" || true
  sbctl sign -s "$ESP/EFI/Boot/bootx64.efi" || true
  for f in /boot/vmlinuz-*; do
    [[ -f "$f" ]] && sbctl sign -s "$f"
  done

  # Generate GRUB config (detect Windows too)
  sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub || true
  grub-mkconfig -o /boot/grub/grub.cfg

  echo "=============================================================="
  echo "🎉 Secure Boot setup complete."
  echo "Reboot with Secure Boot enabled in firmware."
  echo "=============================================================="
fi

# ---------------- Theme Option ----------------
echo
read -rp "Do you want to install the Minegrub World Selector GRUB theme? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  echo "Installing Minegrub GRUB theme..."
  THEME_DIR="/boot/grub/themes/minegrub"
  rm -rf "$THEME_DIR"
  git clone --depth=1 https://github.com/Lxtharia/minegrub-world-sel-theme "$THEME_DIR"
  if grep -q "^GRUB_THEME=" /etc/default/grub; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DIR/theme.txt\"|" /etc/default/grub
  else
    echo "GRUB_THEME=\"$THEME_DIR/theme.txt\"" >>/etc/default/grub
  fi
  grub-mkconfig -o /boot/grub/grub.cfg
  echo "✅ Minegrub theme installed successfully!"
else
  echo "Skipped GRUB theme installation."
fi
