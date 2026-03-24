#!/usr/bin/env bash
# ============================================================================
# AGISOTA Linux — Image Builder
# Builds a custom Fedora Asahi Remix image with AGISOTA branding
#
# Prerequisites:
#   - Fedora aarch64 build environment (native or QEMU)
#   - kiwi-cli installed: dnf install kiwi-systemdeps python3-kiwi
#   - Root access
#
# Usage: sudo ./scripts/build-image.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="/var/tmp/agisota-build"
OUTPUT_DIR="${REPO_DIR}/output"
VERSION="1.0.0"
FEDORA_VER=$(rpm -E %fedora 2>/dev/null || echo "41")

log() { echo -e "\033[0;33m[BUILD]\033[0m $*"; }
err() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; exit 1; }

# Check prereqs
[[ $EUID -ne 0 ]] && err "Run as root: sudo $0"
command -v kiwi-ng &>/dev/null || err "kiwi-ng not found. Install: dnf install python3-kiwi kiwi-systemdeps"

log "Building AGISOTA Linux v${VERSION} image..."

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"

# ============================================================================
# Option A: Kickstart-based build (simpler)
# ============================================================================
build_with_kickstart() {
    log "Using kickstart-based build..."

    # Create kickstart file
    cat > "${BUILD_DIR}/agisota-kde.ks" <<KICKSTART
# AGISOTA Linux Kickstart
# Based on Fedora Asahi Remix KDE

%include /usr/share/spin-kickstarts/fedora-live-kde.ks

lang ru_RU.UTF-8
keyboard --xlayouts='us,ru' --switch='grp:alt_shift_toggle'
timezone Europe/Moscow --utc

# Repos
repo --name=fedora --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-\$releasever&arch=\$basearch
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f\$releasever&arch=\$basearch
repo --name=rpmfusion-free --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-\$releasever&arch=\$basearch
repo --name=rpmfusion-nonfree --mirrorlist=https://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-\$releasever&arch=\$basearch

%packages
@kde-desktop
# Base tools
zsh
tmux
htop
btop
ripgrep
fd-find
bat
fzf
jq
wget
curl
git
git-lfs
nodejs
npm
python3
python3-pip
podman
podman-compose
flatpak
kvantum
papirus-icon-theme
google-noto-sans-fonts
google-noto-sans-mono-fonts
google-noto-emoji-fonts
jetbrains-mono-fonts
tailscale
neovim
%end

%post --nochroot
# Copy branding files into the image
cp -r ${REPO_DIR}/branding/kde/color-scheme/AGISOTA.colors \$INSTALL_ROOT/usr/share/color-schemes/
cp -r ${REPO_DIR}/branding/kde/look-and-feel/org.agisota.desktop \$INSTALL_ROOT/usr/share/plasma/look-and-feel/
cp -r ${REPO_DIR}/branding/kde/konsole/* \$INSTALL_ROOT/usr/share/konsole/
cp -r ${REPO_DIR}/branding/plymouth/agisota \$INSTALL_ROOT/usr/share/plymouth/themes/
cp -r ${REPO_DIR}/branding/kde/sddm/agisota \$INSTALL_ROOT/usr/share/sddm/themes/
cp ${REPO_DIR}/config/fonts/99-agisota-fonts.conf \$INSTALL_ROOT/etc/fonts/conf.d/
%end

%post
# Set Russian locale
echo 'LANG=ru_RU.UTF-8' > /etc/locale.conf
localectl set-locale LANG=ru_RU.UTF-8

# Install Victor Mono
mkdir -p /usr/share/fonts/victor-mono
curl -fsSL "https://github.com/rubjo/victor-mono/releases/download/v1.5.6/VictorMonoAll.zip" -o /tmp/vm.zip
unzip -o /tmp/vm.zip "OTF/*" -d /tmp/vm
cp /tmp/vm/OTF/*.otf /usr/share/fonts/victor-mono/
rm -rf /tmp/vm /tmp/vm.zip
fc-cache -fv

# Plymouth
plymouth-set-default-theme agisota

# SDDM
mkdir -p /etc/sddm.conf.d
echo -e "[Theme]\nCurrent=agisota" > /etc/sddm.conf.d/agisota.conf

# Enable services
systemctl enable sddm
systemctl enable tailscaled
systemctl enable podman.socket
systemctl enable firewalld

# Flatpak setup
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# npm globals
npm install -g pnpm @anthropic-ai/claude-code @openai/codex 2>/dev/null || true

# Starship
curl -fsSL https://starship.rs/install.sh | sh -s -- -y 2>/dev/null || true
%end
KICKSTART

    # Build with livemedia-creator
    livemedia-creator \
        --ks="${BUILD_DIR}/agisota-kde.ks" \
        --no-virt \
        --resultdir="$OUTPUT_DIR" \
        --project="AGISOTA Linux" \
        --releasever="$FEDORA_VER" \
        --make-disk \
        --image-name="agisota-linux-${VERSION}.raw"

    log "Image built: ${OUTPUT_DIR}/agisota-linux-${VERSION}.raw"

    # Compress
    zstd -T0 -19 "${OUTPUT_DIR}/agisota-linux-${VERSION}.raw" -o "${OUTPUT_DIR}/agisota-linux-${VERSION}.raw.zst"
    log "Compressed: ${OUTPUT_DIR}/agisota-linux-${VERSION}.raw.zst"
}

# ============================================================================
# Option B: Transform existing image (faster for iteration)
# ============================================================================
build_with_transform() {
    log "Using transform-based build..."
    log "Download base Fedora Asahi image first, then mount and run transform.sh inside"

    local base_image="${1:-}"
    [[ -z "$base_image" ]] && err "Usage: $0 --transform <base-image.raw>"

    local loop_dev
    loop_dev=$(losetup --find --show --partscan "$base_image")

    mkdir -p "${BUILD_DIR}/mnt"
    mount "${loop_dev}p3" "${BUILD_DIR}/mnt"
    mount "${loop_dev}p2" "${BUILD_DIR}/mnt/boot"

    # Run transform inside chroot
    cp "${REPO_DIR}/scripts/transform.sh" "${BUILD_DIR}/mnt/tmp/"
    cp -r "${REPO_DIR}" "${BUILD_DIR}/mnt/tmp/agisota-linux"

    arch-chroot "${BUILD_DIR}/mnt" /bin/bash /tmp/transform.sh

    umount -R "${BUILD_DIR}/mnt"
    losetup -d "$loop_dev"

    log "Transformed image: $base_image"
}

# Main
case "${1:-kickstart}" in
    --transform) build_with_transform "${2:-}" ;;
    *) build_with_kickstart ;;
esac
