#!/usr/bin/env bash
# ============================================================================
# AGISOTA Linux — Transform Script
# Converts base Fedora Asahi Remix (KDE) into AGISOTA Linux
#
# Usage: curl -fsSL https://raw.githubusercontent.com/agisota/agisota-linux/main/scripts/transform.sh | bash
# Or:    git clone https://github.com/agisota/agisota-linux && cd agisota-linux && bash scripts/transform.sh
# ============================================================================

set -euo pipefail

AGISOTA_VERSION="1.0.0"
AGISOTA_REPO="https://github.com/agisota/agisota-linux"
AGISOTA_RAW="https://raw.githubusercontent.com/agisota/agisota-linux/main"
ACCENT="#FF6B35"
REPO_DIR=""

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${GREEN}[AGISOTA]${NC} $*"; }
warn() { echo -e "${ORANGE}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
banner() {
    echo -e "${ORANGE}${BOLD}"
    echo "    ╔═══════════════════════════════════════╗"
    echo "    ║         AGISOTA Linux v${AGISOTA_VERSION}          ║"
    echo "    ║   Transform Fedora Asahi → AGISOTA    ║"
    echo "    ╚═══════════════════════════════════════╝"
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "Этот скрипт нужно запускать от root: sudo bash transform.sh"
        exit 1
    fi
}

check_fedora_asahi() {
    if ! grep -q "Fedora" /etc/os-release 2>/dev/null; then
        err "Не найдена Fedora. Этот скрипт предназначен для Fedora Asahi Remix."
        exit 1
    fi
    if ! uname -m | grep -q "aarch64"; then
        warn "Не aarch64 архитектура. Продолжаем, но некоторые пакеты могут не установиться."
    fi
    log "Fedora Asahi Remix обнаружена ✓"
}

clone_or_detect_repo() {
    if [[ -f "./branding/logo/agisota-logo.png" ]]; then
        REPO_DIR="$(pwd)"
        log "Локальный репозиторий обнаружен: ${REPO_DIR}"
    else
        log "Клонируем репозиторий AGISOTA..."
        REPO_DIR="/tmp/agisota-linux"
        rm -rf "$REPO_DIR"
        git clone --depth 1 "$AGISOTA_REPO" "$REPO_DIR"
    fi
}

# ============================================================================
# Phase 1: System packages
# ============================================================================
install_base_packages() {
    log "═══ Фаза 1: Системные пакеты ═══"

    # Enable RPM Fusion
    dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm \
        2>/dev/null || true

    # Docker CE repo
    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo 2>/dev/null || true

    # Tailscale repo
    dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo 2>/dev/null || true

    # Install base packages
    log "Устанавливаем базовые пакеты..."
    dnf install -y \
        zsh tmux htop btop ripgrep fd-find bat eza fzf jq tree wget curl \
        unzip p7zip wl-clipboard \
        git git-lfs gcc g++ make cmake \
        python3 python3-pip nodejs npm \
        podman podman-compose buildah skopeo \
        NetworkManager-wifi iwd tailscale wireguard-tools \
        2>&1 | tail -5

    # Docker CE (separate — may not be available on all Fedora versions)
    dnf install -y docker-ce docker-compose-plugin 2>/dev/null || warn "Docker CE не установлен (может быть недоступен для aarch64)"

    log "Базовые пакеты установлены ✓"
}

install_desktop_packages() {
    log "Устанавливаем десктоп-пакеты..."
    dnf install -y \
        kvantum papirus-icon-theme \
        pipewire wireplumber \
        flatpak \
        obs-studio \
        2>&1 | tail -5

    log "Десктоп-пакеты установлены ✓"
}

install_fonts() {
    log "Устанавливаем шрифты..."

    # Victor Mono from COPR or direct download
    if ! fc-list | grep -qi "Victor Mono"; then
        log "Скачиваем Victor Mono..."
        local font_dir="/usr/share/fonts/victor-mono"
        mkdir -p "$font_dir"
        local vm_version="1.5.6"
        local vm_url="https://github.com/rubjo/victor-mono/releases/download/v${vm_version}/VictorMonoAll.zip"
        local tmp_zip="/tmp/victor-mono.zip"
        curl -fsSL "$vm_url" -o "$tmp_zip"
        unzip -o "$tmp_zip" "OTF/*" -d /tmp/victor-mono-extract
        cp /tmp/victor-mono-extract/OTF/*.otf "$font_dir/"
        rm -rf "$tmp_zip" /tmp/victor-mono-extract
        log "Victor Mono установлен ✓"
    else
        log "Victor Mono уже установлен ✓"
    fi

    # Other fonts from dnf
    dnf install -y \
        google-noto-sans-fonts google-noto-sans-mono-fonts \
        google-noto-serif-fonts google-noto-emoji-fonts \
        jetbrains-mono-fonts fira-code-fonts \
        2>&1 | tail -3

    # Install fontconfig
    cp "${REPO_DIR}/config/fonts/99-agisota-fonts.conf" /etc/fonts/conf.d/
    fc-cache -fv >/dev/null 2>&1

    log "Все шрифты установлены ✓"
}

# ============================================================================
# Phase 2: Branding
# ============================================================================
install_branding() {
    log "═══ Фаза 2: Брендинг AGISOTA ═══"

    # KDE Color Scheme
    local cs_dir="/usr/share/color-schemes"
    mkdir -p "$cs_dir"
    cp "${REPO_DIR}/branding/kde/color-scheme/AGISOTA.colors" "$cs_dir/"
    log "Цветовая схема установлена ✓"

    # KDE Look and Feel
    local lnf_dir="/usr/share/plasma/look-and-feel"
    mkdir -p "$lnf_dir"
    cp -r "${REPO_DIR}/branding/kde/look-and-feel/org.agisota.desktop" "$lnf_dir/"
    log "KDE Look-and-Feel установлен ✓"

    # Konsole profile + color scheme
    local konsole_dir="/usr/share/konsole"
    mkdir -p "$konsole_dir"
    cp "${REPO_DIR}/branding/kde/konsole/AGISOTA.profile" "$konsole_dir/"
    cp "${REPO_DIR}/branding/kde/konsole/AGISOTA.colorscheme" "$konsole_dir/"
    log "Konsole профиль установлен ✓"

    # Plymouth theme
    local plymouth_dir="/usr/share/plymouth/themes/agisota"
    mkdir -p "$plymouth_dir"
    cp "${REPO_DIR}/branding/plymouth/agisota/agisota.plymouth" "$plymouth_dir/"
    cp "${REPO_DIR}/branding/plymouth/agisota/agisota.script" "$plymouth_dir/"
    cp "${REPO_DIR}/branding/logo/agisota-logo.png" "$plymouth_dir/logo.png"

    # Generate progress bar images for Plymouth
    if command -v convert &>/dev/null; then
        convert -size 400x8 xc:"#3A3F44" "$plymouth_dir/progress-bg.png"
        convert -size 396x4 xc:"${ACCENT}" "$plymouth_dir/progress-fill.png"
        convert -size 300x40 xc:"#1B1E21" -fill "#3A3F44" -draw "roundrectangle 0,0,299,39,6,6" "$plymouth_dir/entry.png"
    else
        warn "ImageMagick не найден — Plymouth прогресс-бар не создан"
    fi

    plymouth-set-default-theme agisota 2>/dev/null || warn "Не удалось установить Plymouth тему"
    dracut -f 2>/dev/null || true
    log "Plymouth тема установлена ✓"

    # SDDM theme
    local sddm_dir="/usr/share/sddm/themes/agisota"
    mkdir -p "$sddm_dir"
    cp "${REPO_DIR}/branding/kde/sddm/agisota/metadata.desktop" "$sddm_dir/"
    cp "${REPO_DIR}/branding/kde/sddm/agisota/theme.conf" "$sddm_dir/"
    cp "${REPO_DIR}/branding/kde/sddm/agisota/Main.qml" "$sddm_dir/"
    cp "${REPO_DIR}/branding/logo/agisota-logo.png" "$sddm_dir/logo.png"
    # Wallpaper for SDDM — use logo on dark bg if wallpaper not yet generated
    if [[ -f "${REPO_DIR}/branding/wallpapers/agisota-default.png" ]]; then
        cp "${REPO_DIR}/branding/wallpapers/agisota-default.png" "$sddm_dir/background.png"
    fi

    # Set SDDM theme
    mkdir -p /etc/sddm.conf.d
    cat > /etc/sddm.conf.d/agisota.conf <<'SDDM'
[Theme]
Current=agisota

[General]
InputMethod=

[X11]
EnableHiDPI=true

[Wayland]
EnableHiDPI=true
SDDM

    log "SDDM тема установлена ✓"

    # Wallpaper — copy if exists
    local wall_dir="/usr/share/wallpapers/agisota"
    mkdir -p "$wall_dir/contents/images"
    if [[ -f "${REPO_DIR}/branding/wallpapers/agisota-default.png" ]]; then
        cp "${REPO_DIR}/branding/wallpapers/agisota-default.png" "$wall_dir/contents/images/3456x2234.png"
        cat > "$wall_dir/metadata.json" <<'WALLMETA'
{
    "KPlugin": {
        "Authors": [{"Name": "AGISOTA"}],
        "Id": "agisota-default",
        "License": "MIT",
        "Name": "AGISOTA Default"
    }
}
WALLMETA
    fi

    log "Брендинг AGISOTA установлен ✓"
}

# ============================================================================
# Phase 3: Locale
# ============================================================================
configure_locale() {
    log "═══ Фаза 3: Локализация ═══"

    # Install Russian locale
    dnf install -y glibc-langpack-ru 2>&1 | tail -3

    # Set locale
    cp "${REPO_DIR}/config/locale/locale.conf" /etc/locale.conf
    localectl set-locale LANG=ru_RU.UTF-8

    # Keyboard layouts: Russian + US English
    localectl set-x11-keymap "us,ru" "" "" "grp:alt_shift_toggle"

    # Timezone — Moscow by default (can be changed)
    timedatectl set-timezone Europe/Moscow 2>/dev/null || true

    log "Локаль ru_RU.UTF-8 установлена ✓"
    log "Раскладки: US + RU (переключение: Alt+Shift) ✓"
}

# ============================================================================
# Phase 4: Flatpak apps
# ============================================================================
install_flatpaks() {
    log "═══ Фаза 4: Flatpak приложения ═══"

    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

    local apps=(
        "com.brave.Browser"
        "org.telegram.desktop"
        "md.obsidian.Obsidian"
        "dev.zed.Zed"
        "com.obsproject.Studio"
        "org.kde.filelight"
        "com.github.tchx84.Flatseal"
    )

    for app in "${apps[@]}"; do
        log "  Устанавливаем ${app}..."
        flatpak install -y flathub "$app" 2>&1 | tail -1 || warn "Не удалось установить $app"
    done

    log "Flatpak приложения установлены ✓"
}

# ============================================================================
# Phase 5: Developer tools
# ============================================================================
install_dev_tools() {
    log "═══ Фаза 5: Developer Tools ═══"

    # Get the actual user (not root)
    local real_user="${SUDO_USER:-$(logname 2>/dev/null || echo nobody)}"
    local real_home=$(eval echo "~${real_user}")

    # npm globals
    log "Устанавливаем npm tools..."
    npm install -g pnpm tsx 2>&1 | tail -3 || true

    # Claude Code
    log "Устанавливаем Claude Code..."
    npm install -g @anthropic-ai/claude-code 2>&1 | tail -3 || warn "Claude Code: ошибка установки"

    # Codex CLI
    log "Устанавливаем Codex CLI..."
    npm install -g @openai/codex 2>&1 | tail -3 || warn "Codex CLI: ошибка установки"

    # Rust + cargo tools (as user)
    if ! command -v rustup &>/dev/null; then
        log "Устанавливаем Rust..."
        su - "$real_user" -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y' 2>&1 | tail -3
    fi

    # Starship prompt
    if ! command -v starship &>/dev/null; then
        log "Устанавливаем Starship..."
        curl -fsSL https://starship.rs/install.sh | sh -s -- -y 2>&1 | tail -3
    fi

    # Pulumi
    log "Устанавливаем Pulumi..."
    curl -fsSL https://get.pulumi.com | sh 2>&1 | tail -3 || warn "Pulumi: ошибка установки"

    # Temporal CLI
    log "Устанавливаем Temporal CLI..."
    curl -sSf https://temporal.download/cli.sh | sh 2>&1 | tail -3 || warn "Temporal CLI: ошибка установки"

    # Bun
    log "Устанавливаем Bun..."
    su - "$real_user" -c 'curl -fsSL https://bun.sh/install | bash' 2>&1 | tail -3 || warn "Bun: ошибка установки"

    # Deno
    log "Устанавливаем Deno..."
    su - "$real_user" -c 'curl -fsSL https://deno.land/install.sh | sh' 2>&1 | tail -3 || warn "Deno: ошибка установки"

    # Go
    dnf install -y golang 2>&1 | tail -3 || true

    # Python tools
    pip install uv ruff ipython 2>&1 | tail -3 || true

    # Ghostty (from Copr or source)
    dnf copr enable -y pgdev/ghostty 2>/dev/null && dnf install -y ghostty 2>/dev/null || warn "Ghostty: не удалось установить из Copr"

    # lazygit
    dnf copr enable -y atim/lazygit 2>/dev/null && dnf install -y lazygit 2>/dev/null || warn "lazygit: не удалось установить из Copr"

    log "Developer tools установлены ✓"
}

# ============================================================================
# Phase 6: Shell & user config
# ============================================================================
configure_shell() {
    log "═══ Фаза 6: Shell конфигурация ═══"

    local real_user="${SUDO_USER:-$(logname 2>/dev/null || echo nobody)}"
    local real_home=$(eval echo "~${real_user}")

    # Set zsh as default shell
    chsh -s /bin/zsh "$real_user" 2>/dev/null || true

    # Starship config
    mkdir -p "${real_home}/.config"
    cat > "${real_home}/.config/starship.toml" <<'STARSHIP'
format = """
[╭─](bold fg:#FF6B35)$directory$git_branch$git_status$rust$python$nodejs$golang
[╰─](bold fg:#FF6B35)$character"""

[character]
success_symbol = "[λ](bold fg:#FF6B35)"
error_symbol = "[λ](bold fg:#DA4453)"

[directory]
style = "bold fg:#E8EAEC"
truncation_length = 3

[git_branch]
symbol = " "
style = "bold fg:#FF6B35"

[git_status]
style = "bold fg:#DA4453"

[rust]
symbol = " "
style = "bold fg:#FF6B35"

[python]
symbol = " "
style = "bold fg:#3498DB"

[nodejs]
symbol = " "
style = "bold fg:#27AE60"

[golang]
symbol = " "
style = "bold fg:#1ABC9C"
STARSHIP

    # Basic .zshrc
    if [[ ! -f "${real_home}/.zshrc" ]]; then
        cat > "${real_home}/.zshrc" <<'ZSHRC'
# AGISOTA Linux — zsh config
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"

# Aliases
alias ls='eza --icons'
alias ll='eza -la --icons'
alias cat='bat --style=plain'
alias grep='rg'
alias find='fd'
alias top='btop'
alias g='git'
alias dc='docker compose'
alias pc='podman compose'
alias k='kubectl'

# History
HISTSIZE=50000
SAVEHIST=50000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY

# FZF
source /usr/share/fzf/shell/key-bindings.zsh 2>/dev/null
export FZF_DEFAULT_OPTS='--color=bg+:#232629,fg:#E8EAEC,fg+:#FFFFFF,hl:#FF6B35,hl+:#FF8C5A,info:#A1A9B1,pointer:#FF6B35,prompt:#FF6B35'

# Path
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$HOME/.deno/bin:$HOME/.bun/bin:$PATH"

# Editor
export EDITOR=nvim
export VISUAL=nvim
ZSHRC
    fi

    chown -R "$real_user:$real_user" "${real_home}/.config" "${real_home}/.zshrc"

    log "Shell конфигурация установлена ✓"
}

# ============================================================================
# Phase 7: Apply KDE settings for user
# ============================================================================
apply_kde_settings() {
    log "═══ Фаза 7: Применяем настройки KDE ═══"

    local real_user="${SUDO_USER:-$(logname 2>/dev/null || echo nobody)}"
    local real_home=$(eval echo "~${real_user}")
    local kde_dir="${real_home}/.config"

    mkdir -p "$kde_dir"

    # Set look and feel
    su - "$real_user" -c 'lookandfeeltool -a org.agisota.desktop' 2>/dev/null || true

    # Set color scheme
    cat >> "${kde_dir}/kdeglobals" <<'KDEGLOBALS'

[General]
ColorScheme=AGISOTA
font=Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
fixed=Victor Mono,13,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
menuFont=Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
smallestReadableFont=Noto Sans,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
toolBarFont=Noto Sans,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1

[Icons]
Theme=Papirus-Dark

[KDE]
LookAndFeelPackage=org.agisota.desktop
SingleClick=false
KDEGLOBALS

    # Konsole default profile
    mkdir -p "${kde_dir}/konsolerc"
    cat > "${kde_dir}/konsolerc" <<'KONSOLERC'
[Desktop Entry]
DefaultProfile=AGISOTA.profile

[MainWindow]
MenuBar=Disabled
ToolBarsMovable=Disabled
KONSOLERC

    chown -R "$real_user:$real_user" "$kde_dir"

    log "Настройки KDE применены ✓"
}

# ============================================================================
# Phase 8: Services
# ============================================================================
enable_services() {
    log "═══ Фаза 8: Сервисы ═══"

    systemctl enable --now tailscaled 2>/dev/null || warn "Tailscale не запущен"
    systemctl enable --now docker 2>/dev/null || true
    systemctl enable --now podman.socket 2>/dev/null || true
    systemctl enable --now firewalld 2>/dev/null || true
    systemctl enable sddm 2>/dev/null || true

    log "Сервисы активированы ✓"
}

# ============================================================================
# Phase 9: Cleanup & Summary
# ============================================================================
cleanup_and_summary() {
    log "═══ Фаза 9: Финализация ═══"

    dnf clean all >/dev/null 2>&1
    flatpak repair --user 2>/dev/null || true

    echo ""
    echo -e "${ORANGE}${BOLD}"
    echo "    ╔═══════════════════════════════════════════════╗"
    echo "    ║     AGISOTA Linux v${AGISOTA_VERSION} — УСТАНОВЛЕН!       ║"
    echo "    ╠═══════════════════════════════════════════════╣"
    echo "    ║                                               ║"
    echo "    ║  ✓ Системные пакеты                          ║"
    echo "    ║  ✓ KDE тема + цветовая схема                 ║"
    echo "    ║  ✓ Victor Mono шрифт                         ║"
    echo "    ║  ✓ Plymouth boot splash                      ║"
    echo "    ║  ✓ SDDM логин-экран                          ║"
    echo "    ║  ✓ Русская локаль (US+RU раскладки)          ║"
    echo "    ║  ✓ Flatpak приложения                        ║"
    echo "    ║  ✓ Developer tools                           ║"
    echo "    ║  ✓ Zsh + Starship                            ║"
    echo "    ║  ✓ Сервисы                                   ║"
    echo "    ║                                               ║"
    echo "    ║  Перезагрузись для полного применения:        ║"
    echo "    ║  $ sudo reboot                               ║"
    echo "    ║                                               ║"
    echo "    ╚═══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ============================================================================
# Main
# ============================================================================
main() {
    banner
    check_root
    check_fedora_asahi
    clone_or_detect_repo

    install_base_packages
    install_desktop_packages
    install_fonts
    install_branding
    configure_locale
    install_flatpaks
    install_dev_tools
    configure_shell
    apply_kde_settings
    enable_services
    cleanup_and_summary
}

main "$@"
