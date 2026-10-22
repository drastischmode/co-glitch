#!/bin/bash
# Client Bootstrap für Arch Linux oder Ubuntu
# Installiert: git, docker, rclone, tmux, tailscale, node/npx, ufw, fail2ban, openssh
# Idempotent - kann mehrfach ausgeführt werden

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

WITH_OLLAMA=false
if [[ "${1:-}" == "--with-ollama" ]]; then
    WITH_OLLAMA=true
fi

echo "=== Client Bootstrap (Arch/Ubuntu) ==="

# OS Erkennung via /etc/os-release
if [ ! -f /etc/os-release ]; then
    log_error "Kein /etc/os-release gefunden. Nur Arch/Ubuntu/Debian unterstützt."
    exit 1
fi
. /etc/os-release

case "$ID" in
    arch|manjaro|endeavouros)
        PM="pacman"
        PKGS_BASE="git curl wget openssl jq make tmux rclone ufw fail2ban openssh"
        PKGS_DOCKER="docker docker-compose"
        PKGS_BUILD="base-devel"
        log_info "Arch-basiert erkannt ($ID)"
        ;;
    ubuntu|debian|linuxmint|pop)
        PM="apt"
        PKGS_BASE="git curl wget openssl jq make tmux rclone ufw fail2ban openssh-client"
        PKGS_DOCKER="docker.io"
        PKGS_BUILD="build-essential"
        log_info "Debian-basiert erkannt ($ID)"
        ;;
    *)
        log_error "Nicht unterstütztes OS: $ID. Nur Arch/Ubuntu/Debian."
        exit 1
        ;;
esac

# Sudo-Prüfung
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

# Pakete installieren (idempotent: command -v check)
log_info "Installiere Basispakete..."
if [ "$PM" = "pacman" ]; then
    $SUDO pacman -Syu --noconfirm --needed $PKGS_BASE
    # Docker
    if ! command -v docker &> /dev/null; then
        $SUDO pacman -Syu --noconfirm --needed $PKGS_DOCKER
    else
        log_info "Docker bereits installiert: $(docker --version)"
    fi
    # Build tools
    $SUDO pacman -Syu --noconfirm --needed $PKGS_BUILD
elif [ "$PM" = "apt" ]; then
    export DEBIAN_FRONTEND=noninteractive
    $SUDO apt-get update
    $SUDO apt-get install -y $PKGS_BASE
    # Docker
    if ! command -v docker &> /dev/null; then
        $SUDO apt-get install -y $PKGS_DOCKER
    else
        log_info "Docker bereits installiert: $(docker --version)"
    fi
    # Docker Compose: Paketname unterscheidet sich je nach Distro/Version
    # (Ubuntu 24.04+: docker-compose-v2, Docker-Repo: docker-compose-plugin, älter: docker-compose)
    if docker compose version &> /dev/null; then
        log_info "Docker Compose Plugin bereits vorhanden"
    else
        $SUDO apt-get install -y docker-compose-v2 2>/dev/null \
            || $SUDO apt-get install -y docker-compose-plugin 2>/dev/null \
            || $SUDO apt-get install -y docker-compose 2>/dev/null \
            || log_warn "Docker Compose konnte nicht installiert werden - bitte manuell prüfen"
    fi
    $SUDO apt-get install -y $PKGS_BUILD
fi

# Docker Daemon konfigurieren (falls nicht vorhanden)
DOCKER_DAEMON_JSON="/etc/docker/daemon.json"
if [ ! -f "$DOCKER_DAEMON_JSON" ]; then
    log_info "Konfiguriere Docker Daemon..."
    $SUDO mkdir -p /etc/docker
    $SUDO tee "$DOCKER_DAEMON_JSON" > /dev/null <<'EOF'
{
  "live-restore": true,
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    $SUDO systemctl restart docker
    log_info "Docker Daemon konfiguriert und neu gestartet"
else
    log_info "Docker Daemon Config existiert bereits: $DOCKER_DAEMON_JSON"
fi

# Docker Service aktivieren
$SUDO systemctl enable --now docker

# User zur docker Gruppe
log_info "Füge User zur docker Gruppe hinzu..."
$SUDO usermod -aG docker "$USER"

# UFW konfigurieren (nur Client-Basics: ausgehende erlauben, eingehende default deny)
log_info "Konfiguriere UFW..."
$SUDO ufw --force enable
$SUDO ufw default deny incoming
$SUDO ufw default allow outgoing
# SSH erlauben falls nicht lokal
$SUDO ufw allow 22/tcp comment "SSH" 2>/dev/null || true
# Docker UFW Fix
if grep -q "^DEFAULT_FORWARD_POLICY=" /etc/default/ufw; then
    $SUDO sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
else
    echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' | $SUDO tee -a /etc/default/ufw > /dev/null
fi
$SUDO ufw reload

# Fail2ban konfigurieren
log_info "Konfiguriere Fail2ban..."
$SUDO tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF
$SUDO systemctl enable --now fail2ban

# Tailscale installieren (falls nicht vorhanden)
if ! command -v tailscale &> /dev/null; then
    log_info "Installiere Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
else
    log_info "Tailscale bereits installiert: $(tailscale version | head -1)"
fi

# Ollama optional installieren
if [ "$WITH_OLLAMA" = true ]; then
    log_info "Installiere Ollama (--with-ollama)..."
    if ! command -v ollama &> /dev/null; then
        curl -fsSL https://ollama.com/install.sh | sh
    else
        log_info "Ollama bereits installiert"
    fi
    ollama pull qwen3.5:8b
fi

# Docker Compose Verifikation
if docker compose version &> /dev/null; then
    log_info "Docker Compose (Plugin): $(docker compose version --short)"
elif command -v docker-compose &> /dev/null; then
    log_info "Docker Compose (Standalone): $(docker-compose --version)"
else
    log_warn "Docker Compose nicht gefunden!"
fi

# Node/npx für MCP prüfen
if command -v npx &> /dev/null; then
    log_info "npx verfügbar: $(npx --version)"
else
    log_warn "npx nicht gefunden - MCP Server (filesystem, git, postgres) funktionieren evtl. nicht"
fi

echo ""
log_info "=== Client Setup abgeschlossen ==="
echo ""
echo "⚠️  WICHTIG: Damit Docker ohne sudo funktioniert:"
echo "   Abmelden & wieder anmelden  --ODER--  newgrp docker"
echo ""
echo "Nächste Schritte:"
echo "  1. make gen-secrets"
echo "  2. .env bearbeiten (NVIDIA_API_KEY, ZAI_API_KEY eintragen)"
echo "  3. make up-client"
echo "  4. make client-health"
echo ""
echo "Optional: make install-ollama  (für lokalen KI-Fallback)"