#!/usr/bin/env bash
# ============================================================================
# AGISOTA Linux — Build m1n1 with custom boot logo
#
# Prerequisites:
#   - aarch64 Linux (or cross-compile toolchain)
#   - ImageMagick (magick command)
#   - git, make, gcc-aarch64-linux-gnu (if cross-compiling)
#
# Usage: ./scripts/build-m1n1-logo.sh [path-to-logo.png]
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOGO_SOURCE="${1:-${REPO_DIR}/branding/logo/agisota-logo.png}"
M1N1_DIR="${REPO_DIR}/build/m1n1"

log() { echo -e "\033[0;33m[m1n1]\033[0m $*"; }
err() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; exit 1; }

# Check deps
command -v magick &>/dev/null || command -v convert &>/dev/null || err "ImageMagick required (magick or convert)"
command -v git &>/dev/null || err "git required"
command -v make &>/dev/null || err "make required"

# Clone m1n1 if needed
if [[ ! -d "$M1N1_DIR" ]]; then
    log "Клонируем m1n1..."
    git clone --depth 1 https://github.com/AsahiLinux/m1n1.git "$M1N1_DIR"
fi

# Prepare logo: 256x256 and 128x128 RGBA PNGs
LOGO_DIR="${M1N1_DIR}/logo"
mkdir -p "$LOGO_DIR"

log "Подготавливаем логотип из: ${LOGO_SOURCE}"

# Use magick if available, fallback to convert
IMG_CMD="magick"
command -v magick &>/dev/null || IMG_CMD="convert"

$IMG_CMD "$LOGO_SOURCE" -resize 256x256 -background none -gravity center -extent 256x256 "${LOGO_DIR}/agisota_256.png"
$IMG_CMD "$LOGO_SOURCE" -resize 128x128 -background none -gravity center -extent 128x128 "${LOGO_DIR}/agisota_128.png"

log "Логотип подготовлен: 256x256 + 128x128"

# Build m1n1 with custom logo
cd "$M1N1_DIR"

log "Собираем m1n1..."

if uname -m | grep -q "aarch64"; then
    # Native build
    make RELEASE=1 CHAINLOADING=1 LOGO=logo/agisota
else
    # Cross-compile (needs aarch64 toolchain)
    if command -v aarch64-linux-gnu-gcc &>/dev/null; then
        make RELEASE=1 CHAINLOADING=1 LOGO=logo/agisota ARCH=aarch64 CROSS_COMPILE=aarch64-linux-gnu-
    else
        err "Кросс-компиляция: нужен aarch64-linux-gnu-gcc. Установи: dnf install gcc-aarch64-linux-gnu"
    fi
fi

log "m1n1 собран: ${M1N1_DIR}/build/m1n1.bin"
log "Размер: $(du -h "${M1N1_DIR}/build/m1n1.bin" | cut -f1)"
log ""
log "Этот файл нужно положить в package.zip как m1n1.bin"
log "и указать в installer-data.json: \"boot_object\": \"m1n1.bin\""
