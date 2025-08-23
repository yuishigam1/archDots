#!/usr/bin/env bash
set -euo pipefail

echo "=============================================================="
echo "⚙️  Configuring Secure Boot with shim + sbctl..."
echo "=============================================================="

# ------------------------------------------------
# Root check
# ------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo "This script needs root privileges. Run with sudo."
  exit 1
fi

# ------------------------------------------------
# Install required packages
# ------------------------------------------------
echo "📦 Installing required packages..."
pacman -Syu --needed --noconfirm grub efibootmgr os-prober sbctl shim-signed git

# ------------------------------------------------
# Generate Secure Boot keys
# ------------------------------------------------
echo "🔑 Generating Secure Boot keys..."
if ! sbctl status | grep -q "Owner UUID"; then
  sbctl create-keys
else
  echo "✓ Secure boot keys have already been created!"
fi

# ------------------------------------------------
# Install GRUB
# ------------------------------------------------
echo "📦 Installing GRUB to EFI..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# ------------------------------------------------
# Run os-prober + update grub.cfg
# ------------------------------------------------
echo "🔎 Running os-prober..."
os-prober || true
grub-mkconfig -o /boot/grub/grub.cfg

# ------------------------------------------------
# Install GRUB theme (optional)
# ------------------------------------------------
THEME_DIR="/boot/grub/themes/minegrub-world-selection"
if [[ -d "$THEME_DIR" ]]; then
  echo "🎨 Applying GRUB theme..."
  sed -i 's|^#\?GRUB_THEME=.*|GRUB_THEME="'"$THEME_DIR/theme.txt"'"|' /etc/default/grub
  grub-mkconfig -o /boot/grub/grub.cfg
else
  echo "⚠️ Theme not found at $THEME_DIR, skipping..."
fi

# ------------------------------------------------
# Detect EFI directory dynamically
# ------------------------------------------------
echo "🔍 Detecting EFI mount point..."
EFI_DIR=$(findmnt -n -o TARGET /boot/efi 2>/dev/null || true)
if [[ -z "$EFI_DIR" || ! -d "$EFI_DIR/EFI" ]]; then
  # fallback: look under /boot and /efi
  for d in /boot /efi; do
    if [[ -d "$d/EFI" ]]; then
      EFI_DIR="$d"
      break
    fi
  done
fi

if [[ -z "$EFI_DIR" || ! -d "$EFI_DIR/EFI" ]]; then
  echo "❌ Could not detect EFI directory. Exiting."
  exit 1
fi
echo "📂 Using EFI directory: $EFI_DIR"

# ------------------------------------------------
# Sign binaries
# ------------------------------------------------
echo "🔏 Signing EFI binaries..."

# Always sign kernel
sbctl sign -s /boot/vmlinuz-linux || echo "⚠️ Failed signing kernel"

# Sign GRUB + shim if present
GRUB_EFI_DIR=$(find "$EFI_DIR/EFI" -type d \( -iname "grub*" -o -iname "arch*" \) | head -n1)

if [[ -n "$GRUB_EFI_DIR" ]]; then
  echo "📂 Found GRUB EFI directory at: $GRUB_EFI_DIR"
  [[ -f "$GRUB_EFI_DIR/grubx64.efi" ]] && sbctl sign -s "$GRUB_EFI_DIR/grubx64.efi" || echo "⚠️ grubx64.efi missing"
  [[ -f "$GRUB_EFI_DIR/shimx64.efi" ]] && sbctl sign -s "$GRUB_EFI_DIR/shimx64.efi" || echo "⚠️ shimx64.efi missing"
else
  echo "❌ Could not find GRUB EFI directory under $EFI_DIR/EFI/"
fi

echo "=============================================================="
echo "✅ GRUB setup & Secure Boot configuration complete!"
echo "=============================================================="
