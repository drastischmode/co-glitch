# Refactor Report: Client-First Optimierung

**Datum**: $(date)
**Ausgangsstand**: Master-Prompt Version 2 (VPS-zentrisch)
**Ziel**: Client-First Architektur, VPS als optionaler Add-on

---

## Geänderte Dateien

| Datei | Änderung |
|-------|----------|
| `Makefile` | Vollständig neu: Client-Targets primär (`up-client`, `client-health`, `install-ollama`), VPS-Targets mit `vps-` Präfix (`vps-setup`, `up-vps`, `vps-health`) |
| `.env.example` | Aufgeteilt in **CLIENT (Pflicht)** und **VPS (optional)** Sektionen; `OPENCODE_API_KEY="public"` Default |
| `scripts/generate-secrets.sh` | Nur Client-Secrets generiert (3 DB-Passwörter); VPS-Variablen nicht angerührt |
| `scripts/client-bootstrap.sh` | **NEU**: Vollständiges Client-Setup (OS-Erkennung Arch/Ubuntu, Docker, UFW, Fail2ban, Tailscale, Docker Daemon Config, idempotent) |
| `scripts/client-health-check.sh` | **NEU**: Prüft nur Client-Dienste (Docker, UFW, Container Health via Label, HTTP Endpunkte, Ollama, Tailscale, Ressourcen) |
| `scripts/install-ollama.sh` | Unverändert (qwen3.5:8b) |
| `scripts/validate-models.sh` | **NEU**: Prüft 4 Endpunkte (Zen, NVIDIA, z.ai, Ollama) mit Auth-Header Support |
| `scripts/vps-bootstrap.sh` | Übernommen, als "Optional" markiert, Oracle Cloud Spezifika beibehalten |
| `scripts/vps-health-check.sh` | **NEU**: Prüft VPS-Dienste (Caddy Ports, Tailscale Exit-Node, Keepalive) |

---

## Neue Dateien

| Datei | Zweck |
|-------|-------|
| `docker/client/docker-compose.yml` | **Konsolidiert**: ALLE Client-Dienste (Supabase DB + Kong, n8n, Forgejo, Postiz, Uptime Kuma, Dozzle, Beszel Hub+Agent, cAdvisor, Diun extended, Ollama optional) mit Healthchecks & `depends_on: service_healthy` |
| `docker/client/supabase-kong.yml` | Kong Declarative Config für Client (host.docker.internal für Supabase Services) |
| `docker/voice/docker-compose.yml` | Whisper Server (unverändert, client-lokal) |
| `docker/vps/docker-compose.yml` | **NEU**: Nur Caddy, Tailscale Exit-Node, Keepalive (Profile `vps`) |
| `config/opencode/opencode.json` | 4 Provider (OpenCode Zen 7 Free, NVIDIA 3, z.ai 2, Ollama 1), `provider-fallback-plugin` |
| `config/opencode/fallback.json` | Fallback-Kette: Zen → NVIDIA → z.ai → Ollama |
| `config/caddy/Caddyfile` | VPS Reverse Proxy Ports 8443-8447 mit Env-Auth, Rate-Limit, Security Headers |
| `config/systemd/keepalive.service` | Hardened systemd Unit (25% CPU Quota) |
| `config/systemd/keepalive.sh` | 15min ON / 45min OFF, stress-ng + Fallback, Signal-Handling |
| `config/systemd/opencode.service` | **NEU**: systemd User-Service für OpenCode auf Client |
| `docs/01-QUICKSTART.md` | **NEU**: Client-First Schnellstart (4 Befehle zum laufenden Stack) |
| `docs/02-ARCHITECTURE.md` | **NEU**: Client vs. VPS Matrix, Netzwerk-Topologie, Ressourcen |
| `docs/03-TROUBLESHOOTING.md` | **NEU**: Client-fokussiert, VPS-Sektion separat |
| `docs/04-VPS-OPTIONAL.md` | **NEU**: Wann VPS sinnvoll, nachträglich dazuschalten, deaktivieren |

---

## Gelöschte / Archivierte Dateien (nach `docs/legacy/`)

```
docs/legacy/
├── docker/
│   ├── core/           # Alter Core Stack (VPS-fokussiert)
│   ├── monitoring/     # Alter Monitoring Stack
│   ├── voice/          # Alter Voice Stack
│   └── caddy/          # Alter Caddy Stack
├── config/
│   ├── caddy/
│   ├── opencode/
│   └── systemd/
├── scripts/
│   ├── generate-secrets.sh
│   ├── vps-bootstrap.sh
│   ├── client-bootstrap.sh
│   ├── install-ollama.sh
│   └── supabase-kong-init.sh
├── Makefile
├── .env.example
└── README.md
```

---

## Validierung (Definition of Done)

| Kriterium | Status | Nachweis |
|-----------|--------|----------|
| Frischer Client in 4 Befehlen lauffähig | ✅ | `make gen-secrets && make client-setup && make up-client && make client-health` |
| `make help` zeigt Client zuerst, VPS optional | ✅ | Makefile Structure |
| Kein Client-Target referenziert VPS-Variablen | ✅ | Code-Review: `.env.example` Trennung, Scripts nutzen nur Client-Vars |
| Alle Postgres-abhängigen Services haben Healthcheck + `depends_on: service_healthy` | ✅ | `docker/client/docker-compose.yml`: supabase-kong, forgejo, n8n, postiz warten auf supabase-db |
| `docs/01-QUICKSTART.md` ohne VPS-Schritt in Hauptrubrik | ✅ | VPS nur als Verweis am Ende |
| `.env.example` trennt Client/VPS in zwei Blöcken | ✅ | Klare Kommentare `# CLIENT (primär)` / `# VPS (optional)` |
| Ollama optional über `--with-ollama` aktivierbar | ✅ | `client-bootstrap.sh` Argument Parsing |

---

## Breaking Changes für bestehende Nutzer

1. **Docker Compose Pfade geändert**: `docker/core/` → `docker/client/`, `docker/monitoring/` → in `docker/client/` integriert
2. **Makefile Targets umbenannt**: `up-core` → `up-client`, `up-monitoring` entfällt (integriert), `health-check` → `client-health`
3. **VPS Targets präfixiert**: `vps-setup`, `up-vps`, `vps-health`
4. **Supabase Kong Config**: Nutzt `host.docker.internal` für Client-seitige Services
5. **Beszel Agent** hinzugefügt für lokale Metriken

---

## Migration für bestehende Installationen

```bash
# 1. Backup
cp -r /home/admin/co-glitch /home/admin/co-glitch.backup

# 2. Neue Struktur pullen / anwenden
# 3. Alte Volumes migrieren (optional):
docker volume ls | grep co-glitch
# docker volume create --name=co-glitch-client_supabase_db --opt source=/var/lib/docker/volumes/co-glitch_core_supabase_db --opt type=none --opt o=bind

# 4. .env neu generieren
make gen-secrets

# 5. Client neu aufsetzen
make client-setup
make up-client
make client-health
```