#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# Add Docker repository (dnf5 method)
curl -fsSL https://download.docker.com/linux/fedora/docker-ce.repo -o /etc/yum.repos.d/docker-ce.repo

# Core packages for Stratos Linux
# Note: Installing packages separately to handle potential failures gracefully
dnf5 install -y tmux
dnf5 install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Try to install libldm, skip if not available
dnf5 install -y libldm || echo "libldm package not found in repositories"

# Install GNOME Extensions management tools
dnf5 install -y gnome-extensions-app gnome-tweaks

# Install specific GNOME extensions (available in Fedora repos)
dnf5 install -y gnome-shell-extension-user-theme
dnf5 install -y gnome-shell-extension-dash-to-dock

# Extensions not available in Fedora repos - will be downloaded from extensions.gnome.org
# - ArcMenu
# - Just Perfection
# - Blur My Shell
# - Tiling Assistant
# - Desktop Icons NG (DING)

# Install extensions from GNOME Extensions website
# Create extension installation script
cat > /usr/bin/install-gnome-extension.sh << 'EOF'
#!/bin/bash
# Script to install GNOME extensions from extensions.gnome.org

EXTENSION_ID=$1
if [ -z "$EXTENSION_ID" ]; then
    echo "Usage: $0 <extension-id>"
    exit 1
fi

# Get GNOME Shell version
GNOME_VERSION=$(gnome-shell --version | cut -d' ' -f3 | cut -d'.' -f1,2)

# Download extension info
EXTENSION_INFO=$(curl -s "https://extensions.gnome.org/extension-info/?pk=${EXTENSION_ID}")
DOWNLOAD_URL=$(echo $EXTENSION_INFO | python3 -c "import sys, json; data=json.load(sys.stdin); print('https://extensions.gnome.org' + data['download_url'])")

if [ "$DOWNLOAD_URL" = "https://extensions.gnome.org" ]; then
    echo "Failed to get download URL for extension $EXTENSION_ID"
    exit 1
fi

# Create extensions directory
mkdir -p /usr/share/gnome-shell/extensions

# Download and install extension
TEMP_FILE=$(mktemp)
curl -s -o "$TEMP_FILE" "$DOWNLOAD_URL"

# Extract extension UUID from the zip
EXTENSION_UUID=$(unzip -qql "$TEMP_FILE" | head -n1 | tr -s ' ' | cut -d' ' -f5- | cut -d'/' -f1)

# Extract extension to system directory
unzip -q "$TEMP_FILE" -d "/usr/share/gnome-shell/extensions/"

rm "$TEMP_FILE"
echo "Installed extension: $EXTENSION_UUID"
EOF

chmod +x /usr/bin/install-gnome-extension.sh

# Install Python3 for JSON parsing
dnf5 install -y python3

# Install extensions from GNOME Extensions website
# ArcMenu - Extension ID: 3628
/usr/bin/install-gnome-extension.sh 3628 || echo "Failed to install ArcMenu"

# Just Perfection - Extension ID: 3843
/usr/bin/install-gnome-extension.sh 3843 || echo "Failed to install Just Perfection"

# Blur My Shell - Extension ID: 3193
/usr/bin/install-gnome-extension.sh 3193 || echo "Failed to install Blur My Shell"

# Tiling Assistant - Extension ID: 3733
/usr/bin/install-gnome-extension.sh 3733 || echo "Failed to install Tiling Assistant"

# Desktop Icons NG (DING) - Extension ID: 2087
/usr/bin/install-gnome-extension.sh 2087 || echo "Failed to install Desktop Icons NG"

# Tailscale QS - Extension ID: 4065
/usr/bin/install-gnome-extension.sh 4065 || echo "Failed to install Tailscale QS"

# Daily Bing Wallpaper - Extension ID: 1262
/usr/bin/install-gnome-extension.sh 1262 || echo "Failed to install Daily Bing Wallpaper"

# Burn My Windows - Extension ID: 4679
/usr/bin/install-gnome-extension.sh 4679 || echo "Failed to install Burn My Windows"

#### Icon Theme Configuration

# Install Fluent icon theme
echo "Installing Fluent icon theme..."

# Install required packages for icon theme installation
dnf5 install -y git

# Clone Fluent icon theme repository
cd /tmp
git clone https://github.com/vinceliuice/Fluent-icon-theme.git
cd Fluent-icon-theme

# Install the icon theme system-wide
./install.sh -a

# Set Fluent-dark as the default icon theme
# Create a dconf profile for default settings
mkdir -p /etc/dconf/profile
cat > /etc/dconf/profile/user << 'EOF'
user-db:user
system-db:local
EOF

# Create system database directory
mkdir -p /etc/dconf/db/local.d

# Set default icon theme to Fluent-dark
cat > /etc/dconf/db/local.d/01-icon-theme << 'EOF'
[org/gnome/desktop/interface]
icon-theme='Fluent-dark'
EOF

# Update dconf database
dconf update

# Clean up
cd /
rm -rf /tmp/Fluent-icon-theme

