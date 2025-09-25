#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# Add Docker repository
dnf5 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo

# Core packages for Stratos Linux
# Note: Installing packages separately to handle potential failures gracefully
dnf5 install -y tmux
dnf5 install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Try to install libldm, skip if not available
dnf5 install -y libldm || echo "libldm package not found in repositories"

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
cat > /etc/motd << EOF

            ..'''' `````|````` |`````````,       .'.       `````|`````  .~      ~.              ..'''' 
         .''            |      |'''|'''''      .''```.          |      |          |          .''       
      ..'               |      |    `.       .'       `.        |      |          |       ..'          
....''                  |      |      `.   .'           `.      |       `.______.'  ....''             
                                                                                                       
                                             LINUX
EOF
