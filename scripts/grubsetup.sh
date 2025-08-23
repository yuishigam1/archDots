#!/usr/bin/env bash
set -euo pipefail

# Arch Linux one-shot Secure Boot (shim + GRUB + MOK), no Setup Mode needed.

# ---------------- Safety ----------------
if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi
[[ -f /etc/arch-release ]] || {
  echo "This is for Arch Linux."
  exit 1
}

# ---------------- Packages ----------------
pacman -Sy --needed --noconfirm grub efibootmgr os-prober sbsigntools shim-signed mokutil

# ---------------- ESP detect ----------------
detect_esp() {
  if findmnt -no FSTYPE /boot/efi 2>/dev/null | grep -qi vfat; then
    echo /boot/efi
    return
  fi
  if findmnt -no FSTYPE /boot 2>/dev/null | grep -qi vfat; then
    echo /boot
    return
  fi
  local mp
  mp="$(lsblk -o MOUNTPOINT,FSTYPE,PARTFLAGS -nr | awk '$2 ~ /vfat/ && $3 ~ /esp|boot/ {print $1}' | head -n1)"
  [[ -n "${mp:-}" ]] && {
    echo "$mp"
    return
  }
  echo "ERROR: ESP not mounted. Mount it at /boot or /boot/efi and rerun." >&2
  exit 1
}
ESP="$(detect_esp)"
echo "ESP: $ESP"

# ---------------- GRUB config ----------------
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

# ---------------- Install GRUB (UEFI) ----------------
grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB

# ---------------- Put shim + MokManager ----------------
SHIM_DIR="/usr/share/shim-signed"
[[ -f "$SHIM_DIR/shimx64.efi" && -f "$SHIM_DIR/MokManager.efi" ]] ||
  {
    echo "shim files missing in $SHIM_DIR"
    exit 1
  }

mkdir -p "$ESP/EFI/GRUB"
cp -f "$SHIM_DIR/shimx64.efi" "$ESP/EFI/GRUB/shimx64.efi"
cp -f "$SHIM_DIR/MokManager.efi" "$ESP/EFI/GRUB/MokManager.efi"

# Ensure GRUB binary is where shim expects it
GRUB_EFI="$ESP/EFI/GRUB/grubx64.efi"
if [[ ! -f "$GRUB_EFI" ]]; then
  # try to find the installed GRUB .efi and normalize
  found=$(find "$ESP/EFI/GRUB" -maxdepth 1 -iname 'grubx64.efi' -o -iname 'grub.efi' | head -n1 || true)
  if [[ -n "${found:-}" ]]; then cp -f "$found" "$GRUB_EFI"; else
    echo "Could not locate GRUB EFI under $ESP/EFI/GRUB"
    exit 1
  fi
fi

# ---------------- MOK keys ----------------
SB_DIR="/etc/secureboot"
KEY_DIR="$SB_DIR/keys"
mkdir -p "$KEY_DIR"
MOK_KEY="$KEY_DIR/MOK.key"
MOK_CRT="$KEY_DIR/MOK.crt"
MOK_CER="$KEY_DIR/MOK.cer"

if [[ ! -f "$MOK_KEY" || ! -f "$MOK_CRT" ]]; then
  echo "Generating MOK keypair..."
  openssl req -new -x509 -newkey rsa:2048 -sha256 -days 3650 \
    -subj "/CN=Arch Linux MOK/" -keyout "$MOK_KEY" -out "$MOK_CRT" -nodes
  openssl x509 -in "$MOK_CRT" -outform DER -out "$MOK_CER"
fi
chmod 600 "$MOK_KEY"

# ---------------- Helper to sign PE/EFI ----------------
sign_file() {
  local in="$1"
  local out="${1}.signed"
  sbsign --key "$MOK_KEY" --cert "$MOK_CRT" --output "$out" "$in"
  mv -f "$out" "$in"
}

# ---------------- Sign GRUB EFI ----------------
echo "Signing GRUB EFI: $GRUB_EFI"
sign_file "$GRUB_EFI"

# ---------------- GRUB config with Windows ----------------
command -v os-prober >/dev/null || pacman -S --noconfirm os-prober
grub-mkconfig -o /boot/grub/grub.cfg

# ---------------- Sign kernels + initramfs ----------------
sign_kernels() {
  shopt -s nullglob
  for k in /boot/vmlinuz-*; do
    echo "Signing kernel: $k"
    sign_file "$k"
  done
  for i in /boot/initramfs-*.img /boot/initramfs-*.img.old; do [[ -f "$i" ]] && {
    echo "Signing initramfs: $i"
    sign_file "$i"
  }; done
  shopt -u nullglob
}
sign_kernels