echo "Fluent icon theme installed and set as default"

#### Flatpak Configuration and Installation

# Install Flatpak (should already be available in Fedora)
dnf5 install -y flatpak

# Add Flathub repository - this configures the repository for the image
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Create comprehensive Flatpak installation scripts for users
# This approach is better for immutable systems where users install apps as needed

# Create system-wide Flatpak installation script
cat > /usr/bin/install-system-flatpaks.sh << 'EOF'
#!/bin/bash
# System-wide Flatpaks Installation Script
echo "Installing system-wide Flatpaks (productivity, utilities, and core applications)..."

# Productivity and Office
flatpak install -y --system flathub org.onlyoffice.desktopeditors
flatpak install -y --system flathub org.mozilla.Thunderbird
flatpak install -y --system flathub com.bitwarden.desktop
flatpak install -y --system flathub org.cryptomator.Cryptomator

# Development and System Tools
flatpak install -y --system flathub com.mattjakeman.ExtensionManager
flatpak install -y --system flathub com.github.marhkb.Pods
flatpak install -y --system flathub it.mijorus.gearlever
flatpak install -y --system flathub net.nokyan.Resources
flatpak install -y --system flathub org.virt_manager.virt-manager
flatpak install -y --system flathub com.termius.Termius

# Media and Graphics
flatpak install -y --system flathub org.videolan.VLC
flatpak install -y --system flathub com.obsproject.Studio
flatpak install -y --system flathub com.github.rafostar.Clapper
flatpak install -y --system flathub com.github.huluti.Curtail
flatpak install -y --system flathub de.haeckerfelix.Fragments

# Text Editors and Documentation
flatpak install -y --system flathub com.github.marktext.marktext
flatpak install -y --system flathub org.gnome.gitlab.somas.Apostrophe
flatpak install -y --system flathub page.tesk.Refine

# GNOME Applications
flatpak install -y --system flathub org.gnome.Calculator
flatpak install -y --system flathub org.gnome.Calendar
flatpak install -y --system flathub org.gnome.Characters
flatpak install -y --system flathub org.gnome.Connections
flatpak install -y --system flathub org.gnome.Contacts
flatpak install -y --system flathub org.gnome.DejaDup
flatpak install -y --system flathub org.gnome.Firmware
flatpak install -y --system flathub org.gnome.Fractal
flatpak install -y --system flathub org.gnome.GHex
flatpak install -y --system flathub org.gnome.Geary
flatpak install -y --system flathub org.gnome.Logs
flatpak install -y --system flathub org.gnome.Loupe
flatpak install -y --system flathub org.gnome.Maps
flatpak install -y --system flathub org.gnome.NautilusPreviewer
flatpak install -y --system flathub org.gnome.Papers
flatpak install -y --system flathub org.gnome.SimpleScan
flatpak install -y --system flathub org.gnome.TextEditor
flatpak install -y --system flathub org.gnome.Weather
flatpak install -y --system flathub org.gnome.World.PikaBackup
flatpak install -y --system flathub org.gnome.baobab
flatpak install -y --system flathub org.gnome.clocks
flatpak install -y --system flathub org.gnome.font-viewer

# Audio/Sound Tools
flatpak install -y --system flathub com.rafaelmardojai.Blanket
flatpak install -y --system flathub com.saivert.pwvucontrol

# Utilities and Tools
flatpak install -y --system flathub com.vixalien.sticky
flatpak install -y --system flathub io.gitlab.adhami3310.Converter
flatpak install -y --system flathub io.gitlab.librewolf-community
flatpak install -y --system flathub io.kapsa.drive
flatpak install -y --system flathub nl.g4d.Girens
flatpak install -y --system flathub page.codeberg.libre_menu_editor.LibreMenuEditor
flatpak install -y --system flathub so.libdb.dissent
flatpak install -y --system flathub org.jdownloader.JDownloader
flatpak install -y --system flathub io.github.realmazharhussain.GdmSettings
flatpak install -y --system flathub io.github.giantpinkrobots.varia
flatpak install -y --system flathub io.github.nokse22.Exhibit
flatpak install -y --system flathub io.github.shiftey.Desktop

echo "System-wide Flatpaks installation completed!"
EOF

chmod +x /usr/bin/install-system-flatpaks.sh

# Create gaming Flatpak installation script
cat > /usr/bin/install-gaming-flatpaks.sh << 'EOF'
#!/bin/bash
# Gaming Flatpaks - User Installation Script
echo "Installing gaming and emulation Flatpaks for current user..."

# Gaming Platforms
flatpak install -y --user flathub com.valvesoftware.Steam
flatpak install -y --user flathub com.heroicgameslauncher.hgl
flatpak install -y --user flathub net.lutris.Lutris
flatpak install -y --user flathub com.usebottles.bottles
flatpak install -y --user flathub org.winehq.Wine

