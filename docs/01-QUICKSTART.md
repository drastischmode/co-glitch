# co-glitch Quickstart (Client-First)

## Voraussetzungen
- **Client**: Arch Linux, Manjaro, EndeavourOS, Ubuntu, Debian, Linux Mint, Pop!_OS
- **RAM**: 8 GB empfohlen (16 GB für Ollama + alle Dienste)
- **Optional VPS**: Ubuntu 22.04/24.04 (Oracle Cloud Free Tier ARM empfohlen)
- **Tailscale Account** (für Tailnet-Vernetzung)

---

## 1. Bootstrap (frische Maschine)

```bash
# Ein einziger Befehl auf frischem System (installiert make, curl, git + Client-Setup)
./bootstrap.sh
```

**Was `bootstrap.sh` macht:**
- Installiert idempotent: `make`, `curl`, `git` (apt/pacman)
- Ruft `make client-setup` auf (Docker, UFW, Fail2ban, Tailscale, ...)

> **Alternative (manuell):**
> ```bash
> # Ubuntu/Debian
> sudo apt-get update && sudo apt-get install -y make curl git
> # Arch
> sudo pacman -S --needed make curl git
> make client-setup
> ```

---

## 2. Repository vorbereiten

```bash
cd /home/admin/co-glitch

# Secrets generieren (erstellt .env mit sicheren Passwörtern)
make gen-secrets

# .env bearbeiten: mindestens NVIDIA_API_KEY, ZAI_API_KEY eintragen
# OPENCODE_API_KEY="public" funktioniert oft ohne Account
nano .env
```

### Erforderliche Einträge in `.env`:

| Variable | Beschreibung | Quelle |
|----------|--------------|--------|
| `OPENCODE_API_KEY` | OpenCode Zen Gateway | Default `"public"` oder Key von opencode.ai |
| `NVIDIA_API_KEY` | NVIDIA NIM (Nemotron) | https://build.nvidia.com/ |
| `ZAI_API_KEY` | Z.ai / Zhipu GLM | https://z.ai/ |

> **Tipp**: `make gen-secrets` füllt alle DB-Passwörter automatisch.

---

## 3. Client einrichten (falls nicht via bootstrap.sh)

```bash
# Vollständiges Setup (Docker, Tools, UFW, Fail2ban, Tailscale)
make client-setup

# Optional: Ollama lokal installieren (Offline-Fallback, empfohlen)
make install-ollama

# Tailscale verbinden (Auth-URL im Browser öffnen)
tailscale up
```

### Was `client-setup` macht:
- OS-Erkennung (Arch vs Ubuntu/Debian)
- Pakete: git, docker, docker-compose, rclone, tmux, ufw, fail2ban, openssh
- Docker Daemon Config (live-restore, userland-proxy: false, Log-Rotation)
- User zur docker Gruppe hinzufügen
- UFW: Default deny incoming, allow outgoing, SSH erlaubt
- Fail2ban: SSH Schutz
- Tailscale Installation

### Nach Installation:
```bash
# Docker ohne sudo nutzen (einmalig):
newgrp docker
# ODER: Abmelden & wieder anmelden
```

---

## 4. AI-Modelle validieren

```bash
make validate-models
```

Prüft Erreichbarkeit aller Endpunkte:
- OpenCode Zen (Free Tier, **kritisch**, funktioniert mit `"public"`)
- NVIDIA NIM (mit API-Key, **optional**)
- z.ai / Zhipu (mit API-Key, **optional**)
- Ollama lokal (falls installiert, **optional**)

> **Hinweis**: Nur OpenCode Zen muss erreichbar sein. Fehlende optionale Keys geben nur Warnungen.

---

## 5. Client-Stack starten

```bash
# Alle Client-Dienste starten (Default-Profil: client)
make up-client

# Optional: Voice-Stack (Whisper STT)
make up-voice

# Optional: Ollama (falls installiert)
docker compose -f docker/client/docker-compose.yml --profile client-ollama up -d

# Optional: Extended-Dienste (Postiz, Beszel-Agent, Diun)
make up-client-extended
```

### Was `up-client` startet (Profile: `client`):

| Service | Port (lokal) | Zweck |
|---------|-------------|-------|
| n8n | 5678 | Workflow-Automatisierung |
| Forgejo | 3000/2222 | Git Hosting (Web + SSH) |
| Supabase Studio | 8000 (Kong) | Backend-as-a-Service |
| Uptime Kuma | 3001 | Uptime/Status-Monitoring |
| Dozzle | 8082 | Container Logs UI |
| Beszel Hub | 8090 | System-Metriken |
| cAdvisor | 8080 | Container Resource Metrics |

