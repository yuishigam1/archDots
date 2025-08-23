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
pacman -Sy --needed --noconfirm grub efibootmgr os-prober sbsigntools shim-signed sbctl git

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
  local mp
  mp="$(lsblk -o MOUNTPOINT,FSTYPE,PARTFLAGS -nr | awk '$2 ~ /vfat/ && $3 ~ /esp|boot/ {print $1}' | head -n1)"
  [[ -n "${mp:-}" ]] && {
    echo "$mp"
    return
  }
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

# ---------------- Install GRUB + shim ----------------
grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB --recheck --boot-directory="$ESP/boot"
mkdir -p "$ESP/EFI/GRUB"
cp -f /usr/share/shim-signed/shimx64.efi "$ESP/EFI/GRUB/"
cp -f /usr/share/shim-signed/MokManager.efi "$ESP/EFI/GRUB/"
cp -f "$ESP/EFI/GRUB/shimx64.efi" "$ESP/EFI/BOOT/BOOTX64.EFI"

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

# ---------------- Sign EFI binaries ----------------
echo "Signing EFI binaries..."
sbctl sign -s "$ESP/EFI/GRUB/shimx64.efi"
sbctl sign -s "$ESP/EFI/GRUB/grubx64.efi"
for f in "$ESP/grub/x86_64-efi/"*.efi; do
  [[ -f "$f" ]] && sbctl sign -s "$f"
done

# ---------------- Sign kernels ----------------
for k in /boot/vmlinuz-*; do sbctl sign -s "$k"; done
for i in /boot/initramfs-*.img /boot/initramfs-*.img.old; do [[ -f "$i" ]] && sbctl sign -s "$i"; done

# ---------------- Pacman hooks ----------------
HOOK_DIR="/etc/pacman.d/hooks"
mkdir -p "$HOOK_DIR"
cat >"$HOOK_DIR/95-secureboot-resign.hook" <<'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Type=Path
Target=boot/vmlinuz-*
Target=boot/initramfs-*.img
Target=efi/EFI/GRUB/*.efi

[Action]
Description=Secure Boot: sign EFI/kernel (MOK)
When=PostTransaction
Exec=/usr/bin/sbctl sign-all
EOF

echo "=============================================================="
echo "✅ GRUB + Secure Boot setup complete!"
echo "Reboot with Secure Boot ON and shim should load Arch + Windows."
echo "MOK keys already enrolled with sbctl. No Setup Mode required."
echo "=============================================================="
