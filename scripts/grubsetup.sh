#!/usr/bin/env bash
set -euo pipefail

# ---------------- Safety ----------------
if [[ $EUID -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi
[[ -f /etc/arch-release ]] || {
  echo "This script is for Arch Linux."
  exit 1
}

# ---------------- Packages ----------------
pacman -Sy --needed --noconfirm grub efibootmgr os-prober sbsigntools shim sbctl git

# ---------------- Detect EFI ----------------
detect_esp() {
  if findmnt -no FSTYPE /boot 2>/dev/null | grep -qi vfat; then
    echo /boot
    return
  fi
  if findmnt -no FSTYPE /boot/efi 2>/dev/null | grep -qi vfat; then
    echo /boot/efi
    return
  fi
  echo "ERROR: EFI partition not mounted at /boot or /boot/efi" >&2
  exit 1
}
ESP="$(detect_esp)"
echo "EFI directory: $ESP"

# ---------------- Secure Boot keys ----------------
SB_DIR="/etc/secureboot"
mkdir -p "$SB_DIR/keys"
if ! sbctl status &>/dev/null; then
  sbctl create-keys --yes
fi

# ---------------- Install GRUB ----------------
grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB --recheck --boot-directory="$ESP/boot"

# ---------------- GRUB config ----------------
[[ -f /etc/default/grub ]] || cat >/etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 nowatchdog"
GRUB_CMDLINE_LINUX=""
GRUB_DISABLE_OS_PROBER=false
EOF

grub-mkconfig -o "$ESP/grub/grub.cfg"

# ---------------- Sign all EFI + kernels ----------------
echo "Signing EFI binaries + kernel/initramfs..."
sbctl sign-all

# ---------------- Pacman hook for auto-sign ----------------
HOOK_DIR="/etc/pacman.d/hooks"
mkdir -p "$HOOK_DIR"
cat >"$HOOK_DIR/95-secureboot-resign.hook" <<EOF
[Trigger]
Operation=Install
Operation=Upgrade
Type=Path
Target=boot/vmlinuz-*
Target=boot/initramfs-*.img
Target=EFI/GRUB/*.efi

[Action]
Description=Secure Boot: sign EFI/kernel (MOK)
When=PostTransaction
Exec=/usr/bin/sbctl sign-all --esp "$ESP"
EOF

# ---------------- Optional fallback ----------------
mkdir -p "$ESP/EFI/Boot"
cp -f "$ESP/EFI/GRUB/shimx64.efi" "$ESP/EFI/Boot/bootx64.efi"
cp -f "$ESP/EFI/GRUB/grubx64.efi" "$ESP/EFI/Boot/grubx64.efi"

echo "=============================================================="
echo "✅ GRUB + Secure Boot setup complete!"
echo "Reboot with Secure Boot ON and shim should load Arch + Windows."
echo "Keys are already managed by sbctl. No Setup Mode required."
echo "=============================================================="