# ---------------- Pacman hooks ----------------
HOOK_DIR="/etc/pacman.d/hooks"
mkdir -p "$HOOK_DIR"
cat >"$HOOK_DIR/95-secureboot-resign-kernel.hook" <<'EOF'
[Trigger]
Operation=Install
Operation=Upgrade
Type=Path
Target=boot/vmlinuz-*
Target=boot/initramfs-*.img

[Action]
Description=Secure Boot: sign kernel/initramfs (MOK)
When=PostTransaction
Exec=/usr/bin/bash -c 'KEY="/etc/secureboot/keys/MOK.key"; CRT="/etc/secureboot/keys/MOK.crt"; for f in /boot/vmlinuz-* /boot/initramfs-*.img; do [[ -f "$f" ]] && /usr/bin/sbsign --key "$KEY" --cert "$CRT" --output "$f.signed" "$f" && /usr/bin/mv -f "$f.signed" "$f"; done'
EOF

cat >"$HOOK_DIR/96-secureboot-resign-grub.hook" <<'EOF'
[Trigger]
Operation=Upgrade
Type=Path
Target=efi/EFI/GRUB/grubx64.efi
Target=boot/efi/EFI/GRUB/grubx64.efi

[Action]
Description=Secure Boot: sign GRUB EFI (MOK)
When=PostTransaction
Exec=/usr/bin/bash -c 'KEY="/etc/secureboot/keys/MOK.key"; CRT="/etc/secureboot/keys/MOK.crt"; for e in /boot/efi/EFI/GRUB/grubx64.efi /efi/EFI/GRUB/grubx64.efi; do [[ -f "$e" ]] && /usr/bin/sbsign --key "$KEY" --cert "$CRT" --output "$e.signed" "$e" && /usr/bin/mv -f "$e.signed" "$e"; done'
EOF

# ---------------- NVRAM entry + BootOrder ----------------
esp_src="$(findmnt -no SOURCE "$ESP")"
disk_dev="$(lsblk -no PKNAME "$esp_src" | head -n1)"
disk="/dev/${disk_dev}"
partnum="$(lsblk -no PARTNUM "$esp_src")"
EFIPATH="\\EFI\\GRUB\\shimx64.efi"

efibootmgr -c -d "$disk" -p "$partnum" -L "GRUB (shim)" -l "$EFIPATH" || true
current_order="$(efibootmgr | awk '/BootOrder/ {print $2}')"
shim_bootnum="$(efibootmgr | awk '/GRUB \(shim\)/ {print substr($1,5,4)}' | head -n1)"
if [[ -n "${shim_bootnum:-}" && -n "${current_order:-}" ]]; then
  new_order="$shim_bootnum"
  IFS=',' read -r -a arr <<<"$current_order"
  for x in "${arr[@]}"; do [[ "$x" == "$shim_bootnum" ]] || new_order+=",$x"; done
  efibootmgr -o "$new_order" || true
fi

# ---------------- Fallback path (for stubborn firmware) ----------------
mkdir -p "$ESP/EFI/Boot"
cp -f "$ESP/EFI/GRUB/shimx64.efi" "$ESP/EFI/Boot/bootx64.efi"
# second stage for fallback must be grubx64.efi in same dir
cp -f "$ESP/EFI/GRUB/grubx64.efi" "$ESP/EFI/Boot/grubx64.efi"

# ---------------- MOK import (works with SB not in Setup Mode) ----------------
PASS="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 14 || true)"
echo "=============================================================="
echo "MOK enrollment password (save it): $PASS"
echo "It will be required ONCE in MokManager at next boot."
echo "=============================================================="

# Pre-schedule MOK enrollment non-interactively:
# mokutil asks twice; feed automatically.
{
  echo "$PASS"
  echo "$PASS"
} | mokutil --import "$MOK_CER"

# ---------------- Done ----------------
echo
echo "=============================================================="
echo "Secure Boot setup complete."
echo "Next:"
echo " 1) Reboot with Secure Boot ON."
echo " 2) At blue MokManager screen: Enroll MOK -> Continue -> Yes -> enter password above."
echo " 3) GRUB menu should show Windows + Arch. Boot normally."
echo
echo "Keys: $KEY_DIR  (keep MOK.key private!)"
echo "Fallback path created: $ESP/EFI/Boot/bootx64.efi"
echo "Pacman hooks installed: will auto-sign on updates."
echo "=============================================================="

# ---------------- Theme Option ----------------
echo
read -rp "Do you want to install the Minegrub World Selector GRUB theme? (y/N): " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  echo "Installing Minegrub GRUB theme..."
  pacman -Sy --needed --noconfirm git
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
