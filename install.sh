#!/bin/bash
set -Eeuo pipefail

### -------------------- LOGGING --------------------
LOG_FILE="/tmp/install_log.txt"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Arch + KDE Zero-Click Provisioning ==="

### -------------------- ROOT CHECK --------------------
[[ $EUID -eq 0 ]] || { echo "Run with sudo"; exit 1; }

### -------------------- USER DETECTION --------------------
USER_NAME="${SUDO_USER:-$(logname 2>/dev/null || true)}"
[[ -n "$USER_NAME" ]] && id "$USER_NAME" &>/dev/null || {
    echo "Could not detect user"
    exit 1
}

HOME_DIR="$(eval echo "~$USER_NAME")"
HOSTNAME="$(hostname)"

echo "User: $USER_NAME"
echo "Host: $HOSTNAME"

### -------------------- DOTFILES AUTO-DETECT --------------------
for d in "$HOME_DIR/Dotfiles" "$HOME_DIR/dotfiles" "$HOME_DIR/.dotfiles"; do
    [[ -d "$d" ]] && DOTFILES_DIR="$d" && break
done

[[ -n "${DOTFILES_DIR:-}" ]] || { echo "Dotfiles directory not found"; exit 1; }

CONFIG_SRC="$DOTFILES_DIR/configs"
PLASMA_CFG="$CONFIG_SRC/plasma"
TMPDIR="$DOTFILES_DIR/temp"

mkdir -p "$TMPDIR"
chown -R "$USER_NAME:$USER_NAME" "$TMPDIR"

echo "Dotfiles: $DOTFILES_DIR"

### -------------------- NETWORK CHECK --------------------
curl -s https://archlinux.org >/dev/null || { echo "No network connection"; exit 1; }

### -------------------- BASE TOOLS --------------------
pacman -Syu --noconfirm git curl wget unzip base-devel

### -------------------- PACKAGES --------------------
OFFICIAL_PACKAGES=(
    git zsh alacritty steam btop cpupower
    easyeffects qbittorrent kdenlive krita
    cameractrls lm_sensors elisa
)

AUR_PACKAGES=(
    zed proton-vpn-gtk-app gpu-screen-recorder
    zsh-syntax-highlighting discord-ptb
    floorp-bin librewolf-bin localsend-bin
    protonplus proton-pass-bin proton-mail-bin
    ungoogled-chromium-bin tidal-hifi-bin
    adwsteamgtk coolercontrol-bin stremio
    chatterino2-bin pano-scrobbler-bin kew
)

pacman -S --noconfirm "${OFFICIAL_PACKAGES[@]}"

### -------------------- PARU (AUR HELPER) --------------------
if ! command -v paru &>/dev/null; then
    sudo -u "$USER_NAME" git clone https://aur.archlinux.org/paru.git "$TMPDIR/paru"
    sudo -u "$USER_NAME" bash -c "cd $TMPDIR/paru && makepkg -si --noconfirm"
fi

sudo -u "$USER_NAME" paru -S --noconfirm "${AUR_PACKAGES[@]}"

### -------------------- FONTS --------------------
git clone https://github.com/paper-design/paper-mono.git "$TMPDIR/paper-mono"
mkdir -p /usr/share/fonts/TTF
cp "$TMPDIR/paper-mono/fonts/ttf/"*.ttf /usr/share/fonts/TTF/
fc-cache -fv
rm -rf "$TMPDIR/paper-mono"

### -------------------- KDE THEME --------------------
sudo -u "$USER_NAME" git clone https://gitlab.com/pwyde/monochrome-kde.git "$TMPDIR/mono"
sudo -u "$USER_NAME" bash -c "cd $TMPDIR/mono && ./install.sh --install"
rm -rf "$TMPDIR/mono"

