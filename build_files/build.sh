#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File
log() {
	echo "=== $* ==="
}

COPR_REPOS=(
    avengemedia/dms
	pgdev/ghostty
	ulysg/xwayland-satellite
	yalter/niri
)
for repo in "${COPR_REPOS[@]}"; do
	# Try to enable the repo, but don't fail the build if it doesn't support this Fedora version
	if ! dnf5 -y copr enable "$repo" 2>&1; then
		log "Warning: Failed to enable COPR repo $repo (may not support Fedora $RELEASE)"
	fi
done

NIRI_PKGS=(
    dms
	niri
	cava
	cliphist
	greetd
	greetd-selinux
	dms-greeter 
	dgop
	dsearch
	gnome-keyring
	matugen
	wl-clipboard
	xdg-desktop-portal-gtk
	xwayland-satellite
	kde-connect
    python3-pip
)

# Note that many font packages are preinstalled in the
# bazzite image, along with the SymbolsNerdFont which doesn't
# have an associated fedora package:
#
#   fira-code-fonts
#   google-droid-sans-fontsbazzirico
#   google-noto-emoji-fonts
#   google-noto-sans-cjk-fonts
#   google-noto-color-emoji-fonts
#   jetbrains-mono-fonts
#
# Because the nerd font symbols are mapped correctly, we can get
# nerd font characters anywhere.
FONTS=(
    adobe-source-code-pro-fonts
	fontawesome-fonts-all
)

# chrome etc are installed as flatpaks. We generally prefer that
# for most things with GUIs, and homebrew for CLI apps. This list is
# only special GUI apps that need to be installed at the system level.
ADDITIONAL_SYSTEM_APPS=(
    # pick your poison
    
	ghostty

	
)

# we do all package installs in one rpm-ostree command
# so that we create minimal layers in the final image
log "Installing packages using dnf5..."
dnf5 install --setopt=install_weak_deps=False -y \
	"${FONTS[@]}" \
	"${NIRI_PKGS[@]}" \
	"${ADDITIONAL_SYSTEM_APPS[@]}"
	
# Install pywalfox via pip
log "Installing pywalfox via pip..."
# 2. INSTALL both pywal and pywalfox via pip
log "Installing pywal and pywalfox via pip..."
pip install --prefix=/usr --no-cache-dir  pywal pywalfox

### 5. Bake in the Systemd User Unit for Pywalfox
log "Creating and enabling pywalfox systemd user unit..."
mkdir -p /usr/lib/systemd/user/
cat <<EOF > /usr/lib/systemd/user/pywalfox.service
[Unit]
Description=Pywalfox Daemon & DMS Color Linker
After=graphical-session.target

[Service]
# This line handles the 'additional instruction' from the DMS docs automatically
ExecStartPre=/usr/bin/bash -c 'mkdir -p %h/.cache/wal && ln -sf %h/.cache/wal/dank-pywalfox.json %h/.cache/wal/colors.json'
# The daemon
ExecStart=/usr/bin/pywalfox daemon
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

#######################################################################
### Disable repositeories so they aren't cluttering up the final image

log "Disable Copr repos to get rid of clutter..."
for repo in "${COPR_REPOS[@]}"; do
	dnf5 -y copr disable "$repo"
done
systemctl enable podman.socket