# Gaming Tools
flatpak install -y --user flathub com.github.Matoking.protontricks
flatpak install -y --user flathub com.vysp3r.ProtonPlus
flatpak install -y --user flathub com.steamgriddb.SGDBoop
flatpak install -y --user flathub com.steamgriddb.steam-rom-manager
flatpak install -y --user flathub net.davidotek.pupgui2
flatpak install -y --user flathub com.github.mtkennerly.ludusavi
flatpak install -y --user flathub io.github.fastrizwaan.WineCharm
flatpak install -y --user flathub io.github.fastrizwaan.WineZGUI

# Emulators
flatpak install -y --user flathub org.DolphinEmu.dolphin-emu
flatpak install -y --user flathub net.pcsx2.PCSX2
flatpak install -y --user flathub net.rpcs3.RPCS3
flatpak install -y --user flathub org.duckstation.DuckStation
flatpak install -y --user flathub io.github.ryubing.Ryujinx
flatpak install -y --user flathub net.shadps4.shadPS4

# Specialized Gaming Tools
flatpak install -y --user flathub com.github.ADBeveridge.Raider
flatpak install -y --user flathub com.github.sdv43.whaler
flatpak install -y --user flathub io.github.ellie_commons.jorts
flatpak install -y --user flathub io.github.zaedus.spider

# Screen Recording and Streaming
flatpak install -y --user flathub com.dec05eba.gpu_screen_recorder
flatpak install -y --user flathub de.nicokimmel.shadowcast-electron
flatpak install -y --user flathub dev.lizardbyte.app.Sunshine
flatpak install -y --user flathub dev.fredol.open-tv

echo "Gaming Flatpaks installation completed!"
echo "You can now launch your gaming applications from the application menu."
EOF

chmod +x /usr/bin/install-gaming-flatpaks.sh

# Create a combined installation script
cat > /usr/bin/install-all-flatpaks.sh << 'EOF'
#!/bin/bash
# Install all Stratos Linux Flatpaks
echo "Installing all Stratos Linux Flatpaks..."
echo "This will install system-wide and user-level applications."
echo ""

echo "Installing system applications..."
/usr/bin/install-system-flatpaks.sh

echo ""
echo "Installing gaming applications..."
/usr/bin/install-gaming-flatpaks.sh

echo ""
echo "All Flatpak installations completed!"
echo "Applications are now available in your application menu."
EOF

chmod +x /usr/bin/install-all-flatpaks.sh

echo "Flatpak configuration completed!"
echo "Users can install applications using:"
echo "  install-system-flatpaks.sh   - Productivity and system tools"
echo "  install-gaming-flatpaks.sh   - Gaming and emulation"
echo "  install-all-flatpaks.sh      - All applications"

# Enable additional repositories

# Enable RPMFusion repositories (free and non-free)
dnf5 install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
dnf5 install -y https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Enable COPR repositories
dnf5 -y copr enable ublue-os/staging

#### System Services Configuration

# Enable container services
systemctl enable podman.socket
systemctl enable docker
systemctl enable containerd

# Configure docker for user access
groupadd -f docker
# Note: Users will need to be added to docker group manually after installation

#### Stratos Linux Branding Configuration

# Create custom OS release info
cat > /etc/os-release << EOF
NAME="Stratos Linux"
VERSION="$(date +%Y.%m.%d)"
ID="stratos"
ID_LIKE="fedora"
VERSION_CODENAME=""
VERSION_ID="$(date +%Y.%m.%d)"
PLATFORM_ID="platform:stratos"
PRETTY_NAME="Stratos Linux $(date +%Y.%m.%d)"
ANSI_COLOR="0;34"
LOGO="stratos-linux"
CPE_NAME="cpe:/o:stratos:stratos:$(date +%Y.%m.%d)"
HOME_URL="https://github.com/ljam96/stratos-linux"
DOCUMENTATION_URL="https://github.com/ljam96/stratos-linux/blob/main/README.md"
SUPPORT_URL="https://github.com/ljam96/stratos-linux/issues"
BUG_REPORT_URL="https://github.com/ljam96/stratos-linux/issues"
REDHAT_BUGZILLA_PRODUCT="Stratos Linux"
REDHAT_BUGZILLA_PRODUCT_VERSION="$(date +%Y.%m.%d)"
REDHAT_SUPPORT_PRODUCT="Stratos Linux"
REDHAT_SUPPORT_PRODUCT_VERSION="$(date +%Y.%m.%d)"
EOF

# Create custom issue file
cat > /etc/issue << EOF
Welcome to Stratos Linux \r (\l)

EOF

# Create motd
cat > /etc/motd << 'EOF'

  ███████ ████████ ██████   █████  ████████  ██████  ███████
  ██         ██    ██   ██ ██   ██    ██    ██    ██ ██
  ███████    ██    ██████  ███████    ██    ██    ██ ███████
       ██    ██    ██   ██ ██   ██    ██    ██    ██      ██
  ███████    ██    ██   ██ ██   ██    ██     ██████  ███████

                           LINUX

 Welcome to Stratos Linux - Development Ready Container Platform

 Documentation: https://github.com/ljam96/stratos-linux
 Issues: https://github.com/ljam96/stratos-linux/issues

EOF
