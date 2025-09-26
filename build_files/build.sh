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

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "Installing core Flatpaks during build process..."

# Install only the most essential applications to avoid build timeouts
# Essential productivity applications
flatpak install -y --system --noninteractive flathub org.videolan.VLC || echo "Failed to install VLC"
flatpak install -y --system --noninteractive flathub com.mattjakeman.ExtensionManager || echo "Failed to install Extension Manager"
flatpak install -y --system --noninteractive flathub io.gitlab.librewolf-community || echo "Failed to install LibreWolf"

# Gaming platforms
flatpak install -y --system --noninteractive flathub com.valvesoftware.Steam || echo "Failed to install Steam"
flatpak install -y --system --noninteractive flathub net.lutris.Lutris || echo "Failed to install Lutris"

# System tools
flatpak install -y --system --noninteractive flathub net.nokyan.Resources || echo "Failed to install Resources"
flatpak install -y --system --noninteractive flathub io.github.realmazharhussain.GdmSettings || echo "Failed to install GDM Settings"

echo "Core Flatpak applications installed during build process"
echo "Additional applications can be installed using: flatpak install flathub <app-id>"

#### Custom libfprint for CS9711 fingerprint sensor support

echo "Installing custom libfprint with CS9711 support..."

# Install build dependencies for libfprint
dnf5 install -y git gcc meson ninja-build pkgconfig glib2-devel libusb1-devel nss-devel pixman-devel cairo-devel gdk-pixbuf2-devel libgudev-devel

# Clone the custom libfprint repository with CS9711 support
cd /tmp
git clone https://github.com/ddlsmurf/libfprint-CS9711.git
cd libfprint-CS9711

# Build and install the custom libfprint
meson setup builddir --prefix=/usr --libdir=/usr/lib64 --buildtype=release
meson compile -C builddir
meson install -C builddir

# Create a backup of the original libfprint if it exists and replace it
if [ -f /usr/lib64/libfprint-2.so.2 ]; then
    mv /usr/lib64/libfprint-2.so.2 /usr/lib64/libfprint-2.so.2.backup
fi

# Update library cache
ldconfig

# Clean up build directory
cd /
rm -rf /tmp/libfprint-CS9711

echo "Custom libfprint with CS9711 support installed"

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
