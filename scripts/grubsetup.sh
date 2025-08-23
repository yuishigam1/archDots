#!/usr/bin/env bash
set -euo pipefail

echo "=============================================================="
echo "⚙️  Configuring Secure Boot with shim + sbctl..."
echo "=============================================================="

# Ensure we are root
if [[ $EUID -ne 0 ]]; then
  echo "This script needs root privileges. Run with sudo."
  exit 1
fi

# Variables
ESP="/boot"
SHIM_DIR="/usr/share/shim-signed"
THEME_DIR="/boot/grub/themes/minegrub"

# Install required packages
pacman -Syu --needed --noconfirm grub efibootmgr os-prober sbctl shim-signed git

# Check if keys already exist
if sbctl status | grep -q "Installed:.*✔"; then
  echo "✓ Secure Boot already set up and keys enrolled."
else
  echo "🔑 Generating Secure Boot keys..."
  sbctl create-keys
fi

# Install GRUB
echo "📦 Installing GRUB to EFI..."
grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB --modules="tpm" --recheck

# Handle shim + MokManager (Arch style)
mkdir -p "$ESP/EFI/GRUB"
cp -f "$SHIM_DIR/shimx64.efi" "$ESP/EFI/GRUB/shimx64.efi"
cp -f "$SHIM_DIR/mmx64.efi" "$ESP/EFI/GRUB/MokManager.efi"

# Detect other OS (like Windows)
echo "🔎 Running os-prober..."
os-prober || true
grub-mkconfig -o /boot/grub/grub.cfg

# Sign all EFI binaries
echo "🔏 Signing EFI binaries..."
sbctl sign -s /boot/vmlinuz-linux || true
sbctl sign -s /boot/efi/EFI/GRUB/shimx64.efi || true
sbctl sign -s /boot/efi/EFI/GRUB/grubx64.efi || true
sbctl sign-all

# Pacman hook for auto-signing
HOOK_PATH="/etc/pacman.d/hooks/99-secureboot-sign.hook"
mkdir -p "$(dirname "$HOOK_PATH")"
cat >"$HOOK_PATH" <<'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Type=Path
Target=boot/vmlinuz*

[Action]
Description=Sign kernel for Secure Boot
When=PostTransaction
Exec=/usr/bin/sbctl sign -s /boot/vmlinuz-linux
EOF

echo "✓ Added pacman hook for kernel auto-signing."

# Ask about theme
read -rp "🎨 Do you want to install the Minegrub GRUB theme? (y/N): " theme_choice
if [[ "$theme_choice" =~ ^[Yy]$ ]]; then
  echo "📥 Installing Minegrub theme..."
  git clone --depth=1 https://github.com/Lxtharia/minegrub-world-sel-theme "$THEME_DIR"
  echo 'GRUB_THEME="/boot/grub/themes/minegrub/theme.txt"' >>/etc/default/grub
  grub-mkconfig -o /boot/grub/grub.cfg
  echo "✓ Minegrub theme installed."
fi

echo "=============================================================="
echo "✅ Secure Boot + GRUB setup complete!"
echo "=============================================================="
echo "Reboot with Secure Boot ON. If prompted, enroll the MOK key."