> **Optional (Extended-Profil):** Postiz (4007), Beszel Agent, Diun
> ```bash
> make up-client-extended
> ```

---

## 6. Health-Check

```bash
make client-health
```

Prüft: Docker, UFW, alle Container (4-Zustände: healthy/running/unhealthy/not-started), HTTP-Endpunkte, Ollama, Tailscale, Disk, RAM.

---

## 7. OpenCode konfigurieren

```bash
# Config verlinken (empfohlen)
ln -sf $(pwd)/config/opencode/opencode.json ~/.config/opencode/opencode.json

# Optional: OpenCode als systemd User-Service
systemctl --user enable --now --user $(pwd)/config/systemd/opencode.service
```

---

## 8. Zugriff (lokal & Tailnet)

Alle Services binden **nur an 127.0.0.1**. Zugriff über Tailscale IP oder localhost.

| Service | Lokal | Tailnet |
|---------|-------|---------|
| n8n | `http://localhost:5678` | `http://<tailnet-ip>:5678` |
| Forgejo | `http://localhost:3000` | `http://<tailnet-ip>:3000` |
| Supabase | `http://localhost:8000` | `http://<tailnet-ip>:8000` |
| Uptime Kuma | `http://localhost:3001` | `http://<tailnet-ip>:3001` |
| Beszel | `http://localhost:8090` | `http://<tailnet-ip>:8090` |
| Postiz (extended) | `http://localhost:4007` | `http://<tailnet-ip>:4007` |

---

## 9. EDA / Elektrotechnik (Optional - Native Desktop Tools)

KiCad, QElectroTech und ngspice sind **native Desktop-Anwendungen** (keine Container). Sie laufen direkt auf dem Client.

```bash
# Einmalig installieren (falls nicht via bootstrap.sh --with-eda geschehen):
make install-eda
# ODER manuell:
./bootstrap.sh --with-eda
```

### KiCad-Projekt anlegen (Git-ready)
```bash
make eda-project NAME=mein-board TYPE=kicad
# Erstellt: ~/projects/eda/mein-board/ mit .git, .gitignore, KiCad-Projekt
# Öffnen: kicad ~/projects/eda/mein-board/mein-board.kicad_pro
```

### QElectroTech-Projekt anlegen (Git-ready)
```bash
make eda-project NAME=mein-schaltschrank TYPE=qelectrotech
# Erstellt: ~/projects/eda/mein-schaltschrank/ mit .git, .gitignore, QET-Projekt
# Öffnen: qelectrotech ~/projects/eda/mein-schaltschrank/mein-schaltschrank.qet
```

### Simulation mit ngspice
```bash
# Netlist erstellen (.cir) und simulieren:
ngspice -b mein-circuit.cir -o output.txt
# Interaktiv:
ngspice mein-circuit.cir
```

### EDA-Projekte backupen
```bash
make eda-backup
# Wird auch automatisch bei 'make backup' mitgesichert
```

**Projekt-Struktur:**
```
~/projects/eda/
├── mein-board/           (KiCad)
│   ├── mein-board.kicad_pro
│   ├── mein-board.kicad_sch
│   ├── mein-board.kicad_pcb
│   ├── .git/
│   └── .gitignore
└── mein-schaltschrank/   (QElectroTech)
    ├── mein-schaltschrank.qet
    ├── elements/
    ├── projects/
    ├── titleblocks/
    ├── .git/
    └── .gitignore
```

---

## 10. VPS (Optional - nur für öffentliche Erreichbarkeit)

Falls **eingehende Webhooks**, **Tailnet Exit-Node** oder **dauerhaft erreichbare Dienste** gebraucht werden:

```bash
# Auf VPS (als root):
make vps-setup
tailscale up

# Caddy Hash generieren & in .env eintragen:
caddy hash-password --plaintext 'passwort'
# -> Wert in .env: CADDY_ADMIN_HASH

# VPS-Stack starten (nur Caddy + Tailscale Exit-Node + Keepalive)
make up-vps
```

Details: `docs/04-VPS-OPTIONAL.md`

---

## Nützliche Befehle

```bash
# Client-Stack stoppen
make down-client

# Logs folgen
docker compose -f docker/client/docker-compose.yml logs -f --tail=100

# Container Status
docker ps --filter "label=co-glitch.tier=client" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# Supabase Kong initialisieren (einmalig nach erstem Start)
# Siehe docs/03-TROUBLESHOOTING.md

# EDA / Elektrotechnik
make install-eda                    # EDA Tools installieren
make eda-project NAME=x TYPE=kicad  # Neues KiCad-Projekt
make eda-project NAME=x TYPE=qelectrotech  # Neues QET-Projekt
make eda-backup                     # EDA-Projekte backupen

# Alles stoppen (Client + VPS)
make down-all
```