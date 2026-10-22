#!/bin/bash
# Bootstrap-Skript für frische Maschinen
# Installiert make, curl, git idempotent und ruft dann make client-setup auf
# POSIX-kompatibel, funktioniert ohne make

set -eu

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo "=== co-glitch Bootstrap ==="

# OS Erkennung
if [ ! -f /etc/os-release ]; then
    log_error "Kein /etc/os-release gefunden. Nur Arch/Ubuntu/Debian unterstützt."
    exit 1
fi
. /etc/os-release

# Sudo-Prüfung
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
    log_warn "Skript läuft als Root - überspringe sudo"
else
    SUDO="sudo"
    if ! $SUDO -n true 2>/dev/null; then
        log_info "Sudo-Rechte erforderlich. Bitte Passwort eingeben:"
        $SUDO -v
    fi
fi

# Pakete installieren (idempotent)
log_info "Installiere Basis-Tools (make, curl, git)..."
if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -qq
    $SUDO apt-get install -y -qq make curl git >/dev/null
elif command -v pacman >/dev/null 2>&1; then
    $SUDO pacman -Sy --noconfirm --needed make curl git >/dev/null
else
    log_error "Nicht unterstütztes Paketmanagement. Nur apt/pacman."
    exit 1
fi

# Verifizieren
for cmd in make curl git; do
    if command -v "$cmd" >/dev/null; then
        log_info "$cmd: $(command -v $cmd)"
    else
        log_error "$cmd konnte nicht installiert werden"
        exit 1
    fi
done

# make client-setup aufrufen
log_info "Starte make client-setup..."
exec make client-setup