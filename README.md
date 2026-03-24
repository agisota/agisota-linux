# AGISOTA Linux

Custom Fedora Asahi Remix for Apple Silicon (M1/M2/M3/M4).

```
┌─────────────────────────────────────────────┐
│  AGISOTA Linux                              │
│  Based on: Fedora Asahi Remix (KDE Plasma)  │
│  Target: Apple Silicon (aarch64)            │
│  Font: Victor Mono                          │
│  Locale: ru_RU.UTF-8                        │
│  Theme: Dark + Orange accents               │
└─────────────────────────────────────────────┘
```

## Quick Install (from macOS)

```bash
# Install base Fedora Asahi Remix first
curl https://fedora-asahi-remix.org/install | sh

# After booting into Fedora, run the AGISOTA transform
curl -fsSL https://raw.githubusercontent.com/agisota/agisota-linux/main/scripts/transform.sh | bash
```

## What's Included

### Branding
- Custom boot logo (plymouth splash)
- SDDM login theme (dark + orange)
- KDE Plasma look-and-feel theme
- Victor Mono as system monospace font
- Custom wallpaper
- Russian locale by default

### Pre-installed Software

**Browsers**: Brave, Chromium
**Communication**: Telegram, LarkSuite
**Notes**: Obsidian
**Editors**: Cursor, Zed, VS Code
**Terminal**: Ghostty, Kitty
**AI/Dev**: Claude Code, OpenCode, Codex CLI
**Containers**: Podman Desktop, Docker CE
**Infrastructure**: Pulumi, Temporal, Teable
**Database**: MonkDB (container)
**Other**: OBS Studio, Max (Cycling '74)

### System
- KDE Plasma 6 (Wayland)
- Victor Mono font everywhere
- Dark theme with orange (#FF6B35) accents
- Russian keyboard layout + English fallback
- Optimized for Apple Silicon (M1 Max, M2, M3, M4)

## Build Custom Image

```bash
# Requires Fedora aarch64 build environment
./scripts/build-image.sh
```

## Repository Structure

```
branding/          — Logo, wallpapers, plymouth, KDE themes, SDDM
packages/          — Package lists (base, desktop, dev-tools, flatpaks)
config/            — Locale, fonts, SDDM configuration
scripts/           — Transform, setup, and build scripts
installer/         — Custom Asahi installer manifest
systemd/           — Service unit files
.github/workflows/ — CI/CD for image building
```

## License

MIT
