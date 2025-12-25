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

### -------------------- KDE THEME --------------------
runuser -u "$USER_NAME" -- git clone https://gitlab.com/pwyde/monochrome-kde.git "$TMPDIR/mono"
runuser -u "$USER_NAME" -- bash -c "cd $TMPDIR/mono && ./install.sh --install"
rm -rf "$TMPDIR/mono"

### -------------------- ICONS (SNOWY) --------------------
SNOWY_SHARE_URL="https://disk.yandex.ru/d/kVzafq1ptMV4R"
SNOWY_API_URL="https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=${SNOWY_SHARE_URL}"
TMP_ICONS="$TMPDIR/icons_temp"

mkdir -p "$TMP_ICONS"

echo "Resolving Snowy icons download link..."
SNOWY_REAL_URL=$(curl -fsSL "$SNOWY_API_URL" | sed -n 's/.*"href":"\([^"]*\)".*/\1/p')
[[ -n "$SNOWY_REAL_URL" ]] || { echo "Failed to resolve Snowy icons URL"; exit 1; }

echo "Downloading Snowy icons..."
wget -qO "$TMP_ICONS/snowy.tar.xz" "$SNOWY_REAL_URL"

echo "Extracting Snowy icons..."
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
echo "Icons installed: $SNOWY_THEME_NAME"

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

### -------------------- KDE APPLY (PLASMA 5/6 SAFE) --------------------
KW=kwriteconfig5
KS=kstart5
KQ=kquitapp5

command -v kwriteconfig6 &>/dev/null && KW=kwriteconfig6
command -v kstart &>/dev/null && KS=kstart
command -v kquitapp6 &>/dev/null && KQ=kquitapp6

runuser -u "$USER_NAME" -- lookandfeeltool -a org.kde.monochrome || true
runuser -u "$USER_NAME" -- plasma-apply-colorscheme Monochrome || true
runuser -u "$USER_NAME" -- "$KW" --file kdeglobals --group Icons --key Theme "$SNOWY_THEME_NAME"
runuser -u "$USER_NAME" -- "$KW" --file kcminputrc --group Mouse --key cursorTheme Bibata-Original-Classic

### -------------------- PLASMA BACKUP --------------------
BACKUP_DIR="$HOME_DIR/.config_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

for file in plasma-org.kde.plasma.desktop-appletsrc plasmarc kwinrc kdeglobals; do
    [[ -f "$HOME_DIR/.config/$file" ]] && cp "$HOME_DIR/.config/$file" "$BACKUP_DIR/"
done

chown -R "$USER_NAME:$USER_NAME" "$BACKUP_DIR"

### -------------------- PLASMA LAYOUT --------------------
runuser -u "$USER_NAME" -- "$KQ" plasmashell || true
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
chown "$USER_NAME:$USER_NAME" "$HOME_DIR/.config/"*

runuser -u "$USER_NAME" -- "$KS" plasmashell || true

### -------------------- SERVICES --------------------
systemctl enable --now NetworkManager
systemctl enable --now coolercontrold || true
systemctl enable --now cpupower || true

### -------------------- CPU --------------------
cpupower frequency-set --governor performance || true

echo "=== DONE — REBOOT RECOMMENDED ==="