### -------------------- ICONS & CURSOR --------------------
mkdir -p "$HOME_DIR/.local/share/icons"
TMP_ICONS="$TMPDIR/icons_temp"
mkdir -p "$TMP_ICONS"
rm -f "$TMP_ICONS"/*.tar.xz

# -------------------- Snowy Icons --------------------
SNOWY_URL="https://s341vla.storage.yandex.net/rdisk/762d6bda094ad80ac18f08f6b10d7580ef81c50b145721a8462741009f4d67b5/694cbb1d/LrLIAmix5hqiqjtvOniV8Ei4DhrHQAMRA51gS4VUD3KzJ6weCaorNb8hdKlvwFy6GJ5Dmw1PWx30m7QKk6wmnQ==?uid=0&filename=Snowy%20icons.tar.xz"

echo "Downloading Snowy icons..."
wget -O "$TMP_ICONS/snowy.tar.xz" "$SNOWY_URL"

echo "Extracting Snowy icons..."
tar -xf "$TMP_ICONS/snowy.tar.xz" -C "$TMP_ICONS"

SNOWY_DIR=$(find "$TMP_ICONS" -maxdepth 1 -type d -name "Snowy*" | head -n1)
[[ -n "$SNOWY_DIR" ]] || { echo "Snowy icons folder not found"; exit 1; }

SNOWY_THEME_NAME=$(basename "$SNOWY_DIR")  # Keep full folder name
cp -r "$SNOWY_DIR" "$HOME_DIR/.local/share/icons/"

# -------------------- Bibata Cursor --------------------
BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Original-Classic.tar.xz"

echo "Downloading Bibata cursor..."
wget -O "$TMP_ICONS/bibata.tar.xz" "$BIBATA_URL"
tar -xf "$TMP_ICONS/bibata.tar.xz" -C "$TMP_ICONS"

BIBATA_DIR=$(find "$TMP_ICONS" -maxdepth 1 -type d -name "Bibata*" | head -n1)
[[ -n "$BIBATA_DIR" ]] || { echo "Bibata cursor folder not found"; exit 1; }

cp -r "$BIBATA_DIR" "$HOME_DIR/.local/share/icons/"

# Cleanup
rm -rf "$TMP_ICONS"
chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR/.local/share/icons"
echo "Icons and cursor installed successfully."

### -------------------- OH MY ZSH --------------------
[[ -d "$HOME_DIR/.oh-my-zsh" ]] || sudo -u "$USER_NAME" sh -c \
"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

### -------------------- USER CONFIGS --------------------
mkdir -p "$HOME_DIR/.config/alacritty"
cp "$CONFIG_SRC/.bashrc" "$HOME_DIR/" 2>/dev/null || true
cp "$CONFIG_SRC/.zshrc" "$HOME_DIR/" 2>/dev/null || true
cp "$CONFIG_SRC/alacritty.yml" "$HOME_DIR/.config/alacritty/" 2>/dev/null || true
chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR"

### -------------------- KDE AUTO APPLY --------------------
export XDG_RUNTIME_DIR="/run/user/$(id -u "$USER_NAME")"
mkdir -p "$XDG_RUNTIME_DIR"
chown "$USER_NAME:$USER_NAME" "$XDG_RUNTIME_DIR"

sudo -u "$USER_NAME" lookandfeeltool -a org.kde.monochrome || true
sudo -u "$USER_NAME" plasma-apply-colorscheme Monochrome || true

sudo -u "$USER_NAME" kwriteconfig5 --file kdeglobals --group Icons --key Theme "$SNOWY_THEME_NAME"
sudo -u "$USER_NAME" kwriteconfig5 --file kcminputrc --group Mouse --key cursorTheme Bibata-Original-Classic

### -------------------- PLASMA BACKUP --------------------
BACKUP_DIR="$HOME_DIR/.config_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up existing Plasma configs to $BACKUP_DIR..."
for file in plasma-org.kde.plasma.desktop-appletsrc plasmarc kwinrc kdeglobals; do
    [[ -f "$HOME_DIR/.config/$file" ]] && cp "$HOME_DIR/.config/$file" "$BACKUP_DIR/"
done
chown -R "$USER_NAME:$USER_NAME" "$BACKUP_DIR"
echo "Backup complete."

### -------------------- PLASMA LAYOUT --------------------
echo "Applying Plasma layout..."
sudo -u "$USER_NAME" kquitapp5 plasmashell || true
sleep 1

if [[ "$HOSTNAME" == *desktop* ]] && [[ -f "$PLASMA_CFG/desktop-appletsrc-desktop" ]]; then
    LAYOUT="$PLASMA_CFG/desktop-appletsrc-desktop"
elif [[ "$HOSTNAME" == *laptop* ]] && [[ -f "$PLASMA_CFG/desktop-appletsrc-laptop" ]]; then
    LAYOUT="$PLASMA_CFG/desktop-appletsrc-laptop"
else
    LAYOUT="$(ls "$PLASMA_CFG"/desktop-appletsrc-* 2>/dev/null | head -n1)"
fi

[[ -n "${LAYOUT:-}" ]] || { echo "No Plasma layout found"; exit 1; }

cp "$LAYOUT" "$HOME_DIR/.config/plasma-org.kde.plasma.desktop-appletsrc"
cp "$PLASMA_CFG/"{plasmarc,kwinrc,kdeglobals} "$HOME_DIR/.config/" 2>/dev/null || true

chown "$USER_NAME:$USER_NAME" \
  "$HOME_DIR/.config/plasma-org.kde.plasma.desktop-appletsrc" \
  "$HOME_DIR/.config/plasmarc" \
  "$HOME_DIR/.config/kwinrc" \
  "$HOME_DIR/.config/kdeglobals" 2>/dev/null || true

sudo -u "$USER_NAME" kstart5 plasmashell || true

### -------------------- SERVICES --------------------
systemctl enable --now NetworkManager
systemctl enable --now coolercontrold || true

### -------------------- CPU --------------------
cpupower frequency-set --governor performance || true

echo "=== DONE — REBOOT RECOMMENDED ==="
