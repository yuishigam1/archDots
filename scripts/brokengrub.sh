#!/usr/bin/env bash
set -euo pipefail

# -------------------- SETUP MODE CHECK --------------------
if ! sbctl status | grep -q "Setup Mode:	✗ Enabled"; then
  echo -e "\e[31m[ERROR]\e[0m You must be in Setup Mode to run this script."
  echo "Please enter BIOS setup, enable Setup Mode, and try again."
else
  # -------------------- ROOT & ARCH CHECK --------------------
  [[ $EUID -eq 0 ]] || exec sudo bash "$0" "$@"
  [[ -f /etc/arch-release ]] || {
    echo "This script is for Arch Linux only."
    exit 1
  }

  # -------------------- DEPENDENCIES --------------------
  pacman -Sy --needed --noconfirm grub efibootmgr os-prober sbsigntools shim sbctl git

  # -------------------- LOGGING --------------------
  log() { echo -e "\e[34m[INFO]\e[0m $1"; }
  warn() { echo -e "\e[33m[WARN]\e[0m $1"; }
  error() { echo -e "\e[31m[ERROR]\e[0m $1"; }

  # -------------------- DETECT EFI --------------------
  detect_esp() {
    for dir in /boot /boot/efi; do
      mountpoint -q "$dir" || continue
      [[ "$(findmnt -no FSTYPE "$dir")" == "vfat" ]] && echo "$dir" && return
    done
    error "EFI partition not found. Mount a FAT32 ESP to /boot or /boot/efi."
    exit 1
  }
  ESP="$(detect_esp)"
  log "EFI directory detected: $ESP"

  # -------------------- CLEAN PREVIOUS GRUB --------------------
  log "Removing previous GRUB installation..."
  rm -rf "${ESP}/EFI/GRUB" /boot/grub

  # -------------------- REMOVE DUPLICATE GRUB ENTRIES --------------------
  log "Cleaning old GRUB NVRAM entries..."
  for entry in $(efibootmgr | grep -i 'GRUB' | awk '{print $1}' | sed 's/Boot//;s/\*//'); do
    # Keep shim only
    desc=$(efibootmgr -v | grep -A1 "Boot${entry}" | tail -n1)
    if [[ "$desc" != *shimx64.efi* ]]; then
      log "Deleting old plain GRUB entry: $entry"
      efibootmgr -b "$entry" -B || warn "Could not delete $entry"
    fi
  done

  # -------------------- SECURE BOOT KEYS --------------------
  log "Ensuring sbctl keys exist..."
  mkdir -p /etc/secureboot/keys
  if ! sbctl status &>/dev/null; then
    sbctl create-keys --yes
  fi

  # -------------------- GRUB INSTALL --------------------
  log "Installing GRUB..."
  grub-install --target=x86_64-efi --efi-directory="$ESP" --bootloader-id=GRUB --recheck

  # -------------------- SHIM --------------------
  log "Copying shim..."
  mkdir -p "$ESP/EFI/GRUB"
  cp -f /usr/share/shim/shimx64.efi "$ESP/EFI/GRUB/"
  cp -f /usr/share/shim/mmx64.efi "$ESP/EFI/GRUB/"

  # -------------------- OPTIONAL GRUB THEME --------------------
  read -rp "Do you want to install the GRUB theme? (y/n): " INSTALL_THEME
  if [[ "$INSTALL_THEME" =~ ^[Yy]$ ]]; then
    THEME_REPO="https://github.com/Lxtharia/minegrub-world-sel-theme.git"
    THEME_DIR="$ESP/grub/themes/minegrub-world-selection"
    THEME_FILE="theme.txt"
    log "Cloning and applying theme..."
    rm -rf /tmp/minegrub-theme
    git clone "$THEME_REPO" /tmp/minegrub-theme
    mkdir -p "$(dirname "$THEME_DIR")"
    cp -ru /tmp/minegrub-theme/minegrub-world-selection "$THEME_DIR"
    rm -rf /tmp/minegrub-theme
    sed -i "/^GRUB_THEME=/d" /etc/default/grub
    echo "GRUB_THEME=\"$THEME_DIR/$THEME_FILE\"" >>/etc/default/grub
  fi

  # -------------------- GRUB CONFIG --------------------
  log "Generating GRUB config..."
  [[ -f /etc/default/grub ]] || cat >/etc/default/grub <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR="Arch"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 nowatchdog"
GRUB_CMDLINE_LINUX=""
GRUB_DISABLE_OS_PROBER=false
EOF

  GRUB_CFG="$ESP/grub/grub.cfg"
  mkdir -p "$(dirname "$GRUB_CFG")"
  grub-mkconfig -o "$GRUB_CFG"

  # -------------------- SIGN BINARIES --------------------
  log "Signing EFI binaries and kernels..."
  TO_SIGN=()

  # EFI binaries
  while IFS= read -r f; do TO_SIGN+=("$f"); done < <(find "$ESP" -type f -name '*.efi')

  # Kernel images
  while IFS= read -r f; do TO_SIGN+=("$f"); done < <(find /boot -maxdepth 1 -type f -name 'vmlinuz-*')

  # Sign all EFI + kernels with sbctl
  for f in "${TO_SIGN[@]}"; do
    log "Signing $f"
    sbctl sign "$f"
  done

  # Verify
  for f in "${TO_SIGN[@]}"; do
    sbctl verify "$f" || error "$f failed signing!"
  done

  # -------------------- PACMAN HOOK --------------------
  HOOK_DIR="/etc/pacman.d/hooks"
  mkdir -p "$HOOK_DIR"
  HOOK_FILE="$HOOK_DIR/95-secureboot-resign.hook"

  log "Creating pacman hook for auto-signing..."
  TARGETS=$(printf "%s\nTarget=" "${TO_SIGN[@]}" | sed '$s/Target=//')
  cat >"$HOOK_FILE" <<EOF
[Trigger]
Operation=Install
Operation=Upgrade
Type=Path
Target=$TARGETS
[Action]
Description=Secure Boot: sign EFI/kernel
When=PostTransaction
Exec=/usr/bin/sbctl sign-all --esp "$ESP"
EOF

  # -------------------- CREATE SHIM BOOT ENTRY --------------------
  log "Creating boot entry for shim..."
  BOOT_EXIST=$(efibootmgr | grep -i 'GRUB (shim)' || true)
  if [[ -z "$BOOT_EXIST" ]]; then
    ESP_DEV=$(findmnt -no SOURCE "$ESP")
    DISK=$(lsblk -no PKNAME "$ESP_DEV" | head -n1)
    PART=$(lsblk -no NAME "$ESP_DEV" | sed 's/.*p//') # NVMe & SATA safe
    efibootmgr -c -d "/dev/$DISK" -p "$PART" -L "GRUB (shim)" -l '\EFI\GRUB\shimx64.efi'
  else
    log "Shim boot entry already exists."
  fi

  # -------------------- FALLBACK BOOT --------------------
  log "Creating fallback boot copies..."
  mkdir -p "$ESP/EFI/Boot"
  cp -f "$ESP/EFI/GRUB/shimx64.efi" "$ESP/EFI/Boot/BOOTX64.EFI"
  cp -f "$ESP/EFI/GRUB/grubx64.efi" "$ESP/EFI/Boot/grubx64.efi"

  # -------------------- FINAL MESSAGE --------------------
  log "=============================================================="
  log "✅ GRUB + Secure Boot setup complete!"
  log "You can now turn Secure Boot ON. Enroll your PK when prompted."
  log "Pacman hook and auto-signing are configured."
  log "=============================================================="
fi
