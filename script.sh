#!/bin/bash

# Log file for tracking installation progress and errors
LOG_FILE="/tmp/install_log.txt"
echo "Starting installation process..." > "$LOG_FILE"

# Ensure the script is being run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >> "$LOG_FILE"
    exit 1
fi

# Prompt for confirmation before proceeding
read -p "This will install your packages and copy configuration files. Continue? (y/n): " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Aborting installation." >> "$LOG_FILE"
    exit 0
fi

# Step 2: Remove conflicting vlc-plugins-all package (if exists)
echo "Removing conflicting vlc-plugins-all package..." >> "$LOG_FILE"
if pacman -Q vlc-plugins-all &>/dev/null; then
    echo "Package vlc-plugins-all is installed, removing..." >> "$LOG_FILE"
    pacman -Rns vlc-plugins-all --noconfirm >> "$LOG_FILE" 2>&1
    echo "Removed vlc-plugins-all to resolve conflict." >> "$LOG_FILE"
fi

# Variables
USER="$SUDO_USER"  # Assumes you're running the script as root, but for the user's configs
HOME_DIR="/home/$USER"
SCRIPT_DIR=$(dirname "$(realpath "$0")")  # Get the directory of the script
CONFIG_SRC="$SCRIPT_DIR/configs"          # Assuming config files are in the same directory as the script

# Ensure .config directory exists
mkdir -p "$HOME_DIR/.config"

# List of packages you want to install
PACKAGES=(
    "zed"         # Coding
    "steam"       # Gaming
    "alacritty"   # Terminal emulator (if you use it)
    "git"         # Github
    "zsh"         # Shell
    "proton-vpn-gtk-app" # VPN
    "qbittorrent" # Torrent client
    "obs-studio-browser" # Streaming
    "cpupower"    # CPU governor
    "btop"        # btop
    "easyeffects"    # Microphone stuff & headphones
    "gpu-screen-recorder"    # Simple screen recorder
    "avidemux-qt"    # Editor simple
    "avidemux-cli"    # check above
    "kdenlive"    # Editor
    "krita"    # Picture editor
    "cameractrls"    # Camera editor
    "paru"    #Paru aur helper
)

# AUR helpers
AUR_HELPER="paru"

# Step 1: Update system and log the output
echo "Updating system..." >> "$LOG_FILE"
if ! pacman -Syu --noconfirm >> "$LOG_FILE" 2>&1; then
    echo "System update failed!" >> "$LOG_FILE"
    exit 1
fi

# Step 2: Install packages from the official repo
echo "Installing official packages..." >> "$LOG_FILE"
if ! pacman -S --noconfirm "${PACKAGES[@]}" >> "$LOG_FILE" 2>&1; then
    echo "Failed to install official packages!" >> "$LOG_FILE"
    exit 1
fi

# Step 3: Install AUR packages (if using yay)
echo "Installing AUR packages with $AUR_HELPER..." >> "$LOG_FILE"
if ! command -v $AUR_HELPER &> /dev/null; then
    echo "$AUR_HELPER is not installed, installing it now..." >> "$LOG_FILE"
    if ! pacman -S --noconfirm $AUR_HELPER >> "$LOG_FILE" 2>&1; then
        echo "Failed to install AUR helper $AUR_HELPER" >> "$LOG_FILE"
        exit 1
    fi
fi

# Install AUR packages
AUR_PACKAGES=(
    "zsh-syntax-highlighting"
    "powerlevel10k"
    "discord-ptb"
    "pano-scrobbler-bin"
    "kew"
    "floorp-bin"
    "librewolf-bin"
    "localsend-bin"
    "protonplus"
    "proton-pass-bin"
    "proton-mail-bin"
    "ungoogled-chromium-bin"
    "tidal-hifi-bin"
    "adwsteamgtk"
    "coolercontrol-bin"
    "liquidctl"
    "lm_sensors"
    "stremio"
    "chatterino2-bin"
)
if ! $AUR_HELPER -S --noconfirm "${AUR_PACKAGES[@]}" >> "$LOG_FILE" 2>&1; then
    echo "Failed to install AUR packages!" >> "$LOG_FILE"
    exit 1
