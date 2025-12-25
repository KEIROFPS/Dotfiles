#!/bin/bash
set -Eeuo pipefail
trap 'echo "FAILED at line $LINENO"' ERR

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
ping -c1 archlinux.org >/dev/null || { echo "No network connection"; exit 1; }

### -------------------- BASE TOOLS --------------------
pacman -Syu --needed --noconfirm git curl wget unzip base-devel

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

pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"

### -------------------- PARU --------------------
if ! command -v paru &>/dev/null; then
    runuser -u "$USER_NAME" -- git clone https://aur.archlinux.org/paru.git "$TMPDIR/paru"
    runuser -u "$USER_NAME" -- bash -c "cd $TMPDIR/paru && makepkg -si --noconfirm"
fi

runuser -u "$USER_NAME" -- paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"

### -------------------- FONTS --------------------
git clone https://github.com/paper-design/paper-mono.git "$TMPDIR/paper-mono"
install -d /usr/share/fonts/TTF
install -m644 "$TMPDIR/paper-mono/fonts/ttf/"*.ttf /usr/share/fonts/TTF/
fc-cache -r
rm -rf "$TMPDIR/paper-mono"

### -------------------- KDE COLOR SCHEME --------------------
runuser -u "$USER_NAME" -- git clone https://gitlab.com/pwyde/monochrome-kde.git "$TMPDIR/mono"
runuser -u "$USER_NAME" -- bash -c "cd $TMPDIR/mono && ./install.sh --install"
rm -rf "$TMPDIR/mono"

### -------------------- ICONS (SNOWY) --------------------
SNOWY_SHARE_URL="https://disk.yandex.ru/d/kVzafq1ptMV4R"
SNOWY_API_URL="https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=${SNOWY_SHARE_URL}"
TMP_ICONS="$TMPDIR/icons_temp"

mkdir -p "$TMP_ICONS"

SNOWY_REAL_URL=$(curl -fsSL "$SNOWY_API_URL" | sed -n 's/.*"href":"\([^"]*\)".*/\1/p')
[[ -n "$SNOWY_REAL_URL" ]] || { echo "Failed to resolve Snowy icons URL"; exit 1; }

wget -qO "$TMP_ICONS/snowy.tar.xz" "$SNOWY_REAL_URL"
tar -xf "$TMP_ICONS/snowy.tar.xz" -C "$TMP_ICONS"

SNOWY_DIR=$(find "$TMP_ICONS" -maxdepth 1 -type d -iname "Snowy*" | head -n1)
[[ -n "$SNOWY_DIR" ]] || { echo "Snowy icons folder not found"; exit 1; }

SNOWY_THEME_NAME="$(basename "$SNOWY_DIR")"

install -d /usr/share/icons
rm -rf "/usr/share/icons/$SNOWY_THEME_NAME"
cp -r "$SNOWY_DIR" /usr/share/icons/
chmod -R a+rX "/usr/share/icons/$SNOWY_THEME_NAME"
gtk-update-icon-cache "/usr/share/icons/$SNOWY_THEME_NAME" || true
rm -rf "$TMP_ICONS"

### -------------------- BIBATA CURSOR --------------------
BIBATA_URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Original-Classic.tar.xz"
wget -qO "$TMPDIR/bibata.tar.xz" "$BIBATA_URL"
tar -xf "$TMPDIR/bibata.tar.xz" -C /usr/share/icons
rm -f "$TMPDIR/bibata.tar.xz"

### -------------------- OH MY ZSH --------------------
if [[ ! -d "$HOME_DIR/.oh-my-zsh" ]]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    runuser -u "$USER_NAME" -- \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

### -------------------- USER CONFIGS --------------------
mkdir -p "$HOME_DIR/.config/alacritty"
cp "$CONFIG_SRC/.bashrc" "$HOME_DIR/" 2>/dev/null || true
cp "$CONFIG_SRC/.zshrc" "$HOME_DIR/" 2>/dev/null || true
cp "$CONFIG_SRC/alacritty.yml" "$HOME_DIR/.config/alacritty/" 2>/dev/null || true
chown -R "$USER_NAME:$USER_NAME" "$HOME_DIR"

### -------------------- KDE CONFIG (SAFE) --------------------
CONFIG_DIR="$HOME_DIR/.config"

