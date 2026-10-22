# co-glitch

**Infrastructure-as-Code Repository für eine modulare, containerisierte Self-Hosting-Plattform.**

Basierend auf dem Konzept "KI-Plattform Version 6.0" – reduziert auf deterministischen, versionierbaren Code.

---

## Übersicht

| Stack | Profile | Services |
|-------|---------|----------|
| **Core** | `core` | n8n, Postiz, Forgejo, Supabase (Full Stack), Temporal |
| **Monitoring** | `monitoring` | Uptime Kuma, Beszel, Dozzle, cAdvisor, Diun |
| **Voice** | `voice` | Whisper STT Server |
| **Proxy** | `proxy` | Caddy Reverse Proxy (Ports 8443-8447, Basic Auth + Rate Limit) |

Alle Services laufen **nur im Tailscale Tailnet** – keine öffentlichen Ports.
Zugriff über Caddy Reverse Proxy (Ports 8443-8447) mit Basic Auth + Security Headers.

---

## Schnellstart

```bash
# 1. Repository vorbereiten
cd /home/admin/co-glitch
make gen-secrets
# → .env bearbeiten: API-Keys eintragen (OpenCode, OpenRouter, Groq, NVIDIA, Gemini, Z.ai)
# → Caddy Auth-Hashes generieren: caddy hash-password --plaintext 'passwort'

# 2. VPS einrichten (auf Server, als root/sudo)
make vps-setup
tailscale up
make up-core
make up-monitoring
make up-voice
make up-proxy

# 3. Supabase initialisieren (einmalig)
make kong-init

# 4. Lokalen KI-Fallback installieren (optional, aber empfohlen)
make install-ollama

# 5. Client einrichten (auf Laptop)
make client-setup
tailscale up

# 6. OpenCode Config verlinken
ln -sf $(pwd)/config/opencode/opencode.json ~/.config/opencode/opencode.json

# 7. Modell-Erreichbarkeit prüfen
make validate-models
```

---

## Make Targets

```bash
make help              # Zeigt alle Targets
make gen-secrets       # Generiert .env mit sicheren Passwörtern
make validate-env      # Prüft .env auf Vollständigkeit
make vps-setup         # VPS: Docker, UFW, Fail2ban, Tailscale, Keepalive
make client-setup      # Client: Docker, Tools, Tailscale
make install-ollama    # Installiert Ollama + qwen3.5:8b (lokaler Fallback)
make validate-models   # Prüft Erreichbarkeit aller KI-Modell-Endpunkte
make up-core           # Startet Core-Stack
make up-monitoring     # Startet Monitoring-Stack
make up-voice          # Startet Voice-Stack
make up-proxy          # Startet Caddy Reverse Proxy
make up-all            # Startet alle Stacks
make down-all          # Stoppt alle Container
make clean-volumes     # Stoppt ALLE Container UND löscht Volumes (VORSICHT!)
make health-check      # System-Check (Container, UFW, Caddy Ports, DNS, Disk, RAM)
make kong-init         # Initialisiert Kong Consumers für Supabase
make logs-core         # Core-Stack Logs folgen
make logs-monitoring   # Monitoring-Stack Logs folgen
make logs-voice        # Voice-Stack Logs folgen
make logs-proxy        # Caddy Proxy Logs folgen
make status            # Container Status + Docker Disk Usage
```

---

## Verzeichnisstruktur

