#!/bin/sh
# AGISOTA Linux — Bootstrap installer
# Usage: curl -fsSL https://agisota.com/install | sh
#
# This overrides the standard Asahi installer to use AGISOTA images.
# Based on AsahiLinux/asahi-installer bootstrap-prod.sh

set -e

export VERSION_FLAG=https://cdn.asahilinux.org/installer/latest
export INSTALLER_BASE=https://cdn.asahilinux.org/installer
export INSTALLER_DATA=https://raw.githubusercontent.com/agisota/agisota-linux/main/installer/installer-data.json
export REPO_BASE=https://github.com/agisota/agisota-linux/releases/latest/download

echo ""
echo "  ╔═══════════════════════════════════════╗"
echo "  ║      AGISOTA Linux Installer          ║"
echo "  ║  Custom Fedora Asahi for M1/M2/M3/M4  ║"
echo "  ╚═══════════════════════════════════════╝"
echo ""
echo "  Загрузка инсталлера Asahi Linux..."
echo "  (INSTALLER_DATA указывает на AGISOTA)"
echo ""

# Fetch and run the official Asahi installer with our custom data
curl -fsSL https://cdn.asahilinux.org/installer/latest -o /tmp/asahi-installer-version
INSTALLER_VER=$(cat /tmp/asahi-installer-version)
curl -fsSL "https://cdn.asahilinux.org/installer/installer-${INSTALLER_VER}.tar.gz" -o /tmp/asahi-installer.tar.gz

mkdir -p /tmp/asahi-installer
tar xf /tmp/asahi-installer.tar.gz -C /tmp/asahi-installer --strip-components=1
cd /tmp/asahi-installer

# Run with our custom INSTALLER_DATA
exec python3 -m main
