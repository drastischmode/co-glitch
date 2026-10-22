#!/bin/bash
# Client Bootstrap für Arch Linux oder Ubuntu
# Installiert: git, docker, rclone, tmux, tailscale, node/npx (für MCP)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo "=== Client Bootstrap (Arch/Ubuntu) ==="

# OS Erkennung
if command -v pacman &> /dev/null; then
    PM="pacman"
    DISTRO="Arch"
    # Paketnamen für Arch
    PKGS_CORE="git docker docker-compose rclone tmux base-devel openssl nodejs npm"
    PKGS_AUR="tailscale"  # tailscale ist in AUR
    echo "Arch Linux erkannt"
elif command -v apt &> /dev/null; then
    PM="apt"
    DISTRO="Ubuntu/Debian"
    # Paketnamen für Ubuntu
    PKGS_CORE="git docker.io docker-compose-plugin rclone tmux build-essential openssl nodejs npm"
    PKGS_AUR=""
    echo "Ubuntu/Debian erkannt"
else
    log_error "Nicht unterstütztes OS. Nur Arch (pacman) und Ubuntu/Debian (apt)."
    exit 1
fi

# Sudo-Prüfung (für pacman/apt)
if [ "$EUID" -eq 0 ]; then
    SUDO=""
    log_warn "Skript läuft als Root - überspringe sudo"
else
    SUDO="sudo"
    if ! $SUDO -n true 2>/dev/null; then
        log_info "Sudo-Rechte erforderlich. Bitte Passwort eingeben:"
        $SUDO -v
    fi
fi

# Pakete installieren
log_info "Installiere Pakete ($DISTRO)..."
if [ "$PM" = "pacman" ]; then
    $SUDO pacman -Syu --noconfirm --needed $PKGS_CORE
    # AUR Helper prüfen für tailscale
    if command -v yay &> /dev/null; then
        yay -S --noconfirm $PKGS_AUR
    elif command -v paru &> /dev/null; then
        paru -S --noconfirm $PKGS_AUR
    else
        log_warn "Kein AUR Helper (yay/paru) gefunden. Tailscale manuell installieren:"
        log_warn "  git clone https://aur.archlinux.org/tailscale.git && cd tailscale && makepkg -si"
    fi
    $SUDO systemctl enable --now docker
elif [ "$PM" = "apt" ]; then
    $SUDO apt update
    $SUDO apt install -y $PKGS_CORE
    # Tailscale
    if ! command -v tailscale &> /dev/null; then
        curl -fsSL https://tailscale.com/install.sh | sh
    fi
    $SUDO systemctl enable --now docker
fi

# Docker Group
log_info "Füge aktuellen User zur docker Gruppe hinzu..."
$SUDO usermod -aG docker "$USER"

# Docker Compose Verifikation (Plugin vs Standalone)
if docker compose version &> /dev/null; then
    log_info "Docker Compose (Plugin): $(docker compose version --short)"
elif command -v docker-compose &> /dev/null; then
    log_info "Docker Compose (Standalone): $(docker-compose --version)"
else
    log_warn "Docker Compose nicht gefunden!"
fi

# Node/npx Verifikation (für MCP Server)
if command -v npx &> /dev/null; then
    log_info "npx verfügbar: $(npx --version)"
else
    log_warn "npx nicht gefunden - MCP Server (filesystem, git, postgres) werden nicht funktionieren"
fi

# Tailscale
log_info "Tailscale Status:"
if command -v tailscale &> /dev/null; then
    tailscale version | head -1
    systemctl is-enabled --quiet tailscaled && log_info "tailscaled: enabled" || log_warn "tailscaled: nicht enabled"
else
    log_warn "Tailscale nicht installiert"
fi

echo ""
log_info "=== Client Setup abgeschlossen ==="
echo ""
echo "⚠️  WICHTIG: Damit Docker ohne sudo funktioniert:"
echo "   Abmelden & wieder anmelden  --ODER--  newgrp docker"
echo ""
echo "Nächste Schritte:"
echo "  1. tailscale up"
echo "  2. SSH zum VPS: ssh admin@<vps-tailnet-ip>"
echo "  3. OpenCode Config verlinken:"
echo "     ln -sf \$(pwd)/config/opencode/opencode.json ~/.config/opencode/opencode.json"