# Color scheme
grep -q "^\[General\]" "$CONFIG_DIR/kdeglobals" 2>/dev/null || echo "[General]" >> "$CONFIG_DIR/kdeglobals"
sed -i 's/^ColorScheme=.*/ColorScheme=Monochrome/' "$CONFIG_DIR/kdeglobals" 2>/dev/null || true
grep -q "ColorScheme=Monochrome" "$CONFIG_DIR/kdeglobals" || echo "ColorScheme=Monochrome" >> "$CONFIG_DIR/kdeglobals"

# Icons
grep -q "^\[Icons\]" "$CONFIG_DIR/kdeglobals" || echo -e "\n[Icons]" >> "$CONFIG_DIR/kdeglobals"
sed -i "s/^Theme=.*/Theme=$SNOWY_THEME_NAME/" "$CONFIG_DIR/kdeglobals" 2>/dev/null || true
grep -q "Theme=$SNOWY_THEME_NAME" "$CONFIG_DIR/kdeglobals" || echo "Theme=$SNOWY_THEME_NAME" >> "$CONFIG_DIR/kdeglobals"

# Cursor
grep -q "^\[Mouse\]" "$CONFIG_DIR/kcminputrc" 2>/dev/null || echo "[Mouse]" >> "$CONFIG_DIR/kcminputrc"
sed -i 's/^cursorTheme=.*/cursorTheme=Bibata-Original-Classic/' "$CONFIG_DIR/kcminputrc" 2>/dev/null || true
grep -q "cursorTheme=Bibata-Original-Classic" "$CONFIG_DIR/kcminputrc" || echo "cursorTheme=Bibata-Original-Classic" >> "$CONFIG_DIR/kcminputrc"

chown "$USER_NAME:$USER_NAME" \
"$CONFIG_DIR/kdeglobals" \
"$CONFIG_DIR/kcminputrc" 2>/dev/null || true

### -------------------- PLASMA LAYOUT FILES --------------------
BACKUP_DIR="$HOME_DIR/.config_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

for file in plasma-org.kde.plasma.desktop-appletsrc plasmarc kwinrc kdeglobals; do
    [[ -f "$CONFIG_DIR/$file" ]] && cp "$CONFIG_DIR/$file" "$BACKUP_DIR/"
done

if [[ "$HOSTNAME" == *desktop* ]] && [[ -f "$PLASMA_CFG/desktop-appletsrc-desktop" ]]; then
    LAYOUT="$PLASMA_CFG/desktop-appletsrc-desktop"
elif [[ "$HOSTNAME" == *laptop* ]] && [[ -f "$PLASMA_CFG/desktop-appletsrc-laptop" ]]; then
    LAYOUT="$PLASMA_CFG/desktop-appletsrc-laptop"
else
    LAYOUT="$(ls "$PLASMA_CFG"/desktop-appletsrc-* 2>/dev/null | head -n1)"
fi

[[ -n "${LAYOUT:-}" ]] && cp "$LAYOUT" "$CONFIG_DIR/plasma-org.kde.plasma.desktop-appletsrc"
cp "$PLASMA_CFG/"{plasmarc,kwinrc,kdeglobals} "$CONFIG_DIR/" 2>/dev/null || true
chown -R "$USER_NAME:$USER_NAME" "$CONFIG_DIR"

### -------------------- SERVICES --------------------
systemctl enable --now NetworkManager
systemctl enable --now coolercontrold || true
systemctl enable --now cpupower || true

### -------------------- CPU --------------------
cpupower frequency-set --governor performance || true

### -------------------- FINAL SANITY CHECK --------------------
echo "=== SANITY CHECK ==="

# Check Monochrome color scheme
if grep -q "ColorScheme=Monochrome" "$CONFIG_DIR/kdeglobals"; then
    echo "✅ Monochrome color scheme applied"
else
    echo "⚠️ Monochrome color scheme NOT applied"
fi

# Check Snowy icons
if [[ -d "/usr/share/icons/$SNOWY_THEME_NAME" ]]; then
    echo "✅ Snowy icons installed: $SNOWY_THEME_NAME"
else
    echo "⚠️ Snowy icons NOT found"
fi

# Check Bibata cursor
if grep -q "cursorTheme=Bibata-Original-Classic" "$CONFIG_DIR/kcminputrc"; then
    echo "✅ Bibata cursor set"
else
    echo "⚠️ Bibata cursor NOT set"
fi

echo "=== DONE — REBOOT RECOMMENDED ==="
