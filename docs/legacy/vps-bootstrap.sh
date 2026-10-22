#!/bin/bash
# VPS Bootstrap für Ubuntu (Oracle Cloud Free Tier optimiert)
# Benötigt Root-Rechte (sudo)

set -euo pipefail

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Root-Check
if [ "$EUID" -ne 0 ]; then
    log_error "Dieses Skript muss als Root ausgeführt werden (sudo)."
    exit 1
fi

# Ubuntu Version prüfen
if [ ! -f /etc/os-release ]; then
    log_error "Kein /etc/os-release gefunden. Nur Ubuntu unterstützt."
    exit 1
fi
. /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
    log_error "Nur Ubuntu wird unterstützt (gefunden: $ID)."
    exit 1
fi
log_info "Ubuntu $VERSION_ID erkannt."

echo "=== VPS Bootstrap (Ubuntu $VERSION_ID) ==="

# System updaten
log_info "Aktualisiere System..."
apt update && apt upgrade -y

# Notwendige Basis-Pakete
log_info "Installiere Basis-Pakete..."
apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    jq \
    stress-ng \
    htop \
    net-tools \
    dnsutils

# Docker installieren (nur wenn nicht vorhanden)
if ! command -v docker &> /dev/null; then
    log_info "Installiere Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Docker Service aktivieren
    systemctl enable --now docker
else
    log_info "Docker bereits installiert: $(docker --version)"
fi

# Docker Daemon konfigurieren
log_info "Konfiguriere Docker Daemon..."
cat > /etc/docker/daemon.json <<'EOF'
{
  "live-restore": true,
  "userland-proxy": false,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF

# Docker neu starten und Konfiguration verifizieren
systemctl restart docker
sleep 2
if docker info --format '{{.LiveRestoreEnabled}}' | grep -q "true"; then
    log_info "Docker live-restore: aktiviert"
else
    log_warn "Docker live-restore: NICHT aktiviert (Prüfung fehlgeschlagen)"
fi

# UFW konfigurieren
log_info "Konfiguriere UFW..."
apt install -y ufw

# SSH erlauben (vor Enable!)
ufw allow 22/tcp comment "SSH"
ufw allow 41641/udp comment "Tailscale"
ufw default deny incoming
ufw default allow outgoing

# Docker UFW Fix: DEFAULT_FORWARD_POLICY
if grep -q "^DEFAULT_FORWARD_POLICY=" /etc/default/ufw; then
    sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
else
    echo 'DEFAULT_FORWARD_POLICY="ACCEPT"' >> /etc/default/ufw
fi

# UFW aktivieren (non-interaktiv)
ufw --force enable
ufw reload

# Verifizieren
if ufw status | grep -q "Status: active"; then
    log_info "UFW: aktiv"
else
    log_error "UFW: konnte nicht aktiviert werden"
    exit 1
fi

# Fail2ban konfigurieren
log_info "Konfiguriere Fail2ban..."
apt install -y fail2ban

cat > /etc/fail2ban/jail.local <<'EOF'
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

[docker-auth]
enabled = true
filter = docker-auth
logpath = /var/log/auth.log
maxretry = 5
bantime = 7200
EOF

# Fail2ban Filter für Docker (falls nicht vorhanden)
if [ ! -f /etc/fail2ban/filter.d/docker-auth.conf ]; then
    cat > /etc/fail2ban/filter.d/docker-auth.conf <<'EOF'
[Definition]
failregex = ^.*error authorizing.*: <HOST>.*$
ignoreregex =
EOF
fi

systemctl enable --now fail2ban

# Tailscale installieren (mit Verifikation)
log_info "Installiere Tailscale..."
if ! command -v tailscale &> /dev/null; then
    curl -fsSL https://tailscale.com/install.sh | sh
else
    log_info "Tailscale bereits installiert: $(tailscale version | head -1)"
fi

# Tailscale Service aktivieren
systemctl enable --now tailscaled

# Oracle Cloud spezifisch: iptables persistent machen
log_info "Konfiguriere iptables-persistent für Oracle Cloud..."
apt install -y iptables-persistent netfilter-persistent
netfilter-persistent save

# Kernel Parameter für Container Performance
log_info "Setze Kernel-Parameter..."
cat > /etc/sysctl.d/99-co-glitch.conf <<'EOF'
# Container/Network Optimierungen
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
vm.max_map_count = 262144
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
EOF
sysctl --system

# Keepalive Service installieren
log_info "Installiere Keepalive Service..."
KEEPALIVE_SRC="/home/admin/co-glitch/config/systemd"
if [ -d "$KEEPALIVE_SRC" ]; then
    cp "$KEEPALIVE_SRC/keepalive.service" /etc/systemd/system/
    cp "$KEEPALIVE_SRC/keepalive.sh" /usr/local/bin/keepalive.sh
    chmod +x /usr/local/bin/keepalive.sh
    systemctl daemon-reload
    systemctl enable --now keepalive
    log_info "Keepalive Service installiert und gestartet"
else
    log_warn "Keepalive Source nicht gefunden unter $KEEPALIVE_SRC - überspringe"
fi

# Docker Group für admin User (falls existiert)
if id "admin" &>/dev/null; then
    usermod -aG docker admin
    log_info "User 'admin' zur docker Gruppe hinzugefügt"
fi

echo ""
log_info "=== VPS Setup abgeschlossen ==="
echo ""
echo "Nächste Schritte:"
echo "  1. tailscale up"
echo "  2. cd /home/admin/co-glitch && make gen-secrets"
echo "  3. nano .env  (API-Keys & Caddy Hashes eintragen)"
echo "  4. make up-core && make up-monitoring && make up-voice"
echo ""
echo "WICHTIG für Oracle Cloud:"
echo "  - Security Lists / Network Security Groups: Ingress UDP 41641 (Tailscale) erlauben"
echo "  - Instance Console: 'Do not automate termination' prüfen"