```
co-glitch/
├── Makefile                      # Zentrale Steuerung (17 Targets)
├── .env.example                  # Template für Umgebungsvariablen
├── .env                          # Wird von gen-secrets erstellt (NICHT committen!)
├── .gitignore                    # Git Ignore Rules
├── README.md                     # Diese Datei
├── renovate.json                 # Dependency Updates (Docker Images, GitHub Actions)
├── scripts/
│   ├── generate-secrets.sh       # Erzeugt .env mit openssl rand Passwörtern
│   ├── validate-env.sh           # Validiert .env auf Vollständigkeit (29 Required Vars)
│   ├── vps-bootstrap.sh          # Ubuntu: Docker, UFW, Fail2ban, Tailscale, Keepalive
│   ├── client-bootstrap.sh       # Arch/Ubuntu: Docker, Tools, Tailscale, Node/npx
│   ├── install-ollama.sh         # Installiert Ollama + qwen3.5:8b (64k+ Kontext)
│   └── supabase-kong-init.sh     # Initialisiert Kong Consumers via Admin API
├── docker/
│   ├── core/
│   │   ├── docker-compose.yml    # 14 Services mit Healthchecks & depends_on
│   │   └── kong.yml              # Kong Declarative Config (Template)
│   ├── monitoring/
│   │   └── docker-compose.yml    # 5 Services: Kuma, Beszel, Dozzle, cAdvisor, Diun
│   ├── voice/
│   │   └── docker-compose.yml    # Whisper Server + Model Cache Volume
│   └── caddy/
│       └── docker-compose.yml    # Caddy Reverse Proxy (Host Network)
├── config/
│   ├── caddy/
│   │   └── Caddyfile             # Reverse Proxy Config (Ports 8443-8447, Auth, Rate Limit)
│   ├── opencode/
│   │   ├── opencode.json         # 4 Provider, 7 Free Models, Fallback Plugin
│   │   └── fallback.json         # Fallback-Kette: Zen → NVIDIA → z.ai → Ollama
│   └── systemd/
│       ├── keepalive.service     # Oracle Idle-Shutdown Prevention (Hardening)
│       └── keepalive.sh          # 25% CPU Duty Cycle (15min on / 45min off)
├── docs/
│   ├── 01-QUICKSTART.md          # Detaillierter Start-Guide
│   ├── 02-ARCHITECTURE.md        # Architektur: VPS vs Client, Netzwerk, Volumes, Ressourcen
│   └── 03-TROUBLESHOOTING.md     # Häufige Fehler & Lösungen (11 Kategorien)
└── agent/                        # Für zukünftige Agent-Artefakte
```

---

## KI-Modell-Konfiguration (OpenCode)

Die `config/opencode/opencode.json` definiert 4 Provider mit Fallback-Kette:

| Provider | Modelle | Kosten | Rolle |
|----------|---------|--------|-------|
| **OpenCode Zen** | 7 Free Models (DeepSeek V4, Big Pickle, MiMo, Qwen 3.6, MiniMax M3, Nemotron 3 Ultra, North Mini Code) | Kostenlos | **Primär** |
| **NVIDIA NIM** | Nemotron 3.5 Lightning, Nemotron 3 Nano Omni, Nemotron 3 Ultra 550B | Kostenlos (40 RPM) | **Fallback 1-2** |
| **z.ai (Zhipu)** | GLM-4.5 Flash, GLM-4.7 Flash | Kostenlos (~1.000/Tag) | **Fallback 3** |
| **Ollama (lokal)** | qwen3.5:8b (64k+ Kontext) | Kostenlos, Offline | **Letzter Fallback** |

**Fallback-Reihenfolge** (in `config/opencode/fallback.json`):
1. `opencode/big-pickle` (kleines, schnelles Free-Model)
2. `nvidia/nemotron-3.5-lightning-30b-a3b` (schnelles 30B MoE)
3. `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning` (multimodal + reasoning)
4. `zai/glm-4.5-flash` (starkes Coding-Model)
5. `ollama/qwen3.5:8b` (100% offline, 64k+ Kontext)

---

## Sicherheit

- **Keine Secrets im Repo** – `.env` wird generiert, `.env.example` nur Template
- **API-Keys** via `{env:VAR}` in `opencode.json`
- **Basic Auth** für Monitoring-Tools (bcrypt-Hashes in `.env` → Caddyfile)
- **UFW** + **Fail2ban** auf VPS (SSH + Docker Auth Schutz)
- **Tailscale** als einziges Einfallstor (WireGuard Mesh VPN)
- **Caddy Security Headers**: HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy
- **Rate Limiting** auf allen Caddy Endpoints
- **Systemd Hardening** für Keepalive Service (NoNewPrivileges, PrivateTmp, ProtectSystem, etc.)
- **Docker Daemon Hardening**: live-restore, userland-proxy: false, Log-Rotation, ulimits
- **Healthchecks** für alle kritischen Services + `depends_on: condition: service_healthy`

---

## Dokumentation

- [Quickstart](docs/01-QUICKSTART.md) – Schritt-für-Schritt Anleitung
- [Architektur](docs/02-ARCHITECTURE.md) – VPS vs Client, Netzwerk-Topologie, Volumes, Ressourcen
- [Troubleshooting](docs/03-TROUBLESHOOTING.md) – 11 Kategorien mit Lösungen

---

## Lizenz

MIT – Frei zur Nutzung und Anpassung.