fi

# Step 4: Install Paper Mono font
echo "Installing Paper Mono font..." >> "$LOG_FILE"
git clone https://github.com/paper-design/paper-mono.git /tmp/paper-mono || {
    echo "Failed to clone Paper Mono font repository" >> "$LOG_FILE"
    exit 1
}
mkdir -p /usr/share/fonts/TTF
cp /tmp/paper-mono/fonts/ttf/*.ttf /usr/share/fonts/TTF/
fc-cache -fv
rm -rf /tmp/paper-mono
chown -R $USER:$USER "$HOME_DIR/.cache/fontconfig"
echo "Paper Mono font installed successfully!" >> "$LOG_FILE"

# Step 5: Install Monochrome KDE Global Theme
echo "Installing Monochrome KDE theme..." >> "$LOG_FILE"
su - $USER -c "git clone https://github.com/pwyde/monochrome-kde.git /tmp/monochrome-kde && cd /tmp/monochrome-kde && ./install.sh" >> "$LOG_FILE" 2>&1
rm -rf /tmp/monochrome-kde
echo "Note: Apply Monochrome theme in System Settings > Appearance > Global Theme" >> "$LOG_FILE"
echo "Note: Apply Bibata Original Classic cursor in System Settings > Appearance > Cursors" >> "$LOG_FILE"

# Step 6: Install Oh My Zsh
echo "Installing Oh My Zsh..." >> "$LOG_FILE"
if ! sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >> "$LOG_FILE" 2>&1; then
    echo "Failed to install Oh My Zsh!" >> "$LOG_FILE"
    exit 1
fi
echo "Oh My Zsh installed!" >> "$LOG_FILE"

# Step 7: Install Snowy icon theme from Yandex Disk
echo "Installing Snowy icon theme..." >> "$LOG_FILE"
mkdir -p "$HOME_DIR/.local/share/icons"
cd /tmp
SNOWY_ICON_URL="https://getfile.dokpub.com/yandex/get/https://disk.yandex.ru/d/kVzafq1ptMV4R"
wget "$SNOWY_ICON_URL" -O snowy-icons.zip || \
    curl -L "$SNOWY_ICON_URL" | \
    grep -o '"href":"[^"]*"' | cut -d'"' -f4 | xargs wget -O snowy-icons.zip
unzip -o snowy-icons.zip -d snowy-extract
cp -r snowy-extract/Snowy "$HOME_DIR/.local/share/icons/"
chown -R $USER:$USER "$HOME_DIR/.local/share/icons/Snowy"
rm -rf /tmp/snowy-icons.zip /tmp/snowy-extract
echo "Snowy icons installed!" >> "$LOG_FILE"

# Step 7b: Download Bibata Original Classic cursor from GitHub
echo "Installing Bibata Original Classic cursor..." >> "$LOG_FILE"
cd /tmp
BIBATA_CURSOR_URL="https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Original-Classic.tar.xz"
wget "$BIBATA_CURSOR_URL" -O bibata.tar.xz
tar -xf bibata.tar.xz
mkdir -p "$HOME_DIR/.local/share/icons"
cp -r Bibata-Original-Classic "$HOME_DIR/.local/share/icons/"
chown -R $USER:$USER "$HOME_DIR/.local/share/icons/Bibata-Original-Classic"
rm -rf /tmp/bibata.tar.xz /tmp/Bibata-Original-Classic
echo "Bibata Original Classic cursor installed!" >> "$LOG_FILE"
echo "Note: Apply Snowy icons in System Settings > Appearance > Icons" >> "$LOG_FILE"
echo "Note: Apply Bibata Original Classic cursor in System Settings > Appearance > Cursors" >> "$LOG_FILE"

# Step 8: Configure udev rules for WebHID/WebUSB browser access
echo "Setting up udev rules for browser HID/USB access..." >> "$LOG_FILE"
cat > /etc/udev/rules.d/71-webhid.rules << 'EOF'
# Allow browser access to HID devices (hardware wallets, security keys, etc.)
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", TAG+="uaccess"
EOF

cat > /etc/udev/rules.d/71-webusb.rules << 'EOF'
# Allow browser access to USB devices
SUBSYSTEM=="usb", MODE="0660", TAG+="uaccess"
EOF

udevadm control --reload-rules
udevadm trigger
echo "WebHID/WebUSB rules configured - browsers can now access USB/HID devices" >> "$LOG_FILE"

# Step 8a: Copy Plasma applet configuration file (plasma-org.kde.plasma.desktop-appletsrc)
echo "Copying Plasma applet configuration file..." >> "$LOG_FILE"
if [ ! -d "$CONFIG_SRC" ]; then
    echo "Configuration source directory $CONFIG_SRC not found!" >> "$LOG_FILE"
    exit 1
fi

APPLET_FILE="plasma-org.kde.plasma.desktop-appletsrc"
if [ -f "$CONFIG_SRC/$APPLET_FILE" ]; then
    echo "Backing up existing Plasma applet configuration..." >> "$LOG_FILE"
    mv "$HOME_DIR/.config/$APPLET_FILE" "$HOME_DIR/.config/${APPLET_FILE}.bak"
    cp "$CONFIG_SRC/$APPLET_FILE" "$HOME_DIR/.config/$APPLET_FILE"
    chown $USER:$USER "$HOME_DIR/.config/$APPLET_FILE"
    echo "Plasma applet configuration copied!" >> "$LOG_FILE"
else
    echo "Plasma applet configuration file $APPLET_FILE not found in source directory!" >> "$LOG_FILE"
fi


# Step 9: Copy configuration files (if you have custom ones)
echo "Copying configuration files..." >> "$LOG_FILE"
if [ ! -d "$CONFIG_SRC" ]; then
    echo "Configuration source directory $CONFIG_SRC not found!" >> "$LOG_FILE"
    exit 1
fi

CONFIG_FILES=(
    ".bashrc"
    ".zshrc"
    "alacritty.yml"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$HOME_DIR/$file" ]; then
        echo "Backing up existing $file..." >> "$LOG_FILE"
        mv "$HOME_DIR/$file" "$HOME_DIR/${file}.bak"
    fi
    if [ -f "$CONFIG_SRC/$file" ]; then
        if [[ "$file" == "alacritty.yml" ]]; then
            # Special case for alacritty.yml
            mkdir -p "$HOME_DIR/.config/alacritty"
            cp "$CONFIG_SRC/$file" "$HOME_DIR/.config/alacritty/$file"
            chown -R $USER:$USER "$HOME_DIR/.config/alacritty"
            echo "Copied alacritty.yml configuration!" >> "$LOG_FILE"
        else
            cp "$CONFIG_SRC/$file" "$HOME_DIR/$file"
            chown $USER:$USER "$HOME_DIR/$file"
        fi
    else
        echo "Configuration file $file not found in source directory!" >> "$LOG_FILE"
    fi
done

# Step 10: Enable and start necessary services (if any)
echo "Enabling and starting services..." >> "$LOG_FILE"
systemctl enable --now NetworkManager >> "$LOG_FILE" 2>&1
systemctl enable --now coolercontrold >> "$LOG_FILE" 2>&1

# Step 11: Set CPU performance governor to performance
echo "Setting CPU governor to performance..." >> "$LOG_FILE"
if ! command -v cpupower &> /dev/null; then
    echo "cpupower is not installed, installing it now..." >> "$LOG_FILE"
    pacman -S --noconfirm cpupower >> "$LOG_FILE" 2>&1
fi
cpupower frequency-set --governor performance >> "$LOG_FILE" 2>&1

# Step 12: finish
echo "Installation complete!" >> "$LOG_FILE"
echo "Please reboot your system to apply all changes." >> "$LOG_FILE"
echo "Installation log saved to $LOG_FILE"
exit
