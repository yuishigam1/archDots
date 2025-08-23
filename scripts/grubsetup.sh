#!/usr/bin/env bash
set -euo pipefail

# -------------------------------------------------
# Arch Linux one-shot Secure Boot + GRUB + Theme
# -------------------------------------------------

# ---- Root check ----
if [[ $EUID -ne 0 ]]; then
  SCRIPT_PATH="$(realpath "$0")"
  exec sudo bash "$SCRIPT_PATH" "$@"
fi
[[ -f /etc/arch-release ]] || {
  echo "This is for Arch Linux only."
  exit 1
}

# ---- Packages ----
pacman -Sy --needed --noconfirm grub efibootmgr os-prober sbctl git

# ---- Detect ESP ----
detect_esp() {
  if findmnt -no FSTYPE /boot/efi 2>/dev/null | grep -qi vfat; then
    echo /boot/efi
    return
  fi
  if findmnt -no FSTYPE /boot 2>/dev/null | grep -qi vfat; then
    echo /boot
    return
  fi
  echo "ERROR: ESP not mounted. Mount it at /boot or /boot/efi and rerun." >&2
  exit 1
}
ESP="$(detect_esp)"
echo "ESP: $ESP"

# ---- GRUB config ----
mkdir -p /etc/default
if [[ -f /etc/default/grub ]]; then
  sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub || true
else
  cat >/etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 nowatchdog"
GRUB_CMDLINE_LINUX=""
GRUB_DISABLE_OS_PROBER=false
EOF
fi

# ---- Install GRUB if missing ----
if [[ ! -f "$ESP/EFI/GRUB/grubx64.efi" ]]; then
  echo "Installing GRUB to EFI..."
  grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB
fi
grub-mkconfig -o /boot/grub/grub.cfg

# ---- Secure Boot keys ----
if ! sbctl status | grep -q "Setup Mode"; then
  echo "sbctl already initialized, skipping key generation."
else
  echo "Initializing sbctl Secure Boot keys..."
  sbctl create-keys
  sbctl enroll-keys -m # requires BIOS Secure Boot enabled but not in Setup Mode
fi

# ---- Signing ----
echo "Signing boot binaries..."
sbctl sign -s /boot/vmlinuz-linux || true
sbctl sign -s "$ESP/EFI/GRUB/grubx64.efi" || true
shopt -s nullglob
for img in /boot/initramfs-*.img; do sbctl sign -s "$img" || true; done
shopt -u nullglob

# ---- Verify ----
echo "Verification status:"
sbctl verify || true

# ---- Theme Option ----
read -rp "Do you want to install the Minegrub World Selector GRUB theme? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  THEME_DIR="/boot/grub/themes/minegrub"
  rm -rf "$THEME_DIR"
  git clone --depth=1 https://github.com/Lxtharia/minegrub-world-sel-theme "$THEME_DIR"
  if grep -q "^GRUB_THEME=" /etc/default/grub; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DIR/theme.txt\"|" /etc/default/grub
  else
    echo "GRUB_THEME=\"$THEME_DIR/theme.txt\"" >>/etc/default/grub
  fi
  grub-mkconfig -o /boot/grub/grub.cfg
  echo "Minegrub theme installed successfully!"
else
  echo "Skipped GRUB theme installation."
fi

echo "=============================================================="
echo "Secure Boot setup complete."
echo "If Secure Boot is enabled in BIOS, you should boot normally now."
echo "GRUB + kernels are signed, pacman hooks are managed by sbctl."
echo "=============================================================="
